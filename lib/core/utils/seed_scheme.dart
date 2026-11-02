import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

const double kAchromaticSeedChroma = 10;

const double kAccentMinBrightness = 0.2;

const ({double accent, double container}) _lightAccentToneFloors = (
  accent: 20,
  container: 60,
);

const ({double accent, double container}) _darkAccentToneFloors = (
  accent: 65,
  container: 15,
);

const double _accentForegroundContrast = 7;

const double _containerForegroundContrast = 4.5;

bool isAchromaticSeed(Color seed) =>
    Hct.fromInt(seed.toARGB32()).chroma < kAchromaticSeedChroma;

ColorScheme schemeFromSeed(Color seed, Brightness brightness) =>
    ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: isAchromaticSeed(seed)
          ? DynamicSchemeVariant.monochrome
          : DynamicSchemeVariant.tonalSpot,
    );

double accentDepth(Color seed) {
  final brightness = HSVColor.fromColor(seed).value;
  return ((1 - brightness) / (1 - kAccentMinBrightness)).clamp(0.0, 1.0);
}

ColorScheme accentSchemeFromSeed(Color seed, Brightness brightness) {
  final hueSource = HSVColor.fromColor(seed).withValue(1).toColor();
  final base = schemeFromSeed(hueSource, brightness);
  final depth = accentDepth(seed);
  if (depth == 0) return base;

  final scheme = _dynamicSchemeFor(hueSource, brightness);
  final floors = scheme.isDark ? _darkAccentToneFloors : _lightAccentToneFloors;

  _TonePair deepen(
    TonalPalette palette,
    DynamicColor fill,
    DynamicColor onFill,
    double floor,
    double contrast,
  ) {
    final fillTone = fill.getTone(scheme);
    final tone = fillTone > floor
        ? fillTone - (fillTone - floor) * depth
        : fillTone;
    final onTone = onFill.getTone(scheme);
    final readableOnTone = Contrast.ratioOfTones(onTone, tone) >= contrast
        ? onTone
        : DynamicColor.foregroundTone(tone, contrast);
    return (
      fill: Color(palette.getHct(tone).toInt()),
      onFill: Color(palette.getHct(readableOnTone).toInt()),
    );
  }

  final primary = deepen(
    scheme.primaryPalette,
    MaterialDynamicColors.primary,
    MaterialDynamicColors.onPrimary,
    floors.accent,
    _accentForegroundContrast,
  );
  final primaryContainer = deepen(
    scheme.primaryPalette,
    MaterialDynamicColors.primaryContainer,
    MaterialDynamicColors.onPrimaryContainer,
    floors.container,
    _containerForegroundContrast,
  );
  final secondary = deepen(
    scheme.secondaryPalette,
    MaterialDynamicColors.secondary,
    MaterialDynamicColors.onSecondary,
    floors.accent,
    _accentForegroundContrast,
  );
  final secondaryContainer = deepen(
    scheme.secondaryPalette,
    MaterialDynamicColors.secondaryContainer,
    MaterialDynamicColors.onSecondaryContainer,
    floors.container,
    _containerForegroundContrast,
  );
  final tertiary = deepen(
    scheme.tertiaryPalette,
    MaterialDynamicColors.tertiary,
    MaterialDynamicColors.onTertiary,
    floors.accent,
    _accentForegroundContrast,
  );
  final tertiaryContainer = deepen(
    scheme.tertiaryPalette,
    MaterialDynamicColors.tertiaryContainer,
    MaterialDynamicColors.onTertiaryContainer,
    floors.container,
    _containerForegroundContrast,
  );

  return base.copyWith(
    primary: primary.fill,
    onPrimary: primary.onFill,
    primaryContainer: primaryContainer.fill,
    onPrimaryContainer: primaryContainer.onFill,
    secondary: secondary.fill,
    onSecondary: secondary.onFill,
    secondaryContainer: secondaryContainer.fill,
    onSecondaryContainer: secondaryContainer.onFill,
    tertiary: tertiary.fill,
    onTertiary: tertiary.onFill,
    tertiaryContainer: tertiaryContainer.fill,
    onTertiaryContainer: tertiaryContainer.onFill,
    surfaceTint: primary.fill,
  );
}

typedef _TonePair = ({Color fill, Color onFill});

DynamicScheme _dynamicSchemeFor(Color seed, Brightness brightness) {
  final source = Hct.fromInt(seed.toARGB32());
  final isDark = brightness == Brightness.dark;
  return isAchromaticSeed(seed)
      ? SchemeMonochrome(
          sourceColorHct: source,
          isDark: isDark,
          contrastLevel: 0,
        )
      : SchemeTonalSpot(
          sourceColorHct: source,
          isDark: isDark,
          contrastLevel: 0,
        );
}
