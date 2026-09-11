# fjs Cargokit Build Tool

This package is the local Cargokit build tool used by fjs. It is based on the
Flutter Rust Bridge Cargokit integration and is vendored here so the Flutter
plugin can build Rust artifacts without depending on a globally installed Dart
package.

The entrypoint is normally invoked through:

```sh
cargokit/run_build_tool.sh <command> ...
```

`run_build_tool.sh` creates a temporary Dart runner, compiles it to a kernel
snapshot, and invalidates that snapshot when this package changes.

## Commands

### build-pod

Used by the iOS, macOS, and shared Darwin podspecs:

```sh
cargokit/run_build_tool.sh build-pod libfjs fjs
```

Flutter and CocoaPods provide the required `CARGOKIT_*` and Xcode deployment
environment variables. The command builds the Rust crate for the active Darwin
platform and copies `libfjs.a` into the configured build output directory.

### build-gradle

Used by Android builds. Flutter/Gradle provide Android SDK, NDK, target platform,
and output directories through `CARGOKIT_*` environment variables.

### build-cmake

Used by desktop CMake-based builds. The command builds the Rust crate for the
requested desktop target and copies the produced dynamic library into the
configured output directory.

### gen-key

Generates an Ed25519 key pair for signing precompiled Cargokit artifacts:

```sh
cargokit/run_build_tool.sh gen-key
```

Store the private key in CI secrets only. Put the public key in
`libfjs/cargokit.yaml`.

### precompile-binaries

Builds release Rust artifacts, signs them, and uploads them to a GitHub Release
tag named `precompiled_<crate-hash>`:

```sh
PRIVATE_KEY=<hex-private-key> \
GITHUB_TOKEN=<github-token> \
cargokit/run_build_tool.sh precompile-binaries \
  --repository fluttercandies/fjs \
  --manifest-dir libfjs
```

Pass `--target <rust-triple>` one or more times to publish a subset of targets.
When omitted, the tool builds targets that are buildable on the current host and
adds Android targets when Android SDK options are provided.

### verify-binaries

Checks that every configured precompiled artifact exists and that its signature
matches `libfjs/cargokit.yaml`:

```sh
cargokit/run_build_tool.sh verify-binaries --manifest-dir libfjs
```

This command verifies per-target Cargokit artifacts. It does not validate the
SwiftPM XCFramework zip; use `tool/prepare_darwin_release.sh` for that release
path.

## Configuration

Crate-level settings live in `libfjs/cargokit.yaml`:

```yaml
precompiled_binaries:
  url_prefix: https://github.com/fluttercandies/fjs/releases/download/precompiled_
  public_key: <32-byte-ed25519-public-key-hex>
```

User-level settings are read from the nearest `cargokit_options.yaml` found by
walking upward from `CARGOKIT_ROOT_PROJECT_DIR`:

```yaml
use_precompiled_binaries: true
verbose_logging: false
```

Default behavior:

- If Rustup is available, builds use local Rust source.
- If Rustup is missing, builds try signed precompiled binaries.
- `use_precompiled_binaries: true` opts in to precompiled downloads even when
  Rustup is available.
- `use_precompiled_binaries: false` forces local Rust builds.

## Darwin XCFramework Release Flow

CocoaPods and the Swift Package Manager artifact share the same Rust source and
Cargokit build inputs, but the XCFramework is packaged by repository scripts:

```sh
tool/build_fjs_xcframework.sh --configuration Release
tool/prepare_darwin_release.sh --configuration Release
```

`tool/build_fjs_xcframework.sh` writes a temporary options file that sets
`use_precompiled_binaries: false`, so the release XCFramework is built from the
current local Rust source. `tool/prepare_darwin_release.sh` then creates
`build/darwin-release/fjs.xcframework.zip`, writes the SwiftPM checksum, checks
Darwin package metadata, and runs `flutter pub publish --dry-run`.
