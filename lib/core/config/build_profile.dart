import 'package:flutter/services.dart' show appFlavor;

import 'ios_release.dart';
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
  /// flag and keep plugins and spoofing; the update check iOS leaves out in
  /// every build type, see [selfUpdate].
  ///
  /// The gates below are const, so the compiler drops the disabled code
  /// from App Store builds.
  static const bool isAppStoreBuild = LaunchFlags.appStoreBuild;

  /// Plugins and their settings; built-in slash commands stay either way.
  static const bool plugins = !isAppStoreBuild;

  /// Update check, settings button and update dialog.
  ///
  /// App Store builds drop it through the flag, and iOS and macOS need neither:
  /// App Store builds are updated by the App Store, Apple-signed mac Developer
  /// builds install a fresh binary the same way, and the manifest only carries
  /// Android assets. [isStore] and [isAppStoreBuild] still fold the gate to
  /// `false` at compile time where they are set.
  static bool get selfUpdate =>
      !isStore && !isAppStoreBuild && !IosRelease.isIOS && !IosRelease.isMacOS;
  static const bool firebasePush = appFlavor == 'oneme';

  /// Device spoofing screen. Only the settings and login entry points are
  /// hidden; the connect handshake still sends the stored device profile.
  static const bool spoofUi = !isStore && !isAppStoreBuild;
  static const bool tokenLogin = false;
  static const bool qrLogin = false;
  static const bool devTools = !isStore;
  static const bool insecureTransport = !isStore;
  static const bool trafficCapture = !isStore;
  static const bool pranks = !isStore;
  static const bool hiddenContentViewers = !isStore;
  static const bool digitalId = !isStore;
  static const bool ipGeoLookup = !isStore;
  static const bool sessionCityLookup = !isStore;

  // Pure versions of the gates above. dart-define values are fixed at
  // compile time, so tests check every combination through these.
  static bool pluginsFor({required bool appStoreBuild}) => !appStoreBuild;

  static bool selfUpdateFor({
    required bool store,
    required bool appStoreBuild,
    required bool ios,
    required bool macos,
  }) => !store && !appStoreBuild && !ios && !macos;

  static bool spoofUiFor({required bool store, required bool appStoreBuild}) =>
      !store && !appStoreBuild;
}
