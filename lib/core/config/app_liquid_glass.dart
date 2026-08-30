import 'package:flutter/material.dart';

// #***! параметры жидкого стекла, enabled false значит выключено везде
class AppLiquidGlass {
  static const bool enabled = false;

  // #***! подобрано на глаз, крутится только тут
  static const double blurSigma = 0;
  static const double spread = 1;
  static const double refraction = 34;
  static const double chroma = 0;
  static const double specular = 0.45;
  static const double rimWidth = 8;
  static const Offset light = Offset(-0.4, -1);
  static const double tintFeather = 44;

  static Color navTint(ColorScheme cs) =>
      cs.surfaceContainerHigh.withValues(alpha: 0);

  static Color panelTint(ColorScheme cs) => cs.surface.withValues(alpha: 0.24);
}
