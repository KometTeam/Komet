import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

// #***! сколько списка рисовать за экраном, больше плавнее но жрёт память
class AppCacheExtent {
  static const prefKey = 'app_cache_extent';
  static const double defaultValue = 5000;
  static const double min = 1000;
  static const double max = 10000;
  // #***! за этими порогами в настройках ругаемся
  static const double lowWarnThreshold = 2500;
  static const double highWarnThreshold = 7000;

  static final _setting = PersistedSetting<double>(
    prefKey: prefKey,
    defaultValue: defaultValue,
    read: (prefs, key) => prefs.getDouble(key),
    write: (prefs, key, value) async {
      await prefs.setDouble(key, value);
    },
    sanitize: clamp,
  );

  static ValueNotifier<double> get current => _setting.current;

  static Future<double> load() => _setting.load();

  static Future<void> save(double value) => _setting.save(value);

  // #***! подрезаем и введённое и старое сохранённое
  static double clamp(double v) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }
}
