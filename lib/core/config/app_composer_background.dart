import 'package:flutter/foundation.dart';

import '../../frontend/widgets/liquid_glass.dart';
import 'app_visual_style.dart';
import 'persisted_setting.dart';

// #***! фон поля ввода
enum ComposerBackground { standard, frostBlur, liquidGlass }

// #***! стекло не тянет платформа, тихо подставляем блюр
class ComposerMaterial {
  static bool isLiquid(ComposerBackground value) =>
      value == ComposerBackground.liquidGlass && LiquidGlass.isSupported;

  static bool isFrost(ComposerBackground value) =>
      value == ComposerBackground.frostBlur ||
      (value == ComposerBackground.liquidGlass && !LiquidGlass.isSupported);
}

class AppComposerBackground {
  static final ValueListenable<ComposerBackground> current = DerivedSetting(
    [AppVisualStyle.current],
    () => AppVisualStyle.current.value == VisualStyle.liquidGlass
        ? ComposerBackground.liquidGlass
        : ComposerBackground.standard,
  );
}
