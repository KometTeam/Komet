import '../dynamiccolor/dynamic_scheme.dart';

/// A scheme that places the source color in Scheme.primaryContainer.
///
/// Primary Container is the source color, adjusted for color relativity. It maintains constant
/// appearance in light mode and dark mode. This adds ~5 tone in light mode, and subtracts ~5 tone in
/// dark mode.
///
/// Tertiary Container is the complement to the source color, using TemperatureCache. It also
/// maintains constant appearance.
@Deprecated("Use DynamicScheme directly instead")
class SchemeFidelity extends DynamicScheme {
  SchemeFidelity({
    required super.sourceColorHct,
    required super.isDark,
    required super.contrastLevel,
    super.specVersion = DynamicScheme.defaultSpecVersion,
    super.platform = DynamicScheme.defaultPlatform,
  }) : super.fromPalettesOrKeyColors(variant: .vibrant);
}
