import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum BubbleStyle { mobile, desktop }

class AppBubbleShape {
  static const prefKey = 'app_bubble_shape';

  static final _setting = PersistedEnum<BubbleStyle>(
    prefKey: prefKey,
    defaultValue: BubbleStyle.mobile,
    encode: (value) => value.name,
    decode: _parse,
  );

  static ValueNotifier<BubbleStyle> get current => _setting.current;

  static Future<BubbleStyle> load() => _setting.load();

  static Future<void> save(BubbleStyle style) => _setting.save(style);

  static BubbleStyle _parse(String? val) =>
      enumFromName(BubbleStyle.values, val, BubbleStyle.mobile);

  static String label(BubbleStyle style) {
    switch (style) {
      case BubbleStyle.mobile:
        return 'TG Mobile';
      case BubbleStyle.desktop:
        return 'TG Desktop';
    }
  }
}
