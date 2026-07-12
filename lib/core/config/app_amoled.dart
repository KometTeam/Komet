import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

class AppAmoled {
  static const prefKey = 'app_amoled';

  static final _setting = PersistedSetting<bool>(
    prefKey: prefKey,
    defaultValue: false,
    read: (prefs, key) => prefs.getBool(key),
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static ValueNotifier<bool> get current => _setting.current;

  static Future<bool> load() => _setting.load();

  static Future<void> save(bool value) => _setting.save(value);
}
