import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAmoled {
  static const prefKey = 'app_amoled';
  static final ValueNotifier<bool> current = ValueNotifier(false);

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  static Future<void> save(bool value) async {
    current.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }
}
