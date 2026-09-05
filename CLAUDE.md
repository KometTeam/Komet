# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Komet is a cross-platform Flutter messaging client (Android, iOS, macOS, Windows, Linux, Web) that communicates via a custom packet-based protocol with MessagePack serialization and Zstd compression.

## Commands

```bash
flutter pub get          # install dependencies
flutter analyze lib test tool native/komet_crypto/lib  # lint / static analysis (what CI runs)
flutter run              # run on connected device (default: komet flavor)
flutter run --flavor oneme -t lib/main.dart  # run oneme flavor (FCM)

# Android builds (release builds use obfuscation; keep symbols to de-obfuscate crashes)
flutter build apk --release --flavor komet --obfuscate --split-debug-info=build/symbols
flutter build apk --release --split-per-abi --flavor komet --obfuscate --split-debug-info=build/symbols
flutter build appbundle --release --flavor komet --obfuscate --split-debug-info=build/symbols

# Other platforms
flutter build ios --release --no-codesign
flutter build macos --release
flutter build web --release
flutter build linux --release
flutter build windows --release
```

Android builds require **Java 17**. Gradle memory is configured to `-Xmx4096m`.

**Never run APK/AAB builds yourself** (`flutter build apk`, `flutter build appbundle`, gradle assemble tasks) — they are slow and the user builds them. Verify changes with the scoped `flutter analyze` above; the build commands are documentation only.
Always pass those directories: a bare `flutter analyze` also walks the vendored
`native/komet_crypto/cargokit/build_tool` package, whose dependencies are never resolved, and reports
~47 phantom errors. It is a nested package with its own `pubspec.yaml`, so `analyzer: exclude:` in
`analysis_options.yaml` cannot reach it — scoping the command is the only way to skip it.
Note also that `flutter analyze` treats **info**-level lints as fatal by default, so CI fails on any lint.

## Build Flavors

| Flavor  | App ID         | Notes                               |
|---------|----------------|-------------------------------------|
| `komet` | `ru.komet.app` | Default, no FCM                     |
| `oneme` | `ru.oneme.app` | FCM push notifications via Firebase |

Flavor-specific Android resources live in `android/app/src/komet/` and `android/app/src/oneme/`.

## Architecture

The codebase follows a strict layered architecture:

```
core/transport/    — raw socket I/O: connection, sender, receiver, dispatcher, proxy
core/protocol/     — Packet struct, opcode map, MessagePack + Zstd serialization
core/storage/      — SQLite (sqflite), secure token storage, spoofing service
core/push/         — FCM integration (oneme flavor only)
core/config/       — app config, proxy config, device presets, countries list

backend/api.dart   — session lifecycle: connect, handshake, ping, auto-reconnect
backend/modules/   — feature modules: account, messages, chats, contacts, calls, folders

models/            — plain data classes (User, Chat, Message, Call, Attachment, Session)

frontend/screens/  — full-page widgets grouped by feature (auth/, chats/, contacts/, calls/, profile/)
frontend/widgets/  — reusable components (message_bubble, chat_tile, avatar, etc.)
```

Data flow: UI → backend module → `api.dart` → transport layer → server.  
Incoming packets: transport → dispatcher → backend module → state → UI rebuild.

State is `ChangeNotifier`-based but not centralized in one directory: it lives next to the
feature it belongs to — e.g. `ChatListState` in `frontend/screens/chats/chat_list_screen.dart`,
`ChatController` in `frontend/screens/chats/chat/chat_controller.dart`, `PollsState` in
`backend/modules/polls.dart`. Colocate new state with its screen/module rather than adding a
top-level `state/` directory.

Wire framing, MessagePack, and Zstd (de)compression are handled by the Rust core (`kolibri`,
via `native/komet_crypto/`) — `core/protocol/packet.dart` only wraps the already-decoded
payload. There is no serialization work to move off the Dart isolate here; it never runs on it.

## Key Conventions (see [AGENTS.md](./AGENTS.md) for the full, canonical list)

- **No comments in code.** Write self-documenting code instead.
- **Use `showCustomNotification(context, 'text')`** for all user-facing notifications — never use SnackBars.
- When a fix can be done quickly with a hack or properly with a rewrite, **choose the proper rewrite**.
- Quality over quantity.
- **Never leave real data in test files**, including existing message contents or real IDs captured from requests. Use synthetic fixtures instead.
- **A button whose icon toggles between plain and slashed** (flash on/off, mic muted, sound, notifications) **must animate with a Lottie icon** — never swap two `Icon`s instantly. See *Animated icons* below.
- **Never `git commit` unless explicitly asked**, even for trivial changes — leave them in the working tree or stash instead.

## Flutter performance conventions

These are established patterns already in use in this codebase — follow them for new code
rather than introducing a different approach.

- **Heavy CPU work goes through `compute()`, not the main isolate.** `core/utils/image_utils.dart`
  and `core/media/image_optimizer.dart` already offload JPEG/AVIF encoding this way
  (`compute(_encodeAvatarFile, ...)`, `compute(_encodePhotoIsolate, ...)`). Follow the same
  pattern for any new CPU-bound Dart work (image/video processing, large data transforms).
  Note this does **not** apply to wire (de)serialization — MessagePack/Zstd is handled by the
  Rust core (`kolibri`), not Dart, so there's nothing to offload there.
- **`ListView.builder` + `ValueKey` is the norm for lists** (chat list, message list, contacts,
  attachments) — the codebase already uses this pattern in ~40 files. Keep using `ValueKey` on
  list items whose identity matters across rebuilds (reorder, delete, optimistic updates),
  otherwise Flutter can misattribute state to the wrong item.
- **Dispose what you subscribe.** `ChangeNotifier`-based controllers/state classes are colocated
  with their screen or module (see *Architecture* above, not a shared `state/` tree) — each one
  must cancel its `StreamSubscription`s and dispose its controllers (`AnimationController`,
  `TextEditingController`, etc.) in its own `dispose()`.
- **Prefer `const` constructors** wherever the widget's properties are compile-time constant —
  it lets Flutter skip rebuilding that subtree entirely.
- **Keep `build()` pure and cheap** — no network/IO calls, no heavy computation inline; extract
  reusable pieces into their own `StatelessWidget`s instead of nesting logic in one big builder.

## Animated icons

Everything in `assets/lottie/` is generated from the Material Symbols font by `tool/make_morph_icons.py` (stdlib-only Python, no deps). Never hand-edit the JSON — add a spec and re-run `python3 tool/make_morph_icons.py`.

| Kind                     | Spec list     | Widget              |
|--------------------------|---------------|---------------------|
| Morph between two glyphs | `SPECS`       | `ComposerMorphIcon` |
| Plain ↔ slashed toggle   | `SLASH_SPECS` | `LottieSlashIcon`   |

A slash spec takes the plain and slashed codepoints; the generator lays both glyphs out as static layers and sweeps a mask across the diagonal, so the slash looks drawn on top of the icon. Pass `fill=1.0` when the button renders `Icon(..., fill: 1)` — contours are then taken from the `FILL=1` instance of the variable font.

`LottieSlashIcon` plays the asset forward when `slashed` turns true and backward when it turns false, so a single asset covers both directions. The older `AnimatedSlashIcon` (clip wipe over two glyphs) stays where it is already used; new buttons use the Lottie one.

## App icons

Two launcher icons ship: the default comet and the `Minimal` meteor, switched at
runtime by `AppIconConfig` (Android activity-alias, iOS alternate icon). Every
launcher resource is *derived* from `assets/komet.png` / `assets/meteor.png` by a
script in `tool/`, so the source art lives in exactly one place:

| Script                                                                               | Produces                                                                    |
|--------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| `make_icon_bg.dart`                                                                  | `*_icon.png` — the same art flattened on black                              |
| `make_minimal_android.dart` / `make_minimal_adaptive.dart` / `make_minimal_ios.dart` | the `Minimal` launcher + adaptive layers                                    |
| `make_monochrome_android.dart`                                                       | `ic_launcher[_minimal]_monochrome.png` — alpha silhouettes for themed icons |
| `make_appearances_ios.dart`                                                          | `Icon-App-{Dark,Tinted}-1024x1024@1x.png` + their `Contents.json` entries   |

**Themed icons.** Both adaptive icons carry a `<monochrome>` layer, so Android 13+
launchers with *Themed icons* enabled recolour the icon from the wallpaper. The
layer is only the alpha channel of the artwork filled black — the system supplies
both colours, and the same 16% inset as the foreground keeps it aligned with the
normal icon. The iOS 18 counterpart is the dark/tinted appearance pair on the
primary `AppIcon`; alternate icons cannot carry appearance variants.

`flutter_launcher_icons` (configured in `pubspec.yaml`) only generates the default
icon and rewrites `mipmap-anydpi-v26/*.xml` without the insets or the monochrome
layer, so re-run the `tool/` scripts and restore those XMLs after invoking it.

## Localization

Two locales supported: English (`lib/l10n/app_en.arb`) and Russian (`lib/l10n/app_ru.arb`).  
Generated code is in `lib/l10n/` (produced by `flutter gen-l10n` via `l10n.yaml`).

## CI/CD

Four GitHub Actions workflows in `.github/workflows/`:

- `flutter-dev.yml` — PR lint + Android build for dev branch
- `flutter-main.yml` — PR lint + all-platform builds for main branch  
- `build-android.yml` — production APKs + AAB (`komet` flavor), triggered on push to main
- `build-android-fcm.yml` — production APKs + AAB (`oneme` flavor with FCM), triggered on push to main

### Release distribution (S3)

`release-dev.yml` (branch `dev/0.5.0`) mirrors every pre-release to a Timeweb S3
bucket through `.github/scripts/publish-s3.sh`: artifacts land in
`releases/<version>-dev.<build>/` and a `latest.json` manifest is written to the
bucket root with `no-cache`. `release-main.yml` only publishes a GitHub Release —
both workflows share one bucket and one manifest, so only one of them may own it.

The manifest carries `version` and `build` read from `pubspec.yaml`, i.e. exactly
what is compiled into the APK — not the git tag, whose build counter comes from the
run number and would always look newer than the installed app.

The bucket holds 1 GB and a full release set is ~500 MB, so old release prefixes
are pruned *before* the upload (`PRUNE_BEFORE_UPLOAD`, default 1) — uploading first
would peak at ~1 GB and hit the quota. The trade-off is a few minutes during which
the previous manifest points at deleted files. `KEEP_RELEASES` (default 1) sets how
many releases survive. App Bundles are skipped (`EXCLUDE_GLOBS`, default `*.aab`):
they are 114 MB each, only Google Play consumes them, and they stay on GitHub.

The in-app updater (`UpdateChecker`) reads that manifest and nothing else; GitHub
Releases stay as a human-facing mirror. The bucket URL comes from the
`S3_PUBLIC_BASE_URL` repo variable and is baked into builds as
`--dart-define=KOMET_UPDATE_BASE_URL`; it defaults to `https://dl.komet.pw`
(`lib/core/config/update_config.dart`), so local builds check for updates too.
An empty URL makes the updater inert. `UpdateInstaller` verifies the downloaded
APK against the `size` and `sha256` recorded in the manifest.

The bucket must serve `s3:GetObject` anonymously — the updater sends no
credentials.

Required repo secrets: `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`.
Required repo variables: `S3_BUCKET`, `S3_PUBLIC_BASE_URL`.
Optional: `S3_ENDPOINT` (default `https://s3.twcstorage.ru`), `S3_REGION`
(default `ru-1`), `S3_KEEP_RELEASES`.
