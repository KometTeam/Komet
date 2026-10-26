# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Komet is a cross-platform Flutter messaging client (Android, iOS, macOS, Windows, Linux, Web) that communicates via a custom packet-based protocol with MessagePack serialization and Zstd compression.

## Commands

```bash
flutter pub get          # install dependencies
flutter analyze lib test tool  # lint / static analysis (what CI runs)
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
Note that `flutter analyze` treats **info**-level lints as fatal by default, so CI fails on any lint.

### Launch flags

Every launch flag and build-time define is declared in one place, `LaunchFlags`
(`lib/core/config/launch_flags.dart`). `main()` parses the arguments once, logs the active set
as `Флаги запуска: …` and warns about unknown arguments. Add a new flag there, never as a
`String.fromEnvironment` or `args.contains` somewhere else.

| Argument              | dart-define                 | Effect                                                                  |
|-----------------------|-----------------------------|-------------------------------------------------------------------------|
| `--debug`             | `KOMET_DEBUG=true`          | every log level passes; every wire packet is logged with its JSON       |
| `--dw19p-im-crazy`    | `KOMET_DW19P_IM_CRAZY=true` | same, plus the payload of opcode 19 (`LOGIN`)                           |
| `--calldebug`         | `KOMET_CALL_DEBUG=true`     | only call logs (`[call…`, `[media]`, `CallBridge.`) at every level, no wire packets; `--debug` wins |
| `--debug-test`        | `DEBUG_TEST=true`           | fake-data mode: skips login, opens the shell as account `-424242`       |
| `--contacts N`        | `DEBUG_CONTACTS=N`          | implies `--debug-test` and generates N fake contacts                    |
| `--berserk`           | `BERSERK=true`              | drops the profile on login to exercise profile recovery                 |
| `--no-mute`           | `NO_MUTE=true`              | call audio keeps flowing while the mic is shown as muted                |
| —                     | `KOMET_LOG_LEVEL=…`         | minimum log level: `trace`…`fatal`, `off`                               |
| —                     | `KOMET_INSTANCE=name`       | separate app copy: own prefs, database, media cache and plugins         |
| —                     | `KOMET_UPDATE_BASE_URL=…`   | updater manifest base, default `https://cdn.komet.pw`, empty disables   |
| —                     | `KOMET_REVIEW_PHONE` + `_PAYLOAD` | Google Play review account, see *Review account*                  |
| —                     | `is_appstore_build=true`    | App Store build, trimmed by `BuildProfile`                              |

Without `--dw19p-im-crazy` the `LOGIN` payload is replaced by its length in both directions: it
carries the session token and the whole account snapshot. Payloads of every other opcode go out
verbatim — including `AUTH`/`AUTH_REQUEST` responses with their tokens — so a `--debug` log is
not safe to publish as is.

Packets are logged by `WireDebugLog` from `Api._onWireLog`, tagged `api<N>/<pre|auth|web>`, so
the two parallel sessions of the experimental "always SMS" login stay apart. Extra login
diagnostics are plain `logger.d` calls — release filters them out unless a flag is set. Long
lines are split into ≤900-char chunks so logcat does not truncate them.

Arguments reach `main()` only on desktop: `flutter run -d linux --dart-entrypoint-args=--debug`
(repeat the option per argument), or `./build/linux/x64/release/bundle/Komet --debug` for a built
bundle. On Android the engine is started by `audio_service` without entrypoint args, so mobile
builds take the dart-define: `flutter run --dart-define=KOMET_DEBUG=true`.

## Message encryption core

`komet_crypto` is a `dart:ffi` plugin over a C core. `KometTeam/crypto-core` is a **git
submodule** at `native/crypto-core`, and the plugin is a path dependency inside it, so the
version is pinned by the submodule commit. After cloning: `git submodule update --init --recursive`.
Every CI workflow already checks out with `submodules: recursive`.

The C core is the single implementation shared with Komet-Android (which points at a checkout via
`komet.crypto.dir`) — protocol and byte formats live in that repo's `docs/PROTOCOL.md`, never
reimplement them in Dart. Its own suite (`make test`, `make asan`) must pass before bumping the
submodule here.

## Sticker renderer

Animated stickers, animoji and reactions are rendered by [tlottie](https://github.com/dkaraush/tlottie)
(Rust) through the local FFI plugin `native/komet_tlottie`. Its wrapper crate pins tlottie by an
exact git `rev`, and the vendored cargokit compiles it during the Flutter build with the same
toolchain as `kolibri`; bump it by changing the `rev` and running `cargo update -p tlottie`.
`lib/core/media/tlottie/` renders frames in a pool of worker isolates and caches them in RAM and
on disk. Web has no native path and falls back to the pure-Dart `lottie` package.

The UI isolate never touches pixels. A clip is packed into atlas pages of 16 frames
(`AtlasLayout`, one texture per page instead of one per frame, with a transparent 2px gap so
filtering never samples the neighbouring frame), and the workers read and write the disk cache
(`TlottieCodec`) themselves. `TlottieEngine` hands a worker one job at a time, disk loads before
renders, cancels the job of a clip released before it finished (prewarm excepted) and respawns a
worker that died. A finished page reaches the UI isolate as a temp file under
`tlottie_pages/`, opened with `ImmutableBuffer.fromFilePath`, so the engine loads it off the UI
thread. `LottiePlayer` paints the current cell with a `CustomPainter`, so playback repaints without
rebuilding. Before this, one sticker meant ~90 `decodeImageFromPixels` calls and setStates on the UI
thread, and opening the sticker panel froze the app for up to 300 ms.

To run the engine test on the host, build the library with `cargo build --release` in
`native/komet_tlottie/rust` and pass it as `TLOTTIE_LIB`.

## Keyboard and chat panels

The chat follows Telegram: the composer's bottom is always `max(keyboard, visible sticker panel)`
(`StickerPanelController.visibleHeight`, applied in `ChatScreen` as the bottom inset). Opening the
panel over an open keyboard sets it to the keyboard height at once and hides the keyboard, which
slides away over it; going back to typing keeps the panel until the keyboard covers it or settles,
with a 1 s fallback. The last settled keyboard height is persisted per orientation. Sticker search
expands the panel to just under the app bar (`expandAnim`) and keeps it open over the keyboard.

On Android the attachment sheet opens **over** an open keyboard instead of closing it
(`KeyboardCover`, `lib/frontend/widgets/keyboard_cover.dart` + `KeyboardCover.kt`):

- a non-focusable child panel window is added over the FlutterView; Android layers such windows
  above the IME and the activity stays the IME target, so the keyboard remains open underneath;
- the FlutterView's surface is paused and the renderer swapped into a `SurfaceView` in that window
  — the same `pause`/`swapSurface`/`resume` path the embedding uses for `FlutterImageView`;
  touches are forwarded to the FlutterView, back goes to Flutter before the IME (a
  `PRIORITY_OVERLAY` callback on 33+, a pre-IME key hook in `FlutterHostFrame` below);
- the chat paints the keyboard band transparent (`KeyboardCoverHole`, `BlendMode.clear`) so the
  keyboard shows through until the sheet slides over it, and `KeyboardCoverScope` reports no
  keyboard to the rest of the app while the chat holds the keyboard's place itself;
- it is released after the sheet's exit animation, when another text field takes focus (the
  keyboard is hidden under the cover and reopened, so the caption rides up with it), when the IME
  closes, and on pause or resize. Not used on iOS, in embedded layouts or with touch exploration.

`FlutterHostFrame` wraps the FlutterFragment container. Besides the pre-IME back hook it re-applies
the last window insets to the FlutterView once IME animations settle: the embedding's
`ImeSyncDeferringInsetsCallback` holds insets until the IME animation's `onEnd`, and when that
end state is stale (overlapping animations, flutter/flutter#118761) or `onEnd` never comes, the
app stays lifted by the height of a keyboard that is already closed.

## WebRTC plugin fork

`flutter_webrtc` is overridden with the private fork `KometTeam/flutter-webrtc` (upstream v1.5.2 +
patches), pinned by commit in `dependency_overrides` in `pubspec.yaml`. To change the plugin, commit
in the fork, push, and bump the `ref`. The patches:

- desktop camera open/close and `getStats` run on background threads — libwebrtc does both through
  `Thread::BlockingCall` on its worker thread, and on Linux the window is drawn on the platform
  thread, so the UI froze for the 1–2 s a V4L2 camera takes to start;
- `VideoFrameTap` hands the frames of a video track to Dart: raw I420 on Linux/Windows, VP8 encoded
  with MediaCodec on Android.

CI fetches the fork with the repo secret `KOMET_DEPS_TOKEN` (read access to the fork): every Flutter
workflow rewrites the fork URL through workflow-level `GIT_CONFIG_*` env.

Call screen sharing follows MAX: in SERVER topology frames travel as VP8/VP9 over SFU data channels,
not as an RTP track — `consumerScreenShare` to send (`ScreenSharePipeline`, libvpx encoder in an
isolate on desktop), `producerScreenShare` to receive (`RemoteScreens`: libvpx → `ui.Image` on
desktop, MediaCodec → Flutter texture on Android). libvpx is loaded from the system on desktop.

## Build Flavors

| Flavor  | App ID         | Notes                               |
|---------|----------------|-------------------------------------|
| `komet` | `ru.komet.app` | Default, no FCM                     |
| `oneme` | `ru.oneme.app` | FCM push notifications via Firebase |
| `store` | `pw.komet.app` | Google Play build, trimmed by `BuildProfile` |

Flavor-specific Android resources live in `android/app/src/komet/`, `android/app/src/oneme/`
and `android/app/src/store/`.

The store build carries its own application id — `pw.komet.app`, the same identifier as the iOS
bundle — because `ru.komet.app` has already shipped outside Play. The Kotlin sources keep the
`ru.komet.app` namespace: component names in the manifest are absolute, and `MainActivity` derives
the launcher-alias package from its own class name, so the icon switch survives the rename.
`android/app/src/store/google-services.json` must repeat the same id or the Google Services plugin
fails the build.

## Review account

Google Play reviewers cannot receive an SMS from the MAX server, so the store build ships one
account they can open with an ordinary phone-and-code login. `ReviewAccess`
(`lib/core/config/review_access.dart`) holds two `--dart-define`s: `KOMET_REVIEW_PHONE`, the demo
number, and `KOMET_REVIEW_PAYLOAD`, a session token encrypted with the app's own crypto core
(Argon2id + ChaCha20-Poly1305). The key is derived from `<digits of the phone>:<code>`, so the
payload in the APK is worthless without the pair handed to the reviewer, and neither define is
committed — `build-android-play.yml` reads them from the `KOMET_REVIEW_PHONE` and
`KOMET_REVIEW_PAYLOAD` secrets. Without both defines `ReviewAccess.enabled` is false and the login
screen behaves exactly as before.

Entering the demo number skips `requestCode` and opens `CodeConfirmationScreen.review`, which
decrypts the payload with the typed code and signs in through `accountModule.loginWithToken`. The
payload is JSON: `{"token": "…"}`, plus an optional `"spoof"` object in `SpoofProfile.toJson()`
shape when the token has to be replayed with the device parameters it was issued for.

Regenerate the payload with the core's own cipher, so the format can never drift:

```bash
make -C native/crypto-core shared
printf '{"token":"…"}' | dart run tool/review_blob.dart '+7 999 999 99 99' '123456'
```

The tool derives the key exactly as `ReviewAccess` does and prints one space-free Cyrillic blob —
that string is the secret's value.

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

Wire framing, MessagePack, and Zstd (de)compression are handled by the `kolibri` Rust package
from pub.dev — `core/protocol/packet.dart` only wraps the already-decoded payload. There is no serialization work to move off the Dart isolate here; it never runs on it.

## Key Conventions (see [AGENTS.md](./AGENTS.md) for the full, canonical list)

- **No comments in code.** Write self-documenting code instead.
- **Use `showCustomNotification(context, 'text')`** for all user-facing notifications — never use SnackBars.
- **Feedback about one specific on-screen element goes through `showHintBubble(anchorContext, 'text')`** (`lib/frontend/widgets/hint_bubble.dart`) — an anchored bubble next to that element instead of the bottom notification. Pass the element's own context, not the screen's.
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
- **Opening a screen: pay in the first frame, not during the slide.** Routes with the
  `FirstFrameClock` mixin (`SwipeRoute`, and `FirstFramePageRoute` for Material transitions) start
  their clock at the first presented frame and absorb the stalls of the first three frames of a
  push, so a heavy first build only delays the transition, while a `setState` that lands
  mid-transition rebuilds the whole screen and drops visible frames. Put data that is already in
  memory (`chats.cachedChat`, `MessageSessionCache`) into `initState`; defer the rest — server
  responses included — with `RouteSettle.run`. A page that needs its route takes it from
  `RouteProbe` and hands it to `RouteSettle.bind` — `ModalRoute.of(context)` subscribes the caller
  to `isCurrent`, so a whole screen rebuilds whenever anything is pushed over it or popped. Subtrees
  without a `Hero` sit under `HeroMode(enabled: false)`, so `HeroController` does not walk them on
  each transition.

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
| `make_shortcut_icons.py`                                                             | `ic_shortcut_*` — launcher shortcut icons, glyphs from Material Symbols     |

**Themed icons.** Both adaptive icons carry a `<monochrome>` layer, so Android 13+
launchers with *Themed icons* enabled recolour the icon from the wallpaper. The
layer is only the alpha channel of the artwork filled black — the system supplies
both colours, and the same 16% inset as the foreground keeps it aligned with the
normal icon. The iOS 18 counterpart is the dark/tinted appearance pair on the
primary `AppIcon`; alternate icons cannot carry appearance variants.

**Launcher shortcuts.** Long-pressing the Android icon shows *Saved Messages* and
*Search*: `LauncherShortcuts.kt` publishes them as dynamic shortcuts on every
`MainActivity` start (the package differs per flavor, so a static `shortcuts.xml`
cannot name it). Each opens `komet://max.ru/<route>`, which `DeepLinkService` hands
to `openMaxRoute` as soon as the shell is up — these routes have `needsSession`
false and do not wait for login. They rank ahead of the conversation shortcuts
from `KometFcmService`, so the limit evicts old chats, never the actions.

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
`--dart-define=KOMET_UPDATE_BASE_URL`; it defaults to `https://cdn.komet.pw`
(`lib/core/config/update_config.dart`), so local builds check for updates too.
An empty URL makes the updater inert. `UpdateInstaller` verifies the downloaded
APK against the `size` and `sha256` recorded in the manifest.

The bucket must serve `s3:GetObject` anonymously — the updater sends no
credentials.

Required repo secrets: `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`.
Required repo variables: `S3_BUCKET`, `S3_PUBLIC_BASE_URL`.
Optional: `S3_ENDPOINT` (default `https://s3.twcstorage.ru`), `S3_REGION`
(default `ru-1`), `S3_KEEP_RELEASES`.
