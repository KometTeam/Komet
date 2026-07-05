import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

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

  static final _setting = PersistedSetting<int>(
    prefKey: prefKey,
    defaultValue: defaultValue,
    read: (prefs, key) => prefs.getInt(key),
    write: (prefs, key, value) async {
      await prefs.setInt(key, value);
    },
  );

  static ValueNotifier<int> get current => _setting.current;

  static Future<int> load() => _setting.load();

  static Future<void> save(int value) => _setting.save(value);
}
