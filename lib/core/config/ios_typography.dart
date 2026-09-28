import 'package:flutter/widgets.dart';

import 'ios_release.dart';

/// Font weights of the iOS build: regular body text, semibold titles and
/// names, bold for strong formatting. Off iOS every helper returns the
/// value it is given, so Android keeps its look.
abstract final class IosTypography {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight emphasis = FontWeight.w600;
  static const FontWeight strong = FontWeight.w700;

  /// Count inside an iOS reaction capsule.
  static const double reactionCount = 15;

  /// Digits of equal width, so counts do not jitter as they change.
  static const List<FontFeature> tabularDigits = [FontFeature.tabularFigures()];

  /// Body text, previews, meta and menu rows.
  static FontWeight body(FontWeight other) =>
      IosRelease.isIOS ? regular : other;

  /// Titles, names and other emphasized labels.
  static FontWeight title(FontWeight other) =>
      IosRelease.isIOS ? emphasis : other;

  /// The UI on iOS has no italics; slanted text stays upright.
  static FontStyle upright(FontStyle other) =>
      IosRelease.isIOS ? FontStyle.normal : other;

  /// Weight of the message body. On iOS it is plain regular so the variable
  /// weight axis follows [FontWeight] and strong spans render bold.
  static FontWeight? messageBodyWeight() => IosRelease.isIOS ? regular : null;

  /// Weight axis override of the message body. Elsewhere Inter is drawn at a
  /// light 300; on iOS there is no override, a fixed axis value would also
  /// pin bold spans to it.
  static List<FontVariation>? messageBodyVariations(String? family) {
    if (IosRelease.isIOS) return null;
    return family == 'Inter' ? const [FontVariation('wght', 300)] : null;
  }
}
