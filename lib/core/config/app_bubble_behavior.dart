import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BubbleBehavior { mutable, immutable }

class AppBubbleBehavior {
  static const prefKey = 'app_bubble_behavior';
  static final ValueNotifier<BubbleBehavior> current = ValueNotifier(
    BubbleBehavior.mutable,
  );

  static Future<BubbleBehavior> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(prefKey);
    return _parse(val);
  }

  static Future<void> save(BubbleBehavior behavior) async {
    current.value = behavior;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, behavior.name);
  }

  static BubbleBehavior _parse(String? val) {
    if (val == BubbleBehavior.immutable.name) return BubbleBehavior.immutable;
    return BubbleBehavior.mutable;
  }

  static String label(BubbleBehavior behavior) {
    switch (behavior) {
      case BubbleBehavior.mutable:
        return 'Изменяемая';
      case BubbleBehavior.immutable:
        return 'Неизменяемая';
    }
  }
}
