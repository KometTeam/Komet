import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark, schedule }

class AppThemeModeConfig {
  static const prefKey = 'app_theme_mode';
  static final ValueNotifier<AppThemeMode> current = ValueNotifier(
    AppThemeMode.system,
  );

  static Future<AppThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(prefKey));
  }

  static Future<void> save(AppThemeMode mode) async {
    current.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, mode.name);
  }

  static AppThemeMode _parse(String? val) {
    switch (val) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      case 'schedule':
        return AppThemeMode.schedule;
      default:
        return AppThemeMode.system;
    }
  }

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
