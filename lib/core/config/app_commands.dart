import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'persisted_setting.dart';

// #***! слэш команды в поле ввода, экспериментальное
class AppCommands {
  static const prefKey = 'dev_commands';
  static const bool defaultValue = true;

  static final _setting = PersistedSetting<bool>(
    prefKey: prefKey,
    defaultValue: defaultValue,
    read: (prefs, key) => prefs.getBool(key),
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static ValueNotifier<bool> get current => _setting.current;

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(prefKey)) {
      //migration kostyl'
      await save(true);
      return true;
    }
    return _setting.load();
  }

  static Future<void> save(bool value) => _setting.save(value);
}
