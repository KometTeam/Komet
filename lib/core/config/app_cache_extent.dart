import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppCacheExtent {
  static const prefKey = 'app_cache_extent';
  static const double defaultValue = 5000;
  static const double min = 1000;
  static const double max = 10000;
  static const double lowWarnThreshold = 2500;
  static const double highWarnThreshold = 7000;

  static final ValueNotifier<double> current = ValueNotifier(defaultValue);

  static Future<double> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getDouble(prefKey);
    if (raw == null) return defaultValue;
    return clamp(raw);
  }

  static Future<void> save(double value) async {
    final clamped = clamp(value);
    current.value = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(prefKey, clamped);
  }

  static double clamp(double v) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }
}
