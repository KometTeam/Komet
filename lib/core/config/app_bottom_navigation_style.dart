import 'package:flutter/foundation.dart';

import 'app_visual_style.dart';
import 'persisted_setting.dart';

enum BottomNavigationStyle { floating, compact }

class AppBottomNavigationStyle {
  static final ValueListenable<BottomNavigationStyle> current = DerivedSetting(
    [AppVisualStyle.current],
    () => AppVisualStyle.current.value.glossyChrome
        ? BottomNavigationStyle.floating
        : BottomNavigationStyle.compact,
  );
}
