import 'package:flutter/foundation.dart';

import '../../frontend/widgets/liquid_glass.dart';
import 'app_visual_style.dart';
import 'persisted_setting.dart';

// #***! оформление нижней таблетки
enum NavPillStyle { auto, glossy, frostBlur, liquidGlass }

// #***! auto подстраивается под общий стиль, стекло только если платформа тянет
class NavPillMaterial {
  static NavPillStyle resolve(NavPillStyle style) {
    if (style != NavPillStyle.auto) return style;
    return AppVisualStyle.current.value == VisualStyle.liquidGlass
        ? NavPillStyle.liquidGlass
        : NavPillStyle.glossy;
  }

  static bool isLiquid(NavPillStyle style) =>
      resolve(style) == NavPillStyle.liquidGlass && LiquidGlass.isSupported;

  static bool isFrost(NavPillStyle style) {
    final resolved = resolve(style);
    return resolved == NavPillStyle.frostBlur ||
        (resolved == NavPillStyle.liquidGlass && !LiquidGlass.isSupported);
  }
}

// #***! настройка нижней панели
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
