import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum AppThemeMode { system, light, dark, schedule }

class AppThemeModeConfig {
  static const prefKey = 'app_theme_mode';

  static final _setting = PersistedEnum<AppThemeMode>(
    prefKey: prefKey,
    defaultValue: AppThemeMode.system,
    encode: (mode) => mode.name,
    decode: _parse,
  );

  static ValueNotifier<AppThemeMode> get current => _setting.current;

  static Future<AppThemeMode> load() => _setting.load();

  static Future<void> save(AppThemeMode mode) => _setting.save(mode);

  static AppThemeMode _parse(String? val) =>
      enumFromName(AppThemeMode.values, val, AppThemeMode.system);

  static String label(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'Системная';
      case AppThemeMode.light:
        return 'Светлая';
      case AppThemeMode.dark:
        return 'Тёмная';
      case AppThemeMode.schedule:
        return 'По расписанию';
    }
  }
}
