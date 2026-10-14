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

class AppNavPillStyle {
  static final ValueListenable<NavPillStyle> current = DerivedSetting(
    [AppVisualStyle.current, AppElementsBlur.current],
    () => switch (AppVisualStyle.current.value) {
      VisualStyle.materialYou => NavPillStyle.auto,
      VisualStyle.glossy =>
        AppElementsBlur.current.value
            ? NavPillStyle.frostBlur
            : NavPillStyle.glossy,
      VisualStyle.liquidGlass => NavPillStyle.liquidGlass,
    },
  );
}
