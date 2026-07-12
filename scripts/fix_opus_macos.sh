#!/usr/bin/env bash
set -euo pipefail

# Replaces the broken bitcode-only opus/ogg static libraries shipped by
# ogg_opus_player with real machine-code universal libraries vendored in
# macos/prebuilt/opus. Run after `flutter pub get`, before building macOS.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$PROJECT_ROOT/macos/prebuilt/opus"

PKG_CFG="$PROJECT_ROOT/.dart_tool/package_config.json"
LIBS=""

if [ -f "$PKG_CFG" ] && command -v python3 >/dev/null 2>&1; then
  ROOT="$(python3 - "$PKG_CFG" <<'PY'
import json, sys, urllib.parse
data = json.load(open(sys.argv[1]))
for pkg in data.get("packages", []):
    if pkg["name"] == "ogg_opus_player":
        print(urllib.parse.unquote(urllib.parse.urlparse(pkg["rootUri"]).path))
        break
PY
)"
  if [ -n "$ROOT" ]; then
    case "$ROOT" in
      /*) PKGDIR="$ROOT" ;;
      *)  PKGDIR="$(cd "$PROJECT_ROOT/.dart_tool/$ROOT" && pwd)" ;;
    esac
    LIBS="$PKGDIR/darwin/Libs"
  fi
fi

if [ -z "$LIBS" ] || [ ! -d "$LIBS" ]; then
  for cand in "${PUB_CACHE:-$HOME/.pub-cache}/hosted"/*/ogg_opus_player-*/darwin/Libs; do
    [ -d "$cand" ] && LIBS="$cand" && break
  done
fi

if [ -z "$LIBS" ] || [ ! -d "$LIBS" ]; then
  echo "warning: ogg_opus_player macOS Libs dir not found; skipping opus fix" >&2
  exit 0
fi

echo "==> Installing prebuilt opus libs into: $LIBS"
for f in libogg.a libopus.a libopusfile.a libopusenc.a; do
  cp -f "$SRC/$f" "$LIBS/$f"
  echo "  installed $f ($(lipo -archs "$LIBS/$f" 2>/dev/null))"
done
echo "==> opus libs fixed"
