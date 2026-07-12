import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum BubbleBehavior { mutable, immutable }

class AppBubbleBehavior {
  static const prefKey = 'app_bubble_behavior';

  static final _setting = PersistedEnum<BubbleBehavior>(
    prefKey: prefKey,
    defaultValue: BubbleBehavior.mutable,
    encode: (value) => value.name,
    decode: _parse,
  );

  static ValueNotifier<BubbleBehavior> get current => _setting.current;

  static Future<BubbleBehavior> load() => _setting.load();

  static Future<void> save(BubbleBehavior behavior) => _setting.save(behavior);

  static BubbleBehavior _parse(String? val) =>
      enumFromName(BubbleBehavior.values, val, BubbleBehavior.mutable);

  static String label(BubbleBehavior behavior) {
    switch (behavior) {
      case BubbleBehavior.mutable:
        return 'Изменяемая';
      case BubbleBehavior.immutable:
        return 'Неизменяемая';
    }
  }
}
