import '../hct/hct.dart';

/// Check and/or fix universally disliked colors.
///
/// Color science studies of color preference indicate universal distaste
/// for dark yellow-greens, and also show this is correlated to distate
/// for biological waste and rotting food.
///
/// See Palmer and Schloss, 2010 or Schloss and Palmer's Chapter 21 in
/// Handbook of Color Psychology (2015).
abstract final class DislikeAnalyzer {
  /// Returns true if color is disliked.
  ///
  /// Disliked is defined as a dark yellow-green that is not neutral.
  static bool isDisliked(Hct hct) {
    final huePasses = hct.hue.round() >= 90 && hct.hue.round() <= 111;
    final chromaPasses = hct.chroma.round() > 16;
    final tonePasses = hct.tone.round() < 65;
    return huePasses && chromaPasses && tonePasses;
  }

  /// If color is disliked, lighten it to make it likable.
  static Hct fixIfDisliked(Hct hct) =>
      isDisliked(hct) ? .from(hct.hue, hct.chroma, 70.0) : hct;
}
