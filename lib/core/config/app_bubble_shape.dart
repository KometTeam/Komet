import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BubbleStyle { mobile, desktop }

class AppBubbleShape {
  static const prefKey = 'app_bubble_shape';
  static final ValueNotifier<BubbleStyle> current = ValueNotifier(
    BubbleStyle.mobile,
  );

  static Future<BubbleStyle> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(prefKey);
    return _parse(val);
  }

  static Future<void> save(BubbleStyle style) async {
    current.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, style.name);
  }

  static BubbleStyle _parse(String? val) {
    if (val == BubbleStyle.desktop.name) return BubbleStyle.desktop;
    return BubbleStyle.mobile;
  }

  static String label(BubbleStyle style) {
    switch (style) {
      case BubbleStyle.mobile:
        return 'TG Mobile';
      case BubbleStyle.desktop:
        return 'TG Desktop';
    }
  }
}
