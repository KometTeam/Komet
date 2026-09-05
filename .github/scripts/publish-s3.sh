#!/usr/bin/env bash
set -euo pipefail

: "${S3_BUCKET:?S3_BUCKET is required}"
: "${S3_ENDPOINT:?S3_ENDPOINT is required}"
: "${S3_PUBLIC_BASE_URL:?S3_PUBLIC_BASE_URL is required}"
: "${TAG:?TAG is required}"
: "${VERSION:?VERSION is required}"
: "${BUILD:?BUILD is required}"

DIST_DIR="${DIST_DIR:-dist}"
NOTES_FILE="${NOTES_FILE:-}"
RELEASE_URL="${RELEASE_URL:-}"
COMMIT="${COMMIT:-}"
KEEP_RELEASES="${KEEP_RELEASES:-1}"
EXCLUDE_GLOBS="${EXCLUDE_GLOBS:-*.aab}"
PRUNE_BEFORE_UPLOAD="${PRUNE_BEFORE_UPLOAD:-1}"

RELEASE_ID="${RELEASE_ID:-${VERSION}-${BUILD}}"
PREFIX="releases/${RELEASE_ID}"
PUBLIC_BASE="${S3_PUBLIC_BASE_URL%/}"

aws_s3() { aws --endpoint-url "$S3_ENDPOINT" s3 "$@"; }

read -ra EXCLUDE_LIST <<< "$EXCLUDE_GLOBS"

is_excluded() {
  local name="$1" glob
  for glob in "${EXCLUDE_LIST[@]}"; do
    case "$name" in
      $glob) return 0 ;;
    esac
  done
  return 1
}

prune_old_releases() {
  echo "Pruning old releases (keeping $KEEP_RELEASES)"
  local stale_list
  stale_list="$(
    {
      aws_s3 ls "s3://$S3_BUCKET/releases/" || true
    } | awk '/PRE/ {print $2}' | tr -d '/' | sort -Vr \
      | { grep -vx "$RELEASE_ID" || true; } \
      | tail -n "+$KEEP_RELEASES"
  )"

  if [ -z "$stale_list" ]; then
    echo "Nothing to prune."
    return
  fi

  while read -r stale; do
    [ -n "$stale" ] || continue
    echo "Removing s3://$S3_BUCKET/releases/$stale"
    aws_s3 rm --recursive "s3://$S3_BUCKET/releases/$stale" --only-show-errors
  done <<< "$stale_list"
}

content_type_for() {
  case "$1" in
    *.apk) echo "application/vnd.android.package-archive" ;;
    *.aab) echo "application/octet-stream" ;;
    *.ipa) echo "application/octet-stream" ;;
    *.zip) echo "application/zip" ;;
    *.tar.gz) echo "application/gzip" ;;
    *.json) echo "application/json" ;;
    *) echo "application/octet-stream" ;;
  esac
}

echo "Publishing $TAG to s3://$S3_BUCKET/$PREFIX"

if [ "$PRUNE_BEFORE_UPLOAD" = "1" ]; then
  prune_old_releases
fi

INDEX="$(mktemp)"
trap 'rm -f "$INDEX"' EXIT

shopt -s nullglob
for file in "$DIST_DIR"/*; do
  [ -f "$file" ] || continue
  name="$(basename "$file")"
  if is_excluded "$name"; then
    echo "Skipping $name"
    continue
  fi
  size="$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file")"
  digest="$(sha256sum "$file" | awk '{print $1}')"

  aws_s3 cp "$file" "s3://$S3_BUCKET/$PREFIX/$name" \
    --content-type "$(content_type_for "$name")" \
    --cache-control "public, max-age=31536000, immutable" \
    --no-progress

  printf '%s\t%s\t%s\n' "$name" "$size" "$digest" >> "$INDEX"
done
shopt -u nullglob

if [ ! -s "$INDEX" ]; then
  echo "No files found in $DIST_DIR — nothing to publish." >&2
  exit 1
fi

MANIFEST="$(mktemp)"
trap 'rm -f "$INDEX" "$MANIFEST"' EXIT

INDEX_FILE="$INDEX" MANIFEST_FILE="$MANIFEST" ASSET_BASE="$PUBLIC_BASE/$PREFIX" \
RELEASE_ID="$RELEASE_ID" VERSION="$VERSION" BUILD="$BUILD" TAG="$TAG" \
NOTES_FILE="$NOTES_FILE" RELEASE_URL="$RELEASE_URL" COMMIT="$COMMIT" \
python3 <<'PY'
import json, os, datetime

assets = []
with open(os.environ['INDEX_FILE'], encoding='utf-8') as f:
    for line in f:
        line = line.rstrip('\n')
        if not line:
            continue
        name, size, digest = line.split('\t')
        assets.append({
            'name': name,
            'url': f"{os.environ['ASSET_BASE']}/{name}",
            'size': int(size),
            'sha256': digest,
        })
assets.sort(key=lambda a: a['name'])

notes = ''
notes_file = os.environ.get('NOTES_FILE') or ''
if notes_file and os.path.exists(notes_file):
    with open(notes_file, encoding='utf-8') as f:
        notes = f.read().strip()

manifest = {
    'version': os.environ['VERSION'],
    'build': int(os.environ['BUILD']),
    'tag': os.environ['TAG'],
    'release': os.environ['RELEASE_ID'],
    'commit': os.environ.get('COMMIT') or '',
    'url': os.environ.get('RELEASE_URL') or '',
    'published_at': datetime.datetime.now(datetime.timezone.utc)
        .replace(microsecond=0).isoformat().replace('+00:00', 'Z'),
    'notes': notes,
    'assets': assets,
}

with open(os.environ['MANIFEST_FILE'], 'w', encoding='utf-8') as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
    f.write('\n')
PY

aws_s3 cp "$MANIFEST" "s3://$S3_BUCKET/latest.json" \
  --content-type "application/json; charset=utf-8" \
  --cache-control "no-cache, max-age=0, must-revalidate" \
  --no-progress

echo "Manifest published:"
cat "$MANIFEST"

if [ "$PRUNE_BEFORE_UPLOAD" != "1" ]; then
  prune_old_releases
fi

echo "Done: $PUBLIC_BASE/latest.json"
