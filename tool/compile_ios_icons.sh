#!/bin/bash
# Пайплайн иконок Icon Composer для Komet.
#
# Режим ios вызывается фазой Run Script таргета Runner: компилирует
# Runner/Assets.xcassets + .icon-пакеты из Runner/AppIcons через actool
# прямо в Assets.car бандла. Только Assets.car читается системой: там живут
# многослойные рендиции (стекло, dark/tinted) и полная линейка размеров @2x/@3x.
# Имена иконок должен совпадать с CFBundleIcons в Runner/Info.plist
# (komet_icon — primary, meteor_icon и not_skam — альтернативные).
#
# Режим macos собирает KometIcons.car + .icns в macos/Runner/AppIcons как и раньше.
#
# Прогон вручную: ./tool/compile_ios_icons.sh macos
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:?режим: ios или macos}"

PRIMARY=komet_icon
ALTERNATES=(meteor_icon not_skam)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

case "$MODE" in
  macos)
    OUT="macos/Runner/AppIcons"
    ICONS_DIR="assets/ios_icons"
    mkdir -p "$OUT"
    rm -f "$OUT"/*.car "$OUT"/*.icns "$OUT"/*.png

    icon_paths=()
    for n in "$PRIMARY" "${ALTERNATES[@]}"; do
      icon_paths+=("$ICONS_DIR/$n.icon")
    done

    alternates_flags=(--app-icon "$PRIMARY")
    for n in "${ALTERNATES[@]}"; do
      alternates_flags+=("--alternate-app-icon" "$n")
    done

    xcrun actool \
      --compile "$TMP" \
      --platform macosx \
      --minimum-deployment-target 10.15 \
      "${alternates_flags[@]}" \
      --output-partial-info-plist "$TMP/partial.plist" \
      --output-format human-readable-text \
      "${icon_paths[@]}" >/dev/null

    cp "$TMP/Assets.car" "$OUT/KometIcons.car"
    cp "$TMP/$PRIMARY.icns" "$OUT/$PRIMARY.icns"

    echo "$MODE -> $OUT:"
    ls -la "$OUT"
    ;;
  ios)
    PLATFORM="${PLATFORM_NAME:?PLATFORM_NAME должен быть задан Xcode}"
    MIN_TARGET="${IPHONEOS_DEPLOYMENT_TARGET:?IPHONEOS_DEPLOYMENT_TARGET должен быть задан Xcode}"
    SRC="${SRCROOT:?SRCROOT должен быть задан Xcode}"
    DEST="${BUILT_PRODUCTS_DIR:?BUILT_PRODUCTS_DIR должен быть задан Xcode}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?UNLOCALIZED_RESOURCES_FOLDER_PATH должен быть задан Xcode}"

    icon_paths=()
    for n in "$PRIMARY" "${ALTERNATES[@]}"; do
      icon_paths+=("$SRC/Runner/AppIcons/$n.icon")
    done

    alternates_flags=(--app-icon "$PRIMARY")
    for n in "${ALTERNATES[@]}"; do
      alternates_flags+=("--alternate-app-icon" "$n")
    done

    xcrun actool \
      --compile "$TMP" \
      --platform "$PLATFORM" \
      --minimum-deployment-target "$MIN_TARGET" \
      "${alternates_flags[@]}" \
      --output-partial-info-plist "$TMP/partial.plist" \
      --output-format human-readable-text \
      "$SRC/Runner/Assets.xcassets" \
      "${icon_paths[@]}" >/dev/null

    if [ ! -f "$TMP/Assets.car" ]; then
      echo "actool не выдал Assets.car" >&2
      exit 1
    fi
    cp "$TMP/Assets.car" "$DEST/Assets.car"
    ;;
  *) echo "неизвестный режим: $MODE" >&2; exit 1 ;;
esac