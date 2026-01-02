import '../dynamiccolor/dynamic_scheme.dart';

import 'tonal_palette.dart';

/// Comprises foundational palettes to build a color scheme.
///
/// Generated from a source color, these palettes will then be part of a [DynamicScheme] together
/// with appearance preferences.
final class CorePalettes {
  const CorePalettes({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.neutral,
    required this.neutralVariant,
  });

  final TonalPalette primary;
  final TonalPalette secondary;
  final TonalPalette tertiary;
  final TonalPalette neutral;
  final TonalPalette neutralVariant;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is CorePalettes &&
          primary == other.primary &&
          secondary == other.secondary &&
          tertiary == other.tertiary &&
          neutral == other.neutral &&
          neutralVariant == other.neutralVariant;

  @override
  int get hashCode =>
      Object.hash(primary, secondary, tertiary, neutral, neutralVariant);
}
