import 'package:flutter/material.dart';

class AppFrost {
  static const double sigma = 34;
  static const double panelSigma = 24;
  static const double glassAlpha = 0.28;
  static const double blurPanelAlpha = 0.55;

  static Color glassTint(ColorScheme cs, [double alpha = glassAlpha]) =>
      cs.surfaceContainerHigh.withValues(alpha: alpha);

  static Color blurPanelTint(ColorScheme cs) => glassTint(cs, blurPanelAlpha);

  static BorderSide hairline(ColorScheme cs) =>
      BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5);
}
