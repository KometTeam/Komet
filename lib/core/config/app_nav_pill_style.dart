import 'package:flutter/foundation.dart';

import '../../frontend/widgets/liquid_glass.dart';
import 'persisted_setting.dart';

enum NavPillStyle { glossy, frostBlur, liquidGlass }

class NavPillMaterial {
  static bool isLiquid(NavPillStyle style) =>
      style == NavPillStyle.liquidGlass && LiquidGlass.isSupported;

  static bool isFrost(NavPillStyle style) =>
      style == NavPillStyle.frostBlur ||
      (style == NavPillStyle.liquidGlass && !LiquidGlass.isSupported);
}

class AppNavPillStyle {
  static const prefKey = 'app_nav_pill_style';

  static final _setting = PersistedEnum<NavPillStyle>(
    prefKey: prefKey,
    defaultValue: NavPillStyle.glossy,
    encode: (value) => value.name,
    decode: _parse,
  );

  static ValueNotifier<NavPillStyle> get current => _setting.current;

  static Future<NavPillStyle> load() => _setting.load();

  static Future<void> save(NavPillStyle value) => _setting.save(value);

  static NavPillStyle _parse(String? val) =>
      enumFromName(NavPillStyle.values, val, NavPillStyle.glossy);
}
