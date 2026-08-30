import 'package:flutter/material.dart';

// #***! константы матового стекла для всех панелей
class AppFrost {
  static const double sigma = 34;
  static const double panelSigma = 24;
  static const double overlaySigma = 18;
  static const double mediaBackdropSigma = 30;
  static const double glassAlpha = 0.28;
  static const double blurPanelAlpha = 0.55;
  static const double scrimAlpha = 0.4;

  // #***! подкрашиваем блюр темой иначе он грязный
  static Color glassTint(ColorScheme cs, [double alpha = glassAlpha]) =>
      cs.surfaceContainerHigh.withValues(alpha: alpha);

  static Color blurPanelTint(ColorScheme cs) => glassTint(cs, blurPanelAlpha);

  static Color scrim([double alpha = scrimAlpha]) =>
      Colors.black.withValues(alpha: alpha);

  // #***! волосяная линия на краю стеклянной панели
  static BorderSide hairline(ColorScheme cs) =>
      BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5);
}
