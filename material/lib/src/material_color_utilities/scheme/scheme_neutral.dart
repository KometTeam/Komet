import '../dynamiccolor/dynamic_scheme.dart';

/// A theme that's slightly more chromatic than monochrome, which is purely black / white / gray.
@Deprecated("Use DynamicScheme directly instead")
class SchemeNeutral extends DynamicScheme {
  SchemeNeutral({
    required super.sourceColorHct,
    required super.isDark,
    required super.contrastLevel,
    super.specVersion = DynamicScheme.defaultSpecVersion,
    super.platform = DynamicScheme.defaultPlatform,
  }) : super.fromPalettesOrKeyColors(variant: .neutral);
}
