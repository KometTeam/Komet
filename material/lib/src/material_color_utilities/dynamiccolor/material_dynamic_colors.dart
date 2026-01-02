import 'color_spec_2025.dart';
import 'dynamic_color.dart';
import 'dynamic_scheme.dart';

final class MaterialDynamicColors {
  const MaterialDynamicColors() : _colorSpec = const ColorSpec2025();

  final ColorSpec2025 _colorSpec;

  DynamicColor highestSurface(DynamicScheme scheme) =>
      _colorSpec.highestSurface(scheme);

  DynamicColor get primaryPaletteKeyColor => _colorSpec.primaryPaletteKeyColor;

  DynamicColor get secondaryPaletteKeyColor =>
      _colorSpec.secondaryPaletteKeyColor;

  DynamicColor get tertiaryPaletteKeyColor =>
      _colorSpec.tertiaryPaletteKeyColor;

  DynamicColor get neutralPaletteKeyColor => _colorSpec.neutralPaletteKeyColor;

  DynamicColor get neutralVariantPaletteKeyColor =>
      _colorSpec.neutralVariantPaletteKeyColor;

  DynamicColor get errorPaletteKeyColor => _colorSpec.errorPaletteKeyColor;

  DynamicColor get background => _colorSpec.background;

  DynamicColor get onBackground => _colorSpec.onBackground;

  DynamicColor get surface => _colorSpec.surface;

  DynamicColor get surfaceDim => _colorSpec.surfaceDim;

  DynamicColor get surfaceBright => _colorSpec.surfaceBright;

  DynamicColor get surfaceContainerLowest => _colorSpec.surfaceContainerLowest;

  DynamicColor get surfaceContainerLow => _colorSpec.surfaceContainerLow;

  DynamicColor get surfaceContainer => _colorSpec.surfaceContainer;

  DynamicColor get surfaceContainerHigh => _colorSpec.surfaceContainerHigh;

  DynamicColor get surfaceContainerHighest =>
      _colorSpec.surfaceContainerHighest;

  DynamicColor get onSurface => _colorSpec.onSurface;

  DynamicColor get surfaceVariant => _colorSpec.surfaceVariant;

  DynamicColor get onSurfaceVariant => _colorSpec.onSurfaceVariant;

  DynamicColor get inverseSurface => _colorSpec.inverseSurface;

  DynamicColor get inverseOnSurface => _colorSpec.inverseOnSurface;

  DynamicColor get outline => _colorSpec.outline;

  DynamicColor get outlineVariant => _colorSpec.outlineVariant;

  DynamicColor get shadow => _colorSpec.shadow;

  DynamicColor get scrim => _colorSpec.scrim;

  DynamicColor get surfaceTint => _colorSpec.surfaceTint;

  DynamicColor get primary => _colorSpec.primary;

  DynamicColor get primaryDim => _colorSpec.primaryDim;

  DynamicColor get onPrimary => _colorSpec.onPrimary;

  DynamicColor get primaryContainer => _colorSpec.primaryContainer;

  DynamicColor get onPrimaryContainer => _colorSpec.onPrimaryContainer;

  DynamicColor get inversePrimary => _colorSpec.inversePrimary;

  DynamicColor get primaryFixed => _colorSpec.primaryFixed;

  DynamicColor get primaryFixedDim => _colorSpec.primaryFixedDim;

  DynamicColor get onPrimaryFixed => _colorSpec.onPrimaryFixed;

  DynamicColor get onPrimaryFixedVariant => _colorSpec.onPrimaryFixedVariant;

  DynamicColor get secondary => _colorSpec.secondary;

  DynamicColor get secondaryDim => _colorSpec.secondaryDim;

  DynamicColor get onSecondary => _colorSpec.onSecondary;

  DynamicColor get secondaryContainer => _colorSpec.secondaryContainer;

  DynamicColor get onSecondaryContainer => _colorSpec.onSecondaryContainer;

  DynamicColor get secondaryFixed => _colorSpec.secondaryFixed;

  DynamicColor get secondaryFixedDim => _colorSpec.secondaryFixedDim;

  DynamicColor get onSecondaryFixed => _colorSpec.onSecondaryFixed;

  DynamicColor get onSecondaryFixedVariant =>
      _colorSpec.onSecondaryFixedVariant;

  DynamicColor get tertiary => _colorSpec.tertiary;

  DynamicColor get tertiaryDim => _colorSpec.tertiaryDim;

  DynamicColor get onTertiary => _colorSpec.onTertiary;

  DynamicColor get tertiaryContainer => _colorSpec.tertiaryContainer;

  DynamicColor get onTertiaryContainer => _colorSpec.onTertiaryContainer;

  DynamicColor get tertiaryFixed => _colorSpec.tertiaryFixed;

  DynamicColor get tertiaryFixedDim => _colorSpec.tertiaryFixedDim;

  DynamicColor get onTertiaryFixed => _colorSpec.onTertiaryFixed;

  DynamicColor get onTertiaryFixedVariant => _colorSpec.onTertiaryFixedVariant;

  DynamicColor get error => _colorSpec.error;

  DynamicColor get errorDim => _colorSpec.errorDim;

  DynamicColor get onError => _colorSpec.onError;

  DynamicColor get errorContainer => _colorSpec.errorContainer;

  DynamicColor get onErrorContainer => _colorSpec.onErrorContainer;

  DynamicColor get controlActivated => _colorSpec.controlActivated;

  DynamicColor get controlNormal => _colorSpec.controlNormal;

  DynamicColor get controlHighlight => _colorSpec.controlHighlight;

  DynamicColor get textPrimaryInverse => _colorSpec.textPrimaryInverse;

  DynamicColor get textSecondaryAndTertiaryInverse =>
      _colorSpec.textSecondaryAndTertiaryInverse;

  DynamicColor get textPrimaryInverseDisableOnly =>
      _colorSpec.textPrimaryInverseDisableOnly;

  DynamicColor get textSecondaryAndTertiaryInverseDisabled =>
      _colorSpec.textSecondaryAndTertiaryInverseDisabled;

  DynamicColor get textHintInverse => _colorSpec.textHintInverse;

  /// All dynamic colors in Material Design system.
  List<DynamicColor Function()> get allDynamicColors =>
      <DynamicColor Function()>[
        () => primaryPaletteKeyColor,
        () => secondaryPaletteKeyColor,
        () => tertiaryPaletteKeyColor,
        () => neutralPaletteKeyColor,
        () => neutralVariantPaletteKeyColor,
        () => errorPaletteKeyColor,
        () => background,
        () => onBackground,
        () => surface,
        () => surfaceDim,
        () => surfaceBright,
        () => surfaceContainerLowest,
        () => surfaceContainerLow,
        () => surfaceContainer,
        () => surfaceContainerHigh,
        () => surfaceContainerHighest,
        () => onSurface,
        () => surfaceVariant,
        () => onSurfaceVariant,
        () => outline,
        () => outlineVariant,
        () => inverseSurface,
        () => inverseOnSurface,
        () => shadow,
        () => scrim,
        () => surfaceTint,
        () => primary,
        () => primaryDim,
        () => onPrimary,
        () => primaryContainer,
        () => onPrimaryContainer,
        () => primaryFixed,
        () => primaryFixedDim,
        () => onPrimaryFixed,
        () => onPrimaryFixedVariant,
        () => inversePrimary,
        () => secondary,
        () => secondaryDim,
        () => onSecondary,
        () => secondaryContainer,
        () => onSecondaryContainer,
        () => secondaryFixed,
        () => secondaryFixedDim,
        () => onSecondaryFixed,
        () => onSecondaryFixedVariant,
        () => tertiary,
        () => tertiaryDim,
        () => onTertiary,
        () => tertiaryContainer,
        () => onTertiaryContainer,
        () => tertiaryFixed,
        () => tertiaryFixedDim,
        () => onTertiaryFixed,
        () => onTertiaryFixedVariant,
        () => error,
        () => errorDim,
        () => onError,
        () => errorContainer,
        () => onErrorContainer,
        () => controlActivated,
        () => controlNormal,
        () => controlHighlight,
        () => textPrimaryInverse,
        () => textSecondaryAndTertiaryInverse,
        () => textPrimaryInverseDisableOnly,
        () => textSecondaryAndTertiaryInverseDisabled,
        () => textHintInverse,
      ];
}
