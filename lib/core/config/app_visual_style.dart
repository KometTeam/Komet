import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VisualStyle { materialYou, glossy }

class AppVisualStyle {
  static const prefKey = 'app_visual_style';
  static final ValueNotifier<VisualStyle> current =
      ValueNotifier(VisualStyle.materialYou);

  static Future<VisualStyle> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefKey) == 'glossy'
        ? VisualStyle.glossy
        : VisualStyle.materialYou;
  }

  static Future<void> save(VisualStyle value) async {
    current.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefKey,
      value == VisualStyle.glossy ? 'glossy' : 'materialYou',
    );
  }
}
