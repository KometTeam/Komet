import 'package:flutter/material.dart';

class AppFrost {
  static const double sigma = 34;
  static const double panelSigma = 24;

  static Color panelTint(ColorScheme cs) => cs.surface.withValues(alpha: 0.38);

  static Color blurPanelTint(ColorScheme cs) =>
      cs.surfaceContainerHigh.withValues(alpha: 0.55);

  static Color pillTint(ColorScheme cs) =>
      cs.surfaceContainerHigh.withValues(alpha: 0.45);

  static Color navPillTint(ColorScheme cs) =>
      cs.surfaceContainerHigh.withValues(alpha: 0.28);

  static Color fabTint(ColorScheme cs) => navPillTint(cs);

  static Color inputTint(ColorScheme cs) =>
      cs.surfaceContainerHighest.withValues(alpha: 0.45);

  static BorderSide hairline(ColorScheme cs) =>
      BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4), width: 0.5);
}
