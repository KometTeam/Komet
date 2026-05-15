import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized tactile feedback for Komet.
///
/// Wraps Flutter's [HapticFeedback] so the whole app speaks one tactile
/// "language": the same gesture always feels the same. Composite patterns
/// chain impacts with short delays to produce richer, more memorable
/// sensations than a single buzz.
///
/// Every call is best-effort and silent on failure — a device without a
/// vibrator (or with system haptics disabled) must never crash the UI.
class Haptics {
  Haptics._();

  static const String _prefKey = 'haptics_enabled';

  /// Master switch. Silences every haptic app-wide when `false`.
  /// Controlled by the user via Settings; persisted across launches.
  static bool enabled = true;

  /// Restores the saved preference. Call once during app startup,
  /// before the first frame. Defaults to enabled when never set.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {
      enabled = true;
    }
  }

  /// Updates the master switch and persists it.
  static Future<void> setEnabled(bool value) async {
    enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {
      // Persistence is best-effort; the in-memory switch still applies.
    }
  }

  static Future<void> _fire(Future<void> Function() effect) async {
    if (!enabled) return;
    try {
      await effect();
    } catch (_) {
      // Intentionally swallowed: haptics are a nicety, never a hard dependency.
    }
  }

  /// A crisp, light tick — taps, toggles, opening panels.
  static Future<void> tap() => _fire(HapticFeedback.lightImpact);

  /// A firmer press — confirmations, entering a mode.
  static Future<void> medium() => _fire(HapticFeedback.mediumImpact);

  /// A strong thud — destructive or weighty actions.
  static Future<void> heavy() => _fire(HapticFeedback.heavyImpact);

  /// The subtle detent of moving between discrete options — tabs, selection.
  static Future<void> selection() => _fire(HapticFeedback.selectionClick);

  /// Message sent: a quick, instant tick (the "whoosh").
  static Future<void> send() => tap();

  /// A two-beat rising pulse — success, completion, "it landed".
  static Future<void> success() async {
    if (!enabled) return;
    await _fire(HapticFeedback.lightImpact);
    await Future.delayed(const Duration(milliseconds: 90));
    await _fire(HapticFeedback.mediumImpact);
  }

  /// A double thud — errors, rejected or failed actions.
  static Future<void> error() async {
    if (!enabled) return;
    await _fire(HapticFeedback.heavyImpact);
    await Future.delayed(const Duration(milliseconds: 120));
    await _fire(HapticFeedback.heavyImpact);
  }
}
