import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

class AppNotifications {
  static const prefKey = 'notifications_enabled';

  static final _setting = PersistedSetting<bool>(
    prefKey: prefKey,
    defaultValue: true,
    read: (prefs, key) => prefs.getBool(key),
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static ValueNotifier<bool> get enabled => _setting.current;

  static Future<bool> load() => _setting.load();

  static Future<void> setEnabled(bool value) => _setting.save(value);
}
