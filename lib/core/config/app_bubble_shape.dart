import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum BubbleStyle { iMessage }

class AppBubbleShape {
  static const prefKey = 'app_bubble_shape';

  static final _setting = PersistedEnum<BubbleStyle>(
    prefKey: prefKey,
    defaultValue: BubbleStyle.iMessage,
    encode: (value) => value.name,
    decode: _parse,
  );

  static ValueNotifier<BubbleStyle> get current => _setting.current;

  static Future<BubbleStyle> load() => _setting.load();

  static Future<void> save(BubbleStyle style) => _setting.save(style);

  static BubbleStyle _parse(String? val) =>
      BubbleStyle.iMessage;

  static String label(BubbleStyle style) => "iMessage";
}
