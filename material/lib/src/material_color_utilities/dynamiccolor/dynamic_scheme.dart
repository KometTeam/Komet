import 'dart:math' as math;

import '../utils/math_utils.dart';
import '../hct/hct.dart';
import '../palettes/tonal_palette.dart';

import 'color_spec.dart';
import 'color_specs.dart';
import 'dynamic_color.dart';
import 'material_dynamic_colors.dart';
import 'variant.dart';

/// The platform on which this scheme is intended to be used.
enum Platform { phone, watch }

/// Provides important settings for creating colors dynamically,
/// and 6 color palettes.
///
/// Requires:
/// 1. A color. (source color)
/// 2. A theme. (Variant)
/// 3. Whether or not its dark mode.
/// 4. Contrast level. (-1 to 1, currently contrast ratio 3.0 and 7.0)
class DynamicScheme {
  DynamicScheme({
    required this.sourceColorHct,
    required this.variant,
    required this.isDark,
    required this.contrastLevel,
    this.platform = defaultPlatform,
    SpecVersion specVersion = defaultSpecVersion,
    required this.primaryPalette,
    required this.secondaryPalette,
    required this.tertiaryPalette,
    required this.neutralPalette,
    required this.neutralVariantPalette,
    TonalPalette? errorPalette,
  }) : sourceColorArgb = sourceColorHct.toInt(),
       specVersion = _maybeFallbackSpecVersion(specVersion, variant),
       errorPalette = errorPalette ?? .fromHueAndChroma(25.0, 84.0);

  DynamicScheme._fromPalettesOrKeyColors({
    required this.sourceColorHct,
    required this.isDark,
    required this.contrastLevel,
    required this.specVersion,
    required this.platform,
    required this.variant,
    TonalPalette? primaryPalette,
    TonalPalette? secondaryPalette,
    TonalPalette? tertiaryPalette,
    TonalPalette? neutralPalette,
    TonalPalette? neutralVariantPalette,
    TonalPalette? errorPalette,
    Hct? primaryPaletteKeyColor,
    Hct? secondaryPaletteKeyColor,
    Hct? tertiaryPaletteKeyColor,
    Hct? neutralPaletteKeyColor,
    Hct? neutralVariantPaletteKeyColor,
    Hct? errorPaletteKeyColor,
  }) : assert(primaryPalette == null || primaryPaletteKeyColor == null),
       assert(secondaryPalette == null || secondaryPaletteKeyColor == null),
       assert(tertiaryPalette == null || tertiaryPaletteKeyColor == null),
       assert(neutralPalette == null || neutralPaletteKeyColor == null),
       assert(
         neutralVariantPalette == null || neutralVariantPaletteKeyColor == null,
       ),
       assert(errorPalette == null || errorPaletteKeyColor == null),
       sourceColorArgb = sourceColorHct.toInt(),
       primaryPalette =
           primaryPalette ??
           ColorSpecs.get(specVersion).getPrimaryPalette(
             variant,
             primaryPaletteKeyColor ?? sourceColorHct,
             isDark,
             platform,
             contrastLevel,
           ),
       secondaryPalette =
           secondaryPalette ??
           ColorSpecs.get(specVersion).getSecondaryPalette(
             variant,
             secondaryPaletteKeyColor ?? sourceColorHct,
             isDark,
             platform,
             contrastLevel,
           ),
       tertiaryPalette =
           tertiaryPalette ??
           ColorSpecs.get(specVersion).getTertiaryPalette(
             variant,
             tertiaryPaletteKeyColor ?? sourceColorHct,
             isDark,
             platform,
             contrastLevel,
           ),
       neutralPalette =
           neutralPalette ??
           ColorSpecs.get(specVersion).getNeutralPalette(
             variant,
             neutralPaletteKeyColor ?? sourceColorHct,
             isDark,
             platform,
             contrastLevel,
           ),
       neutralVariantPalette =
           neutralVariantPalette ??
           ColorSpecs.get(specVersion).getNeutralVariantPalette(
             variant,
             neutralVariantPaletteKeyColor ?? sourceColorHct,
             isDark,
             platform,
             contrastLevel,
           ),
       errorPalette =
           errorPalette ??
           ColorSpecs.get(specVersion).getErrorPalette(
             variant,
             errorPaletteKeyColor ?? sourceColorHct,
             isDark,
             platform,
             contrastLevel,
           );

  DynamicScheme.fromPalettesOrKeyColors({
    required bool isDark,
    Hct? sourceColorHct,
    double? contrastLevel,
    Variant? variant,
    Platform? platform,
    SpecVersion? specVersion,
    TonalPalette? primaryPalette,
    TonalPalette? secondaryPalette,
    TonalPalette? tertiaryPalette,
    TonalPalette? neutralPalette,
    TonalPalette? neutralVariantPalette,
    TonalPalette? errorPalette,
    Hct? primaryPaletteKeyColor,
    Hct? secondaryPaletteKeyColor,
    Hct? tertiaryPaletteKeyColor,
    Hct? neutralPaletteKeyColor,
    Hct? neutralVariantPaletteKeyColor,
    Hct? errorPaletteKeyColor,
  }) : this._fromPalettesOrKeyColors(
         sourceColorHct: sourceColorHct ?? Hct.fromInt(0xFF6750A4),
         isDark: isDark,
         contrastLevel: contrastLevel ?? 0.0,
         variant: variant ?? .tonalSpot,
         platform: platform ?? defaultPlatform,
         specVersion: _maybeFallbackSpecVersion(
           specVersion ?? defaultSpecVersion,
           variant ?? .tonalSpot,
         ),
         primaryPalette: primaryPalette,
         secondaryPalette: secondaryPalette,
         tertiaryPalette: tertiaryPalette,
         neutralPalette: neutralPalette,
         neutralVariantPalette: neutralVariantPalette,
         errorPalette: errorPalette,
         primaryPaletteKeyColor: primaryPaletteKeyColor,
         secondaryPaletteKeyColor: secondaryPaletteKeyColor,
         tertiaryPaletteKeyColor: tertiaryPaletteKeyColor,
         neutralPaletteKeyColor: neutralPaletteKeyColor,
         neutralVariantPaletteKeyColor: neutralVariantPaletteKeyColor,
         errorPaletteKeyColor: errorPaletteKeyColor,
       );

  /// The source color of the scheme in HCT format.
  final Hct sourceColorHct;

  /// The variant of the scheme.
  final Variant variant;

  /// Whether or not the scheme is dark mode.
  final bool isDark;

  /// Value from -1 to 1. -1 represents minimum contrast.
  /// 0 represents standard (i.e. the design as spec'd),
  /// and 1 represents maximum contrast.
  final double contrastLevel;

  /// The platform on which this scheme is intended to be used.
  final Platform platform;

  /// The spec version of the scheme.
  final SpecVersion specVersion;

  final TonalPalette primaryPalette;

  final TonalPalette secondaryPalette;

  final TonalPalette tertiaryPalette;

  final TonalPalette neutralPalette;

  final TonalPalette neutralVariantPalette;

  final TonalPalette errorPalette;

  /// The source color of the scheme in ARGB format.
  final int sourceColorArgb;

  Hct getHct(DynamicColor dynamicColor) => dynamicColor.getHct(this);

  int getArgb(DynamicColor dynamicColor) => dynamicColor.getArgb(this);

  int get primaryPaletteKeyColor =>
      getArgb(_dynamicColors.primaryPaletteKeyColor);

  int get secondaryPaletteKeyColor =>
      getArgb(_dynamicColors.secondaryPaletteKeyColor);

  int get tertiaryPaletteKeyColor =>
      getArgb(_dynamicColors.tertiaryPaletteKeyColor);

  int get neutralPaletteKeyColor =>
      getArgb(_dynamicColors.neutralPaletteKeyColor);

  int get neutralVariantPaletteKeyColor =>
      getArgb(_dynamicColors.neutralVariantPaletteKeyColor);

  int get errorPaletteKeyColor => getArgb(_dynamicColors.errorPaletteKeyColor);

  int get background => getArgb(_dynamicColors.background);

  int get onBackground => getArgb(_dynamicColors.onBackground);

  int get surface => getArgb(_dynamicColors.surface);

  int get surfaceDim => getArgb(_dynamicColors.surfaceDim);

  int get surfaceBright => getArgb(_dynamicColors.surfaceBright);

  int get surfaceContainerLowest =>
      getArgb(_dynamicColors.surfaceContainerLowest);

  int get surfaceContainerLow => getArgb(_dynamicColors.surfaceContainerLow);

  int get surfaceContainer => getArgb(_dynamicColors.surfaceContainer);

  int get surfaceContainerHigh => getArgb(_dynamicColors.surfaceContainerHigh);

  int get surfaceContainerHighest =>
      getArgb(_dynamicColors.surfaceContainerHighest);

  int get onSurface => getArgb(_dynamicColors.onSurface);

  int get surfaceVariant => getArgb(_dynamicColors.surfaceVariant);

  int get onSurfaceVariant => getArgb(_dynamicColors.onSurfaceVariant);

  int get outline => getArgb(_dynamicColors.outline);

  int get outlineVariant => getArgb(_dynamicColors.outlineVariant);

  int get inverseSurface => getArgb(_dynamicColors.inverseSurface);

  int get inverseOnSurface => getArgb(_dynamicColors.inverseOnSurface);

  int get shadow => getArgb(_dynamicColors.shadow);

  int get scrim => getArgb(_dynamicColors.scrim);

  int get surfaceTint => getArgb(_dynamicColors.surfaceTint);

  int get primary => getArgb(_dynamicColors.primary);

  int get primaryDim => getArgb(_dynamicColors.primaryDim);

  int get onPrimary => getArgb(_dynamicColors.onPrimary);

  int get primaryContainer => getArgb(_dynamicColors.primaryContainer);

  int get onPrimaryContainer => getArgb(_dynamicColors.onPrimaryContainer);

  int get primaryFixed => getArgb(_dynamicColors.primaryFixed);

  int get primaryFixedDim => getArgb(_dynamicColors.primaryFixedDim);

  int get onPrimaryFixed => getArgb(_dynamicColors.onPrimaryFixed);

  int get onPrimaryFixedVariant =>
      getArgb(_dynamicColors.onPrimaryFixedVariant);

  int get inversePrimary => getArgb(_dynamicColors.inversePrimary);

  int get secondary => getArgb(_dynamicColors.secondary);

  int get secondaryDim => getArgb(_dynamicColors.secondaryDim);

  int get onSecondary => getArgb(_dynamicColors.onSecondary);

  int get secondaryContainer => getArgb(_dynamicColors.secondaryContainer);

  int get onSecondaryContainer => getArgb(_dynamicColors.onSecondaryContainer);

  int get secondaryFixed => getArgb(_dynamicColors.secondaryFixed);

  int get secondaryFixedDim => getArgb(_dynamicColors.secondaryFixedDim);

  int get onSecondaryFixed => getArgb(_dynamicColors.onSecondaryFixed);

  int get onSecondaryFixedVariant =>
      getArgb(_dynamicColors.onSecondaryFixedVariant);

  int get tertiary => getArgb(_dynamicColors.tertiary);

  int get tertiaryDim => getArgb(_dynamicColors.tertiaryDim);

  int get onTertiary => getArgb(_dynamicColors.onTertiary);

  int get tertiaryContainer => getArgb(_dynamicColors.tertiaryContainer);

  int get onTertiaryContainer => getArgb(_dynamicColors.onTertiaryContainer);

  int get tertiaryFixed => getArgb(_dynamicColors.tertiaryFixed);

  int get tertiaryFixedDim => getArgb(_dynamicColors.tertiaryFixedDim);

  int get onTertiaryFixed => getArgb(_dynamicColors.onTertiaryFixed);

  int get onTertiaryFixedVariant =>
      getArgb(_dynamicColors.onTertiaryFixedVariant);

  int get error => getArgb(_dynamicColors.error);

  int get errorDim => getArgb(_dynamicColors.errorDim);

  int get onError => getArgb(_dynamicColors.onError);

  int get errorContainer => getArgb(_dynamicColors.errorContainer);

  int get onErrorContainer => getArgb(_dynamicColors.onErrorContainer);

  int get controlActivated => getArgb(_dynamicColors.controlActivated);

  int get controlNormal => getArgb(_dynamicColors.controlNormal);

  int get controlHighlight => getArgb(_dynamicColors.controlHighlight);

  int get textPrimaryInverse => getArgb(_dynamicColors.textPrimaryInverse);

  int get textSecondaryAndTertiaryInverse =>
      getArgb(_dynamicColors.textSecondaryAndTertiaryInverse);

  int get textPrimaryInverseDisableOnly =>
      getArgb(_dynamicColors.textPrimaryInverseDisableOnly);

  int get textSecondaryAndTertiaryInverseDisabled =>
      getArgb(_dynamicColors.textSecondaryAndTertiaryInverseDisabled);

  int get textHintInverse => getArgb(_dynamicColors.textHintInverse);

  @override
  String toString() =>
      "Scheme: variant=${variant.name}, "
      "mode=${isDark ? "dark" : "light"}, "
      "platform=${platform.name}, "
      "contrastLevel=${contrastLevel.toStringAsFixed(1)}, "
      "seed=$sourceColorHct, "
      "specVersion=$specVersion";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is DynamicScheme &&
          sourceColorArgb == other.sourceColorArgb &&
          sourceColorHct == other.sourceColorHct &&
          variant == other.variant &&
          isDark == other.isDark &&
          platform == other.platform &&
          contrastLevel == other.contrastLevel &&
          specVersion == other.specVersion &&
          primaryPalette == other.primaryPalette &&
          secondaryPalette == other.secondaryPalette &&
          tertiaryPalette == other.tertiaryPalette &&
          neutralPalette == other.neutralPalette &&
          neutralVariantPalette == other.neutralVariantPalette &&
          errorPalette == other.errorPalette;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    sourceColorArgb,
    sourceColorHct,
    variant,
    isDark,
    platform,
    contrastLevel,
    specVersion,
    primaryPalette,
    secondaryPalette,
    tertiaryPalette,
    neutralPalette,
    neutralVariantPalette,
    errorPalette,
  );

  static const SpecVersion defaultSpecVersion = .spec2021;
  static const Platform defaultPlatform = .phone;

  static const MaterialDynamicColors _dynamicColors = MaterialDynamicColors();

  static DynamicScheme from(
    DynamicScheme other,
    bool isDark, [
    double? contrastLevel,
  ]) => DynamicScheme(
    sourceColorHct: other.sourceColorHct,
    variant: other.variant,
    isDark: isDark,
    contrastLevel: contrastLevel ?? other.contrastLevel,
    platform: other.platform,
    specVersion: other.specVersion,
    primaryPalette: other.primaryPalette,
    secondaryPalette: other.secondaryPalette,
    tertiaryPalette: other.tertiaryPalette,
    neutralPalette: other.neutralPalette,
    neutralVariantPalette: other.neutralVariantPalette,
    errorPalette: other.errorPalette,
  );

  static double getPiecewiseValue(
    Hct sourceColorHct,
    List<double> hueBreakpoints,
    List<double> hues,
  ) {
    final size = math.min(hueBreakpoints.length - 1, hues.length);
    final sourceHue = sourceColorHct.hue;
    for (var i = 0; i < size; i++) {
      if (sourceHue >= hueBreakpoints[i] && sourceHue < hueBreakpoints[i + 1]) {
        return MathUtils.sanitizeDegreesDouble(hues[i]);
      }
    }
    // No condition matched, return the source value.
    return sourceHue;
  }

  static double getRotatedHue(
    Hct sourceColorHct,
    List<double> hueBreakpoints,
    List<double> rotations,
  ) {
    var rotation = getPiecewiseValue(sourceColorHct, hueBreakpoints, rotations);
    if (math.min(hueBreakpoints.length - 1, rotations.length) <= 0) {
      // No condition matched, return the source hue.
      rotation = 0.0;
    }
    return MathUtils.sanitizeDegreesDouble(sourceColorHct.hue + rotation);
  }

  /// Returns the spec version to use for the given variant.
  /// If the variant is not supported by the given spec version,
  /// the fallback spec version is returned.
  static SpecVersion _maybeFallbackSpecVersion(
    SpecVersion specVersion,
    Variant variant,
  ) => switch (variant) {
    .expressive || .vibrant || .tonalSpot || .neutral => specVersion,
    .monochrome ||
    .fidelity ||
    .content ||
    .rainbow ||
    .fruitSalad => .spec2021,
  };
}
