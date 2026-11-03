#!/usr/bin/env bash
set -euo pipefail

lock="${1:-pubspec.lock}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

pins="$(awk '
  /^  [^ ].*:$/ { name = $1; sub(/:$/, "", name); ref = ""; url = "" }
  $1 == "resolved-ref:" { ref = $2; gsub(/"/, "", ref) }
  $1 == "url:" { url = $2; gsub(/"/, "", url) }
  $1 == "source:" && $2 == "git" { print name, url, ref }
' "$lock")"

if [ -z "$pins" ]; then
  echo "в $lock нет git-зависимостей"
  exit 0
fi

failed=0
while read -r name url ref; do
  repo="$work/$name"
  if ! GIT_TERMINAL_PROMPT=0 git clone -q --mirror "$url" "$repo"; then
    echo "::error file=$lock::$name: не удалось склонировать $url без учётки"
    failed=1
  elif git -C "$repo" cat-file -e "$ref^{commit}" 2>/dev/null; then
    echo "$name: $ref есть в $url"
  else
    echo "::error file=$lock::$name: $ref нет ни в одной ветке или теге $url, pub get с чистым кэшем упадёт"
    failed=1
  fi
done <<< "$pins"

exit "$failed"
