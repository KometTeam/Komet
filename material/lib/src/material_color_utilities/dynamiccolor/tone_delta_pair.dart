import 'dynamic_color.dart';

/// Describes how to fulfill a tone delta pair constraint.
///
/// Determines if the delta is a minimum, maximum, or exact tonal distance that must be maintained.
enum DeltaConstraint {
  /// The tone of roleA must be an exact delta away from the tone of roleB.
  exact,

  /// The tonal distance of roleA and roleB must be at most delta.
  nearer,

  /// The tonal distance of roleA and roleB must be at least delta.
  farther,
}

/// Describes the relationship in lightness between two colors.
///
/// 'relative_darker' and 'relative_lighter' describes the tone adjustment relative to the surface
/// color trend (white in light mode; black in dark mode). For instance, ToneDeltaPair(A, B, 10,
/// 'relative_lighter', 'farther') states that A should be at least 10 lighter than B in light
/// mode, and at least 10 darker than B in dark mode.
enum TonePolarity {
  /// The tone of roleA is always darker than the tone of roleB.
  darker,

  /// The tone of roleA is always lighter than the tone of roleB.
  lighter,

  /// The tone of roleA is darker than the tone of roleB in light mode, and lighter than the tone
  /// of roleB in dark mode.
  relativeDarker,

  /// The tone of roleA is lighter than the tone of roleB in light mode, and darker than the tone
  /// of roleB in dark mode.
  relativeLighter,
}

/// Documents a constraint between two DynamicColors, in which their tones
/// must have a certain distance from each other.
///
/// The polarity is an adjective that describes "A", compared to "B".
/// For instance, ToneDeltaPair(A, B, 15, 'darker') states that A's tone
/// should be at least 15 darker than B's.
///
/// Prefer a DynamicColor with a background, this is for special cases
/// when designers want tonal distance, literally contrast, between two colors
/// that don't have a background / foreground relationship or a contrast
/// guarantee.
final class ToneDeltaPair {
  const ToneDeltaPair({
    required this.roleA,
    required this.roleB,
    required this.delta,
    required this.polarity,
    this.stayTogether = true,
    this.constraint = .exact,
  });

  /// The first role in a pair.
  final DynamicColor roleA;

  /// The second role in a pair.
  final DynamicColor roleB;

  /// Required difference between tones.
  /// Absolute value, negative values have undefined behavior.
  final double delta;

  /// The relative relation between tones of [roleA] and [roleB].
  final TonePolarity polarity;

  /// Whether these two roles should stay on the same side
  /// of the "awkward zone" (T50-59). This is necessary for certain cases where
  /// one role has two backgrounds.
  final bool stayTogether;

  /// How to fulfill the tone delta pair constraint.
  final DeltaConstraint constraint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is ToneDeltaPair &&
          roleA == other.roleA &&
          roleB == other.roleB &&
          delta == other.delta &&
          polarity == other.polarity &&
          stayTogether == other.stayTogether &&
          constraint == other.constraint;

  @override
  int get hashCode =>
      Object.hash(roleA, roleA, delta, polarity, stayTogether, constraint);
}
