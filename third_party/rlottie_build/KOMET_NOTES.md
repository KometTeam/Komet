# rlottie integration (Komet)

`third_party/rlottie` is a **git submodule** pinned to Samsung/rlottie
`f487eff2f8086b84ae1c7faa0418abec909e874b`. This directory (`rlottie_build/`)
holds Komet's build glue that lives *outside* the submodule (we can't commit into
upstream's tree).

After cloning or pulling, initialize the submodule:

```
git submodule update --init --recursive
```

CI does this via `submodules: recursive` on every `actions/checkout` step.

## What powers what

The native animated-reaction / animoji / sticker renderer. rlottie renders each
frame to a premultiplied BGRA buffer off the UI thread; the Dart side
(`lib/core/media/rlottie/`) uploads frames to `ui.Image`, caches them in RAM and
on disk, and plays them from cache — so the first playback is as smooth as later
loops. Web has no native path and falls back to the pure-Dart `lottie` player.

## Files here

- `CMakeLists.txt` — build wrapper for the CMake platforms (Linux/Windows/Android).
  Builds a single self-contained `rlottie` library from the submodule sources with
  `LOTTIE_MODULE OFF` (stb compiled in), `LOTTIE_THREAD ON`, `LOTTIE_CACHE ON`.
  Bypasses upstream's top-level CMakeLists (which references example/test) and
  drives `../rlottie/src` directly.
- `apple/config.h` — static replacement for the CMake-generated `config.h`, used
  by the CocoaPods build (which does not run CMake).
- `../rlottie.podspec` — compiles the submodule sources into the app for iOS/macOS
  (pod root is `third_party/`, so it can reference both the submodule and this glue).

## Build wiring

| Platform | How | Loaded via | Verified |
|----------|-----|-----------|----------|
| Linux    | `linux/CMakeLists.txt` → `add_subdirectory(rlottie_build)`, bundled to `lib/` | `DynamicLibrary.open('librlottie.so')` | ✅ full build + bundled .so |
| Android  | `android/app/build.gradle.kts` `externalNativeBuild` → `android/app/src/main/cpp/CMakeLists.txt` | `DynamicLibrary.open('librlottie.so')` | ✅ NDK r28c arm64 cross-compile |
| Windows  | `windows/CMakeLists.txt` → `add_subdirectory(rlottie_build)`, `rlottie.dll` next to exe | `DynamicLibrary.open('rlottie.dll')` | ⚠️ needs MSVC to verify |
| macOS    | `macos/Podfile` `pod 'rlottie', :path => '../third_party'` | `DynamicLibrary.process()` | ⚠️ needs Xcode to verify |
| iOS      | `ios/Podfile` `pod 'rlottie', :path => '../third_party'` | `DynamicLibrary.process()` | ⚠️ needs Xcode to verify |

## Gotchas for the unverified platforms

- **iOS/macOS symbols:** with `use_frameworks!` the `lottie_animation_*` symbols
  live in `rlottie.framework`. If `DynamicLibrary.process()` can't find them,
  switch the loader in `lib/core/media/rlottie/rlottie_ffi.dart` to
  `DynamicLibrary.open('rlottie.framework/rlottie')`.
- **Windows:** rlottie builds with `/EHs-c- /GR-` and links `Shlwapi.lib` (set in
  `CMakeLists.txt`).
- **32-bit ARM:** the pixman NEON `.S` asm is not wired; armv7 uses the C path.
- **Bumping rlottie:** `cd third_party/rlottie && git checkout <newsha>`, rebuild,
  then re-check `apple/config.h` and the podspec source globs still match upstream.
