import 'dart:math' as math;

import '../utils/color_utils.dart';

/// Color science for contrast utilities.
///
/// Utility methods for calculating contrast given two colors, or calculating
/// a color given one color and a contrast ratio.
///
/// Contrast ratio is calculated using XYZ's Y. When linearized to match human
/// perception, Y becomes HCT's tone and L*a*b*'s' L*.
abstract final class Contrast {
  /// The minimum contrast ratio of two colors. Contrast ratio equation =
  /// (lighter + 5) / (darker + 5). If lighter == darker, ratio == 1.
  static const ratioMin = 1.0;

  /// The maximum contrast ratio of two colors. Contrast ratio equation =
  /// (lighter + 5) / (darker + 5). If lighter == 100 and darker = 0,
  /// ratio == 21.
  static const ratioMax = 21.0;

  static const ratio30 = 3.0;
  static const ratio45 = 4.5;
  static const ratio70 = 7.0;

  // Given a color and a contrast ratio to reach, the luminance of a color
  // that reaches that ratio with the color can be calculated. However,
  // that luminance may not contrast as desired, i.e. the contrast ratio of the
  // input color and the returned luminance may not reach the contrast ratio
  // asked for.
  //
  // When the desired contrast ratio and the result contrast ratio differ
  // by more than this amount, an error value should be returned, or the method
  // should be documented as 'unsafe', meaning, it will return a valid luminance
  // but that luminance may not meet the requested contrast ratio.
  //
  // 0.04 selected because it ensures the resulting ratio rounds to the same
  // tenth.
  static const _contrastRatioEpsilon = 0.04;

  // Color spaces that measure luminance, such as Y in XYZ, L* in L*a*b*,
  // or T in HCT, are known as perceptually accurate color spaces.
  //
  // To be displayed, they must gamut map to a "display space", one that has
  // a defined limit on the number of colors. Display spaces include sRGB,
  // more commonly understood  as RGB/HSL/HSV/HSB.
  // Gamut mapping is undefined and not defined by the color space. Any gamut
  // mapping algorithm must choose how to sacrifice accuracy in hue, saturation,
  // and/or lightness.
  //
  // A principled solution is to maintain lightness, thus maintaining
  // contrast/a11y, maintain hue, thus maintaining aesthetic intent, and reduce
  // chroma until the color is in gamut.
  //
  // HCT chooses this solution, but, that doesn't mean it will _exactly_ matched
  // desired lightness, if only because RGB is quantized: RGB is expressed as
  // a set of integers: there may be an RGB color with, for example,
  // 47.892 lightness, but not 47.891.
  //
  // To allow for this inherent incompatibility between perceptually accurate
  // color spaces and display color spaces, methods that take a contrast ratio
  // and luminance, and return a luminance that reaches that contrast ratio for
  // the input luminance, purposefully darken/lighten their result such that
  // the desired contrast ratio will be reached even if inaccuracy is introduced.
  //
  // 0.4 is generous, ex. HCT requires much less delta. It was chosen because it
  // provides a rough guarantee that as long as a perceptual color space gamut
  // maps lightness such that the resulting lightness rounds to the same
  //  as the requested, the desired contrast ratio will be reached.
  static const _luminanceGamutMapTolerance = 0.4;

  /// Contrast ratio is a measure of legibility, its used to compare the
  /// lightness of two colors. This method is used commonly in industry due to
  /// its use by WCAG.
  ///
  /// To compare lightness, the colors are expressed in the XYZ color space,
  /// where Y is lightness, also known as relative luminance.
  ///
  /// The equation is ratio = lighter Y + 5 / darker Y + 5.
  static double ratioOfYs(double y1, double y2) {
    final lighter = math.max(y1, y2);
    final darker = lighter == y2 ? y1 : y2;
    return (lighter + 5.0) / (darker + 5.0);
  }

  /// Contrast ratio of two tones. T in HCT, L* in L*a*b*. Also known as
  /// luminance or perpectual luminance.
  ///
  /// Contrast ratio is defined using Y in XYZ, relative luminance. However,
  /// relative luminance is linear to number of photons, not to perception of
  /// lightness. Perceptual luminance, L* in L*a*b*, T in HCT, is. Designers
  /// prefer color spaces with perceptual luminance since they're accurate
  /// to the eye.
  ///
  /// Y and L* are pure functions of each other, so it possible to use
  /// perceptually accurate color spaces, and measure contrast, and measure
  /// contrast in a much more understandable way: instead of a ratio, a linear
  /// difference. This allows a designer to determine what they need to adjust
  /// a color's lightness to in order to reach their desired contrast, instead
  /// of guessing & checking with hex codes.
  static double ratioOfTones(double t1, double t2) {
    t1 = t1.clamp(0.0, 100.0);
    t2 = t2.clamp(0.0, 100.0);
    return ratioOfYs(ColorUtils.yFromLstar(t1), ColorUtils.yFromLstar(t2));
  }

  /// Returns T in HCT, L* in L*a*b* >= tone parameter that ensures ratio with
  /// input T/L*. Returns null if ratio cannot be achieved.
  static double? lighter(double tone, double ratio) {
    if (tone < 0.0 || tone > 100.0) return null;
    // Invert the contrast ratio equation to determine lighter Y given a ratio and darker Y.
    final darkY = ColorUtils.yFromLstar(tone);
    final lightY = ratio * (darkY + 5.0) - 5.0;
    if (lightY < 0.0 || lightY > 100.0) return null;
    final realContrast = ratioOfYs(lightY, darkY);
    final delta = (realContrast - ratio).abs();
    if (realContrast < ratio && delta > _contrastRatioEpsilon) return null;
    final returnValue =
        ColorUtils.lstarFromY(lightY) + _luminanceGamutMapTolerance;
    // NOMUTANTS--important validation step; functions it is calling may change implementation.
    return returnValue < 0.0 || returnValue > 100.0 ? null : returnValue;
  }

  /// Tone >= tone parameter that ensures ratio. 100 if ratio
  /// cannot be achieved.
  ///
  /// This method is unsafe because the returned value is guaranteed to be in
  /// bounds, but, the in bounds return value may not reach the desired ratio.
  static double lighterUnsafe(double tone, double ratio) =>
      lighter(tone, ratio) ?? 100.0;

  /// Returns T in HCT, L* in L*a*b* <= tone parameter that ensures ratio with
  /// input T/L*. Returns null if ratio cannot be achieved.
  static double? darker(double tone, double ratio) {
    if (tone < 0.0 || tone > 100.0) return null;
    // Invert the contrast ratio equation to determine darker Y given a ratio and lighter Y.
    final lightY = ColorUtils.yFromLstar(tone);
    final darkY = ((lightY + 5.0) / ratio) - 5.0;
    if (darkY < 0.0 || darkY > 100.0) return null;
    final realContrast = ratioOfYs(lightY, darkY);
    final delta = (realContrast - ratio).abs();
    if (realContrast < ratio && delta > _contrastRatioEpsilon) return null;
    // For information on 0.4 constant, see comment in lighter(tone, ratio).
    final returnValue =
        ColorUtils.lstarFromY(darkY) - _luminanceGamutMapTolerance;
    // NOMUTANTS--important validation step; functions it is calling may change implementation.
    return returnValue < 0.0 || returnValue > 100.0 ? null : returnValue;
  }

  /// Tone <= tone parameter that ensures ratio. 0 if ratio cannot be achieved.
  ///
  /// This method is unsafe because the returned value is guaranteed to be in
  /// bounds, but, the in bounds return value may not reach the desired ratio.
  static double darkerUnsafe(double tone, double ratio) =>
      darker(tone, ratio) ?? 0.0;
}
