import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

class AppMotion {
  static const prefKey = 'app_animations_enabled';
  static const bool defaultValue = true;

  static final _setting = PersistedSetting<bool>(
    prefKey: prefKey,
    defaultValue: defaultValue,
    read: (prefs, key) => prefs.getBool(key),
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static ValueNotifier<bool> get enabled => _setting.current;

  static Future<bool> load() => _setting.load();

  static Future<void> save(bool value) => _setting.save(value);

  static Duration of(Duration duration) =>
      enabled.value ? duration : Duration.zero;
}
