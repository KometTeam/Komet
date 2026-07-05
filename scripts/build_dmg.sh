#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Komet"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/build/macos/Build/Products/Release/$APP_NAME.app"

VERSION="$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | sed 's/version: *//' | cut -d'+' -f1)"
DIST_DIR="$PROJECT_ROOT/dist"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"

echo "==> Building release macOS app"
cd "$PROJECT_ROOT"
flutter pub get
"$PROJECT_ROOT/scripts/fix_opus_macos.sh"
flutter build macos --release

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: $APP_PATH not found after build" >&2
  exit 1
fi

echo "==> Verifying ad-hoc signature (Xcode signs with CODE_SIGN_IDENTITY=- and Release.entitlements)"
codesign --verify --deep --strict "$APP_PATH"
if codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | grep -q "com.apple.security.app-sandbox"; then
  echo "error: app-sandbox is enabled; flutter_secure_storage keychain will fail (-34018) without a Developer Team" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"

BACKGROUND="$PROJECT_ROOT/scripts/dmg/background.png"

if command -v create-dmg >/dev/null 2>&1; then
  echo "==> Packaging with create-dmg"
  create-dmg \
    --volname "$APP_NAME $VERSION" \
    --background "$BACKGROUND" \
    --window-pos 200 120 \
    --window-size 640 400 \
    --icon-size 128 \
    --text-size 13 \
    --icon "$APP_NAME.app" 170 190 \
    --app-drop-link 470 190 \
    --hide-extension "$APP_NAME.app" \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"
else
  echo "==> create-dmg not found, packaging with hdiutil"
  STAGING="$(mktemp -d)"
  cp -R "$APP_PATH" "$STAGING/"
  ln -s /Applications "$STAGING/Applications"
  hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"
  rm -rf "$STAGING"
fi

echo "==> Done: $DMG_PATH"
