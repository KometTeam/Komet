import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppMediaCacheLimit {
  static const prefKey = 'media_cache_limit_bytes';
  static const int defaultValue = 500 * 1024 * 1024; // 500 МБ

  /// Значение «без лимита» — вытеснение из кэша отключено.
  static const int unlimited = 0;

  /// Доступные пресеты лимита, байты (0 — без лимита).
  static const List<int> presets = [
    100 * 1024 * 1024,
    250 * 1024 * 1024,
    500 * 1024 * 1024,
    1024 * 1024 * 1024,
    2 * 1024 * 1024 * 1024,
    unlimited,
  ];

  static final ValueNotifier<int> current = ValueNotifier(defaultValue);

  static Future<int> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(prefKey) ?? defaultValue;
  }

  static Future<void> save(int value) async {
    current.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefKey, value);
  }
}
