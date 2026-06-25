# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Komet is a cross-platform Flutter messaging client (Android, iOS, macOS, Windows, Linux, Web) that communicates via a custom packet-based protocol with MessagePack serialization and Zstd compression.

## Commands

```bash
flutter pub get          # install dependencies
flutter analyze          # lint / static analysis
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

## Build Flavors

| Flavor | App ID | Notes |
|--------|--------|-------|
| `komet` | `ru.komet.app` | Default, no FCM |
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

state/             — ChangeNotifier state classes consumed by the UI
models/            — plain data classes (User, Chat, Message, Call, Attachment, Session)

frontend/screens/  — full-page widgets grouped by feature (auth/, chats/, contacts/, calls/, profile/)
frontend/widgets/  — reusable components (message_bubble, chat_tile, avatar, etc.)
```

Data flow: UI → backend module → `api.dart` → transport layer → server.  
Incoming packets: transport → dispatcher → backend module → state → UI rebuild.

## Key Conventions (from AGENTS.md)

- **No comments in code.** Write self-documenting code instead.
- **Use `showCustomNotification(context, 'text')`** for all user-facing notifications — never use SnackBars.
- When a fix can be done quickly with a hack or properly with a rewrite, **choose the proper rewrite**.
- Quality over quantity.

## Localization

Two locales supported: English (`lib/l10n/app_en.arb`) and Russian (`lib/l10n/app_ru.arb`).  
Generated code is in `lib/l10n/` (produced by `flutter gen-l10n` via `l10n.yaml`).

## CI/CD

Four GitHub Actions workflows in `.github/workflows/`:

- `flutter-dev.yml` — PR lint + Android build for dev branch
- `flutter-main.yml` — PR lint + all-platform builds for main branch  
- `build-android.yml` — production APKs + AAB (`komet` flavor), triggered on push to main
- `build-android-fcm.yml` — production APKs + AAB (`oneme` flavor with FCM), triggered on push to main
