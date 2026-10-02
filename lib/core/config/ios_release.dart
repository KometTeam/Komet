import 'package:flutter/foundation.dart';

import 'build_profile.dart';

/// What every iOS build leaves out or does differently.
///
/// Plugins, the update check and device spoofing depend on the App Store
/// build flag instead, see [BuildProfile.isAppStoreBuild].
///
/// Runtime checks on [defaultTargetPlatform] so Android and desktop keep
/// their behavior and tests can switch platforms with
/// `debugDefaultTargetPlatformOverride`.
abstract final class IosRelease {
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Contact exchange by tapping phones runs on Android host card
  /// emulation; iOS has no counterpart, so the entry point is hidden.
  static bool get nfcContactExchange => !isIOS;

  /// iOS always shows the message long-press menu as a list next to the
  /// message, as context menus do in iOS; the radial style and its setting
  /// are not offered.
  static bool get messageActionsStyleChoice => !isIOS;
}
