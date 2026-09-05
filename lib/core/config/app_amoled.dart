import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

// #***! чёрная тема для олед
class AppAmoled {
  static const prefKey = 'app_amoled';

  // #***! по дефолту как системная
  static bool get systemIsDark =>
      PlatformDispatcher.instance.platformBrightness == Brightness.dark;

  static final _setting = PersistedSetting<bool>(
    prefKey: prefKey,
    defaultValue: systemIsDark,
    read: (prefs, key) => prefs.getBool(key) ?? systemIsDark,
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static ValueNotifier<bool> get current => _setting.current;

  static Future<bool> load() => _setting.load();

  static Future<void> save(bool value) => _setting.save(value);
}
