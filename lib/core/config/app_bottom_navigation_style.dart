import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum BottomNavigationStyle { floating, compact }

class AppBottomNavigationStyle {
  static const prefKey = 'app_bottom_navigation_style';

  static final _setting = PersistedEnum<BottomNavigationStyle>(
    prefKey: prefKey,
    defaultValue: BottomNavigationStyle.floating,
    encode: (value) => value.name,
    decode: (value) => enumFromName(
      BottomNavigationStyle.values,
      value,
      BottomNavigationStyle.floating,
    ),
  );

  static ValueNotifier<BottomNavigationStyle> get current => _setting.current;

  static Future<BottomNavigationStyle> load() => _setting.load();

  static Future<void> save(BottomNavigationStyle value) => _setting.save(value);
}
