import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStories {
  static const prefKey = 'dev_stories';
  static const bool defaultValue = false;

  static final ValueNotifier<bool> current = ValueNotifier(defaultValue);

  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? defaultValue;
  }

  static Future<void> save(bool value) async {
    current.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }
}
