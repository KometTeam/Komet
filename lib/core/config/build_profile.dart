import 'package:flutter/services.dart' show appFlavor;

import 'launch_flags.dart';

// #***! что включено в сборке, всё считается на компиляции из flavor
abstract final class BuildProfile {
  static const String storeFlavor = 'store';

  // #***! store сборка урезана, без самообновления дев инструментов и спуфа
  static const bool isStore = appFlavor == storeFlavor;

  /// App Store build, set with `--dart-define=is_appstore_build=true`.
  ///
  /// Plugins run downloaded JavaScript, which App Review does not allow for
  /// code that changes app behavior, and apps from the App Store are updated
  /// by the App Store. Such builds leave out plugins, the update check and
  /// the device spoofing screen. Sideloaded iOS builds are made without the
  /// flag and keep all of them, like Android.
  ///
  /// The gates below are const, so the compiler drops the disabled code
  /// from App Store builds.
  static const bool isAppStoreBuild = LaunchFlags.appStoreBuild;

  /// Any build reviewed by a store, Google Play or the App Store. Features
  /// that store rules forbid are cut by this one flag on both platforms.
  static const bool isStoreRelease = isStore || isAppStoreBuild;

  /// Plugins and their settings; built-in slash commands stay either way.
  static const bool plugins = !isAppStoreBuild;

  /// Update check, settings button and update dialog.
  static const bool selfUpdate = !isStore && !isAppStoreBuild;
  static const bool firebasePush = appFlavor == 'oneme';

  /// Device spoofing screen. Only the settings and login entry points are
  /// hidden; the connect handshake still sends the stored device profile.
  static const bool spoofUi = !isStore && !isAppStoreBuild;
  static const bool tokenLogin = false;
  static const bool qrLogin = false;
  static const bool devTools = !isStoreRelease;
  static const bool insecureTransport = !isStoreRelease;
  static const bool trafficCapture = !isStoreRelease;
  static const bool pranks = !isStoreRelease;
  static const bool hiddenContentViewers = !isStoreRelease;
  static const bool digitalId = !isStoreRelease;
  static const bool ipGeoLookup = !isStoreRelease;
  static const bool sessionCityLookup = !isStoreRelease;

  /// Ghost mode and anti read hide presence and read receipts from other
  /// people, which App Review treats as working around their privacy.
  static const bool stealthPresence = !isAppStoreBuild;

  /// The `komet://export-logs` link, an undocumented entry point.
  static const bool logExportLink = !isAppStoreBuild;

  // Pure versions of the gates above. dart-define values are fixed at
  // compile time, so tests check every combination through these.
  static bool pluginsFor({required bool appStoreBuild}) => !appStoreBuild;

  static bool selfUpdateFor({
    required bool store,
    required bool appStoreBuild,
  }) => !store && !appStoreBuild;

  static bool spoofUiFor({required bool store, required bool appStoreBuild}) =>
      !store && !appStoreBuild;

  static bool storeReleaseFor({
    required bool store,
    required bool appStoreBuild,
  }) => store || appStoreBuild;
}
