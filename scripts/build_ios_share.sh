#!/bin/bash
set -euo pipefail

share_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
share_crate="$share_root/native/komet_share"
share_target_dir="${CARGO_TARGET_DIR:-$share_crate/target}"
share_output_dir="${BUILT_PRODUCTS_DIR:?}/KometShareTransport"
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"

if ! command -v cargo >/dev/null 2>&1; then
  echo "error: Rust is required to build Komet ShareExtension. Install Rust and the Apple iOS targets." >&2
  exit 1
fi

share_libraries=()
for share_arch in ${ARCHS:?}; do
  case "${PLATFORM_NAME:?}:$share_arch" in
    iphoneos:arm64) share_target=aarch64-apple-ios ;;
    iphonesimulator:arm64) share_target=aarch64-apple-ios-sim ;;
    iphonesimulator:x86_64) share_target=x86_64-apple-ios ;;
    *)
      echo "error: Unsupported Komet ShareExtension platform/architecture: $PLATFORM_NAME/$share_arch" >&2
      exit 1
      ;;
  esac

  cargo build --locked --release --manifest-path "$share_crate/Cargo.toml" \
    --target "$share_target" --target-dir "$share_target_dir"
  share_libraries+=("$share_target_dir/$share_target/release/libkomet_share.a")
done

mkdir -p "$share_output_dir"
if [ "${#share_libraries[@]}" -eq 1 ]; then
  cp "${share_libraries[0]}" "$share_output_dir/libkomet_share.a.tmp"
else
  xcrun lipo -create "${share_libraries[@]}" -output "$share_output_dir/libkomet_share.a.tmp"
fi
mv "$share_output_dir/libkomet_share.a.tmp" "$share_output_dir/libkomet_share.a"
