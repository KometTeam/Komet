import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLinkPreview {
  static const prefKey = 'dev_link_preview';
  static const bool defaultValue = true;

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
