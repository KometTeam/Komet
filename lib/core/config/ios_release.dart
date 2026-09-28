import 'package:flutter/foundation.dart';

/// What the iOS build leaves out or does differently.
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

  /// The device spoofing screen is not offered on iOS. Only the settings
  /// and login entry points are hidden; the connect handshake still sends
  /// the stored device profile.
  static bool get spoofSettings => !isIOS;

  /// Plugins run downloaded JavaScript, which App Review does not allow
  /// for code that changes app behavior. iOS neither loads plugins nor
  /// offers their settings; built-in slash commands stay.
  static bool get plugins => !isIOS;

  /// Apps from the App Store are updated by the App Store, so iOS has no
  /// update check, settings button or update dialog.
  static bool get selfUpdate => !isIOS;
}
