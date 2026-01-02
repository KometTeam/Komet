import '../dynamiccolor/dynamic_scheme.dart';

/// A playful theme - the source color's hue does not appear in the theme.
@Deprecated("Use DynamicScheme directly instead")
class SchemeRainbow extends DynamicScheme {
  SchemeRainbow({
    required super.sourceColorHct,
    required super.isDark,
    required super.contrastLevel,
    super.specVersion = DynamicScheme.defaultSpecVersion,
    super.platform = DynamicScheme.defaultPlatform,
  }) : super.fromPalettesOrKeyColors(variant: .rainbow);
}
