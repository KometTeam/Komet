import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

// #***! потолок всего вытесняемого кэша, 0 значит не чистить вообще
class AppCacheLimit {
  static const prefKey = 'media_cache_limit_bytes';
  static const int defaultValue = 1024 * 1024 * 1024;

  static const int unlimited = 0;

  static const List<int> presets = [
    250 * 1024 * 1024,
    500 * 1024 * 1024,
    1024 * 1024 * 1024,
    2 * 1024 * 1024 * 1024,
    5 * 1024 * 1024 * 1024,
    10 * 1024 * 1024 * 1024,
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
