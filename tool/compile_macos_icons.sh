#!/usr/bin/env bash
#
# compile_macos_icons.sh — компиляция Icon Composer .icon (Liquid Glass)
# для macOS. Единый источник с iOS: ios/Runner/AppIcons/*.icon. Один actool
# прогон кладёт в Assets.car ImageStack'и ВСЕХ иконок (primary + альтернативы)
# со всеми вариантами оформления (light/dark/clear/tinted) — NSImage(named:)
# отдаёт appearance-aware картинку, primary в Dock идёт из бандла (nil-сброс),
# альтернативы через NSApplication.applicationIconImage.
#
# Использование:
#   tool/compile_macos_icons.sh [out-dir]
#   # default out: macos/Runner/AppIcons
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$REPO_ROOT/macos/Runner/AppIcons}"
SRC="$REPO_ROOT/ios/Runner/AppIcons"
PRIMARY_NAME="komet_icon"

OUT="$(cd "$OUT" && pwd)"
mkdir -p "$OUT"

INPUTS=()
ALT_NAMES=()
for ICON in "$SRC"/*.icon; do
  [ -e "$ICON" ] || continue
  NAME="$(basename "${ICON%.icon}")"
  INPUTS+=("$ICON")
  [ "$NAME" = "$PRIMARY_NAME" ] && continue
  ALT_NAMES+=("$NAME")
done
[ -e "$SRC/$PRIMARY_NAME.icon" ] || { echo "ERROR: $SRC/$PRIMARY_NAME.icon не найден" >&2; exit 1; }

CANDIDATES=(
  "/Applications/Xcode.app/Contents/Developer"
  "$(xcode-select -p 2>/dev/null || true)"
  "/Applications/Xcode-beta.app/Contents/Developer"
)
CLEAN_ENV=(
  "HOME=${HOME:-/var/empty}"
  "PATH=/usr/bin:/bin:/usr/sbin:/sbin"
  "TMPDIR=${TMPDIR:-/tmp}"
)
ARGS=(
  --compile "$OUT"
  --platform macosx
  --app-icon "$PRIMARY_NAME"
  --output-partial-info-plist "$OUT/partial.plist"
  --minimum-deployment-target 12.0
)
for NAME in "${ALT_NAMES[@]}"; do
  ARGS+=(--alternate-app-icon "$NAME")
done

for DEV in "${CANDIDATES[@]}"; do
  [ -n "$DEV" ] || continue
  [ -x "$DEV/usr/bin/actool" ] || continue
  CLEAN_ENV[0]="DEVELOPER_DIR=$DEV"
  if env -i "${CLEAN_ENV[@]}" xcrun -sdk macosx actool "${ARGS[@]}" "${INPUTS[@]}" >/dev/null 2>&1; then
    echo "    actool OK ($DEV): $PRIMARY_NAME ${ALT_NAMES[*]:-}"
    rm -f "$OUT/partial.plist" "$OUT"/AlternateIcon_*.icns
    echo "==> Иконки macOS готовы: Assets.car + $PRIMARY_NAME.icns (${ALT_NAMES[*]:-без альтернатив})"
    exit 0
  fi
  echo "    actool ($DEV) не справился, пробую следующий тулчейн..." >&2
done

echo "ERROR: actool не смог скомпилировать иконки (нужен Xcode 27+)" >&2
exit 1