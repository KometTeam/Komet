import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPillGradient {
  static const prefKey = 'app_pill_gradient';
  static final ValueNotifier<bool> current = ValueNotifier(true);

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? true;
  }

  static Future<void> save(bool value) async {
    current.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }
}
