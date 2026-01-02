import '../utils/math_utils.dart';
import '../hct/hct.dart';
import '../contrast/contrast.dart';
import '../palettes/tonal_palette.dart';

import 'color_spec.dart';
import 'color_specs.dart';
import 'tone_delta_pair.dart';
import 'contrast_curve.dart';
import 'dynamic_scheme.dart';

typedef DynamicSchemeCallback<T> = T Function(DynamicScheme s);

/// A color that adjusts itself based on UI state, represented by DynamicScheme.
///
/// This color automatically adjusts to accommodate a desired contrast level, or other adjustments
/// such as differing in light mode versus dark mode, or what the theme is, or what the color that
/// produced the theme is, etc.
///
/// Colors without backgrounds do not change tone when contrast changes. Colors with backgrounds
/// become closer to their background as contrast lowers, and further when contrast increases.
///
/// For example, the default behavior of adjust tone at max contrast to be at a 7.0 ratio with its
/// background is principled and matches accessibility guidance. That does not mean it's the desired
/// approach for _every_ design system, and every color pairing, always, in every case.
///
/// Ultimately, each component necessary for calculating a color, adjusting it for a desired contrast
/// level, and ensuring it has a certain lightness/tone difference from another color, is provided by
/// a function that takes a DynamicScheme and returns a value. This ensures ultimate flexibility, any
/// desired behavior of a color for any design system, but is usually unnecessary.
///
/// @param name The name of the dynamic color.
/// @param palette Function that provides a TonalPalette given DynamicScheme. A TonalPalette is
///   defined by a hue and chroma, so this replaces the need to specify hue/chroma. By providing a
///   tonal palette, when contrast adjustments are made, intended chroma can be preserved.
/// @param isBackground Whether this dynamic color is a background, with some other color as the
///   foreground.
/// @param chromaMultiplier Function that provides a chroma multiplier, given a DynamicScheme.
/// @param background Function that provides a background color, given a DynamicScheme.
/// @param tone Function that provides a tone, given a DynamicScheme.
/// @param secondBackground Function that provides a second background color, given a DynamicScheme.
/// @param contrastCurve Function that provides a contrast curve, given a DynamicScheme.
/// @param toneDeltaPair Function that provides a tone delta pair, given a DynamicScheme.
/// @param opacity Function that provides an opacity percentage, given a DynamicScheme.
final class DynamicColor {
  DynamicColor({
    required this.name,
    required this.palette,
    this.isBackground = false,
    this.chromaMultiplier,
    this.background,
    DynamicSchemeCallback<double>? tone,
    this.secondBackground,
    this.contrastCurve,
    this.toneDeltaPair,
    this.opacity,
  }) : tone = tone ?? getInitialToneFromBackground(background),
       _hctCache = <DynamicScheme, Hct>{} {
    if (background == null && secondBackground != null) {
      throw ArgumentError(
        "Color $name has secondBackground defined, "
        "but background is not defined.",
      );
    }
    if (background == null && contrastCurve != null) {
      throw ArgumentError(
        "Color $name has contrastCurve defined, "
        "but background is not defined.",
      );
    }
    if (background != null && contrastCurve == null) {
      throw ArgumentError(
        "Color $name has background defined, "
        "but contrastCurve is not defined.",
      );
    }
  }

  /// Create a DynamicColor from a hex code.
  ///
  /// Result has no background; thus no support for increasing/decreasing
  /// contrast for a11y.
  ///
  /// - [name] - The name of the dynamic color.
  /// - [argb] - The source color from which to extract the hue and chroma.
  factory DynamicColor.fromArgb(String name, int argb) {
    final hct = Hct.fromInt(argb);
    final palette = TonalPalette.fromInt(argb);
    return DynamicColor(
      name: name,
      palette: (_) => palette,
      tone: (_) => hct.tone,
    );
  }

  /// The name of the dynamic color.
  final String name;

  /// Function that provides a [TonalPalette] given [DynamicScheme].
  /// A [TonalPalette] is defined by a hue and chroma, so this replaces
  /// the need to specify hue/chroma. By providing a tonal palette,
  /// when contrast adjustments are made, intended chroma can be preserved.
  final DynamicSchemeCallback<TonalPalette> palette;

  /// Whether this dynamic color is a background,
  /// with some other color as the foreground.
  final bool isBackground;

  /// Function that provides a chroma multiplier, given a [DynamicScheme].
  final DynamicSchemeCallback<double>? chromaMultiplier;

  /// Function that provides a background color, given a [DynamicScheme].
  final DynamicSchemeCallback<DynamicColor?>? background;

  /// Function that provides a tone, given a [DynamicScheme].
  final DynamicSchemeCallback<double> tone;

  /// Function that provides a second background color, given a [DynamicScheme].
  final DynamicSchemeCallback<DynamicColor?>? secondBackground;

  /// Function that provides a contrast curve, given a [DynamicScheme].
  final DynamicSchemeCallback<ContrastCurve?>? contrastCurve;

  /// Function that provides a tone delta pair, given a [DynamicScheme].
  final DynamicSchemeCallback<ToneDeltaPair?>? toneDeltaPair;

  /// Function that provides an opacity percentage, given a [DynamicScheme].
  final DynamicSchemeCallback<double?>? opacity;

  final Map<DynamicScheme, Hct> _hctCache;

  DynamicColor copyWith({
    String? name,
    DynamicSchemeCallback<TonalPalette>? palette,
    DynamicSchemeCallback<double>? tone,
    bool? isBackground,
  }) => name != null || palette != null || tone != null || isBackground != null
      ? DynamicColor(
          name: name ?? this.name,
          palette: palette ?? this.palette,
          tone: tone ?? this.tone,
          isBackground: isBackground ?? this.isBackground,
          chromaMultiplier: chromaMultiplier,
          background: background,
          secondBackground: secondBackground,
          contrastCurve: contrastCurve,
          toneDeltaPair: toneDeltaPair,
          opacity: opacity,
        )
      : this;

  int getArgb(DynamicScheme scheme) {
    final argb = getHct(scheme).toInt();
    final opacityPercentage = opacity?.call(scheme);
    if (opacityPercentage == null) return argb;
    final alpha = MathUtils.clampInt(
      0,
      255,
      (opacityPercentage * 255.0).round(),
    );
    return (argb & 0x00ffffff) | (alpha << 24);
  }

  Hct getHct(DynamicScheme scheme) {
    final cachedAnswer = _hctCache[scheme];
    if (cachedAnswer != null) return cachedAnswer;
    final answer = ColorSpecs.get(scheme.specVersion).getHct(scheme, this);
    if (_hctCache.length > 4) _hctCache.clear();
    _hctCache[scheme] = answer;
    return answer;
  }

  double getTone(DynamicScheme scheme) =>
      ColorSpecs.get(scheme.specVersion).getTone(scheme, this);

  DynamicColor extendSpecVersion(
    SpecVersion specVersion,
    DynamicColor extendedColor,
  ) {
    _validateExtendedColor(specVersion, extendedColor);
    return DynamicColor(
      name: name,
      isBackground: isBackground,
      palette: (scheme) => scheme.specVersion == specVersion
          ? extendedColor.palette(scheme)
          : palette(scheme),
      tone: (scheme) => scheme.specVersion == specVersion
          ? extendedColor.tone(scheme)
          : tone(scheme),
      chromaMultiplier: (scheme) =>
          (scheme.specVersion == specVersion
                  ? extendedColor.chromaMultiplier
                  : chromaMultiplier)
              ?.call(scheme) ??
          1.0,
      background: (scheme) =>
          (scheme.specVersion == specVersion
                  ? extendedColor.background
                  : background)
              ?.call(scheme),
      secondBackground: (scheme) =>
          (scheme.specVersion == specVersion
                  ? extendedColor.secondBackground
                  : secondBackground)
              ?.call(scheme),
      contrastCurve: (scheme) =>
          (scheme.specVersion == specVersion
                  ? extendedColor.contrastCurve
                  : contrastCurve)
              ?.call(scheme),
      toneDeltaPair: (scheme) =>
          (scheme.specVersion == specVersion
                  ? extendedColor.toneDeltaPair
                  : toneDeltaPair)
              ?.call(scheme),
      opacity: (scheme) =>
          (scheme.specVersion == specVersion ? extendedColor.opacity : opacity)
              ?.call(scheme),
    );
  }

  void _validateExtendedColor(
    SpecVersion specVersion,
    DynamicColor extendedColor,
  ) {
    if (name != extendedColor.name) {
      throw ArgumentError(
        "Attempting to extend color $name with color ${extendedColor.name} "
        "of different name for spec version $specVersion.",
      );
    }
    if (isBackground != extendedColor.isBackground) {
      throw ArgumentError(
        "Attempting to extend color $name as a "
        "${isBackground ? "background" : "foreground"} with color "
        "${extendedColor.name} as a "
        "${extendedColor.isBackground ? "background" : "foreground"} "
        "for spec version $specVersion.",
      );
    }
  }

  @override
  String toString() =>
      "DynamicColor("
      "name: $name, "
      "palette: $palette, "
      "tone: $tone, "
      "isBackground: $isBackground, "
      "chromaMultiplier: $chromaMultiplier, "
      "background: $background, "
      "secondBackground: $secondBackground, "
      "contrastCurve: $contrastCurve, "
      "toneDeltaPair: $toneDeltaPair, "
      "opacity: $opacity"
      ")";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is DynamicColor &&
          name == other.name &&
          palette == other.palette &&
          tone == other.tone &&
          isBackground == other.isBackground &&
          chromaMultiplier == other.chromaMultiplier &&
          background == other.background &&
          secondBackground == other.secondBackground &&
          contrastCurve == other.contrastCurve &&
          toneDeltaPair == other.toneDeltaPair &&
          opacity == other.opacity;

  @override
  int get hashCode => Object.hash(
    name,
    palette,
    tone,
    isBackground,
    chromaMultiplier,
    background,
    secondBackground,
    contrastCurve,
    toneDeltaPair,
    opacity,
  );

  static double foregroundTone(double bgTone, double ratio) {
    final lighterTone = Contrast.lighterUnsafe(bgTone, ratio);
    final darkerTone = Contrast.darkerUnsafe(bgTone, ratio);
    final lighterRatio = Contrast.ratioOfTones(lighterTone, bgTone);
    final darkerRatio = Contrast.ratioOfTones(darkerTone, bgTone);
    final preferLighter = tonePrefersLightForeground(bgTone);

    if (preferLighter) {
      // "Neglible difference" handles an edge case where
      // the initial contrast ratio is high (ex. 13.0),
      // and the ratio passed to the function is that high ratio,
      // and both the lighter
      // and darker ratio fails to pass that ratio.
      //
      // This was observed with Tonal Spot's On Primary Container
      // turning black momentarily between high and max contrast in light mode.
      // PC's standard tone was T90, OPC's was T10, it was light mode,
      // and the contrast level was 0.6568521221032331.
      final negligibleDifference =
          (lighterRatio - darkerRatio).abs() < 0.1 &&
          lighterRatio < ratio &&
          darkerRatio < ratio;
      if (lighterRatio >= ratio ||
          lighterRatio >= darkerRatio ||
          negligibleDifference) {
        return lighterTone;
      } else {
        return darkerTone;
      }
    } else {
      return darkerRatio >= ratio || darkerRatio >= lighterRatio
          ? darkerTone
          : lighterTone;
    }
  }

  static double enableLightForeground(double tone) =>
      tonePrefersLightForeground(tone) && !toneAllowsLightForeground(tone)
      ? 49.0
      : tone;

  static bool tonePrefersLightForeground(double tone) => tone.round() < 60.0;

  static bool toneAllowsLightForeground(double tone) => tone.round() <= 49.0;

  static DynamicSchemeCallback<double> getInitialToneFromBackground([
    DynamicSchemeCallback<DynamicColor?>? background,
  ]) {
    if (background == null) return (s) => 50.0;
    return (scheme) => background.call(scheme)?.getTone(scheme) ?? 50.0;
  }
}
