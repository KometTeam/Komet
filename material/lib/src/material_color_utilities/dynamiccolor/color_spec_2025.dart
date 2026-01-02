// ignore_for_file: recursive_getters

import 'dart:math' as math;

import '../utils/math_utils.dart';
import '../hct/hct.dart';
import '../contrast/contrast.dart';
import '../palettes/tonal_palette.dart';

import 'color_spec.dart';
import 'color_spec_2021.dart';
import 'contrast_curve.dart';
import 'dynamic_color.dart';
import 'dynamic_scheme.dart';
import 'tone_delta_pair.dart';
import 'variant.dart';

/// [ColorSpec] implementation for the 2025 spec.
final class ColorSpec2025 implements ColorSpec {
  const ColorSpec2025() : _baseSpec = const ColorSpec2021();

  final ColorSpec2021 _baseSpec;

  @override
  DynamicColor get primaryPaletteKeyColor => _baseSpec.primaryPaletteKeyColor;

  @override
  DynamicColor get secondaryPaletteKeyColor =>
      _baseSpec.secondaryPaletteKeyColor;

  @override
  DynamicColor get tertiaryPaletteKeyColor => _baseSpec.tertiaryPaletteKeyColor;

  @override
  DynamicColor get neutralPaletteKeyColor => _baseSpec.neutralPaletteKeyColor;

  @override
  DynamicColor get neutralVariantPaletteKeyColor =>
      _baseSpec.neutralVariantPaletteKeyColor;
  @override
  DynamicColor get errorPaletteKeyColor => _baseSpec.errorPaletteKeyColor;

  @override
  DynamicColor get background {
    final color2025 = surface.copyWith(name: "background");
    return _baseSpec.background.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onBackground {
    final color2025 = onSurface.copyWith(
      name: "on_background",
      tone: (s) => s.platform == .watch ? 100.0 : onSurface.getTone(s),
    );
    return _baseSpec.onBackground.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get surface {
    final color2025 = DynamicColor(
      name: "surface",
      palette: (s) => s.neutralPalette,
      tone: (s) {
        if (s.platform == .phone) {
          if (s.isDark) {
            return 4.0;
          } else {
            if (Hct.isYellow(s.neutralPalette.hue)) {
              return 99.0;
            } else if (s.variant == .vibrant) {
              return 97.0;
            } else {
              return 98.0;
            }
          }
        } else {
          return 0.0;
        }
      },
      isBackground: true,
    );
    return _baseSpec.surface.extendSpecVersion(SpecVersion.spec2025, color2025);
  }

  @override
  DynamicColor get surfaceDim {
    final color2025 = DynamicColor(
      name: "surface_dim",
      palette: (s) => s.neutralPalette,
      tone: (s) {
        if (s.isDark) {
          return 4.0;
        } else {
          if (Hct.isYellow(s.neutralPalette.hue)) {
            return 90.0;
          } else if (s.variant == .vibrant) {
            return 85.0;
          } else {
            return 87.0;
          }
        }
      },
      isBackground: true,
      chromaMultiplier: (s) {
        if (!s.isDark) {
          if (s.variant == .neutral) {
            return 2.5;
          } else if (s.variant == .tonalSpot) {
            return 1.7;
          } else if (s.variant == .expressive) {
            return Hct.isYellow(s.neutralPalette.hue) ? 2.7 : 1.75;
          } else if (s.variant == .vibrant) {
            return 1.36;
          }
        }
        return 1.0;
      },
    );
    return _baseSpec.surfaceDim.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get surfaceBright {
    final color2025 = DynamicColor(
      name: "surface_bright",
      palette: (s) => s.neutralPalette,
      tone: (s) {
        if (s.isDark) {
          return 18.0;
        } else {
          if (Hct.isYellow(s.neutralPalette.hue)) {
            return 99.0;
          } else if (s.variant == .vibrant) {
            return 97.0;
          } else {
            return 98.0;
          }
        }
      },
      isBackground: true,
      chromaMultiplier: (s) {
        if (s.isDark) {
          if (s.variant == .neutral) {
            return 2.5;
          } else if (s.variant == .tonalSpot) {
            return 1.7;
          } else if (s.variant == .expressive) {
            return Hct.isYellow(s.neutralPalette.hue) ? 2.7 : 1.75;
          } else if (s.variant == .vibrant) {
            return 1.36;
          }
        }
        return 1.0;
      },
    );
    return _baseSpec.surfaceBright.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get surfaceContainerLowest {
    final color2025 = DynamicColor(
      name: "surface_container_lowest",
      palette: (s) => s.neutralPalette,
      tone: (s) => s.isDark ? 0.0 : 100.0,
      isBackground: true,
    );
    return _baseSpec.surfaceContainerLowest.extendSpecVersion(
      .spec2025,
      color2025,
    );
  }

  @override
  DynamicColor get surfaceContainerLow {
    final color2025 = DynamicColor(
      name: "surface_container_low",
      palette: (s) => s.neutralPalette,
      tone: (s) {
        if (s.platform == .phone) {
          if (s.isDark) {
            return 6.0;
          } else {
            if (Hct.isYellow(s.neutralPalette.hue)) {
              return 98.0;
            } else if (s.variant == .vibrant) {
              return 95.0;
            } else {
              return 96.0;
            }
          }
        } else {
          return 15.0;
        }
      },
      isBackground: true,
      chromaMultiplier: (s) {
        if (s.platform == .phone) {
          if (s.variant == .neutral) {
            return 1.3;
          } else if (s.variant == .tonalSpot) {
            return 1.25;
          } else if (s.variant == .expressive) {
            return Hct.isYellow(s.neutralPalette.hue) ? 1.3 : 1.15;
          } else if (s.variant == .vibrant) {
            return 1.08;
          }
        }
        return 1.0;
      },
    );
    return _baseSpec.surfaceContainerLow.extendSpecVersion(
      .spec2025,
      color2025,
    );
  }

  @override
  DynamicColor get surfaceContainer {
    final color2025 = DynamicColor(
      name: "surface_container",
      palette: (s) => s.neutralPalette,
      tone: (s) {
        if (s.platform == .phone) {
          if (s.isDark) {
            return 9.0;
          } else {
            if (Hct.isYellow(s.neutralPalette.hue)) {
              return 96.0;
            } else if (s.variant == .vibrant) {
              return 92.0;
            } else {
              return 94.0;
            }
          }
        } else {
          return 20.0;
        }
      },
      isBackground: true,
      chromaMultiplier: (s) {
        if (s.platform == .phone) {
          if (s.variant == .neutral) {
            return 1.6;
          } else if (s.variant == .tonalSpot) {
            return 1.4;
          } else if (s.variant == .expressive) {
            return Hct.isYellow(s.neutralPalette.hue) ? 1.6 : 1.3;
          } else if (s.variant == .vibrant) {
            return 1.15;
          }
        }
        return 1.0;
      },
    );
    return _baseSpec.surfaceContainer.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get surfaceContainerHigh {
    final color2025 = DynamicColor(
      name: "surface_container_high",
      palette: (s) => s.neutralPalette,
      tone: (s) {
        if (s.platform == .phone) {
          if (s.isDark) {
            return 12.0;
          } else {
            if (Hct.isYellow(s.neutralPalette.hue)) {
              return 94.0;
            } else if (s.variant == .vibrant) {
              return 90.0;
            } else {
              return 92.0;
            }
          }
        } else {
          return 25.0;
        }
      },
      isBackground: true,
      chromaMultiplier: (s) {
        if (s.platform == .phone) {
          if (s.variant == .neutral) {
            return 1.9;
          } else if (s.variant == .tonalSpot) {
            return 1.5;
          } else if (s.variant == .expressive) {
            return Hct.isYellow(s.neutralPalette.hue) ? 1.95 : 1.45;
          } else if (s.variant == .vibrant) {
            return 1.22;
          }
        }
        return 1.0;
      },
    );
    return _baseSpec.surfaceContainerHigh.extendSpecVersion(
      .spec2025,
      color2025,
    );
  }

  @override
  DynamicColor get surfaceContainerHighest {
    final color2025 = DynamicColor(
      name: "surface_container_highest",
      palette: (s) => s.neutralPalette,
      tone: (s) {
        if (s.isDark) {
          return 15.0;
        } else {
          if (Hct.isYellow(s.neutralPalette.hue)) {
            return 92.0;
          } else if (s.variant == .vibrant) {
            return 88.0;
          } else {
            return 90.0;
          }
        }
      },
      isBackground: true,
      chromaMultiplier: (s) {
        if (s.variant == .neutral) {
          return 2.2;
        } else if (s.variant == .tonalSpot) {
          return 1.7;
        } else if (s.variant == .expressive) {
          return Hct.isYellow(s.neutralPalette.hue) ? 2.3 : 1.6;
        } else if (s.variant == .vibrant) {
          return 1.29;
        }
        return 1.0;
      },
    );
    return _baseSpec.surfaceContainerHighest.extendSpecVersion(
      .spec2025,
      color2025,
    );
  }

  @override
  DynamicColor get onSurface {
    final color2025 = DynamicColor(
      name: "on_surface",
      palette: (s) => s.neutralPalette,
      tone: (s) {
        if (s.variant == .vibrant) {
          return _tMaxC(s.neutralPalette, 0, 100, 1.1);
        } else {
          return DynamicColor.getInitialToneFromBackground((scheme) {
            if (scheme.platform == .phone) {
              return scheme.isDark ? surfaceBright : surfaceDim;
            } else {
              return surfaceContainerHigh;
            }
          })(s);
        }
      },
      chromaMultiplier: (s) {
        if (s.platform == .phone) {
          if (s.variant == .neutral) {
            return 2.2;
          } else if (s.variant == .tonalSpot) {
            return 1.7;
          } else if (s.variant == .expressive) {
            return Hct.isYellow(s.neutralPalette.hue)
                ? (s.isDark ? 3.0 : 2.3)
                : 1.6;
          }
        }
        return 1.0;
      },
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return surfaceContainerHigh;
        }
      },
      contrastCurve: (s) => s.isDark && s.platform == .phone
          ? _getContrastCurve(11)
          : _getContrastCurve(9),
    );
    return _baseSpec.onSurface.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get surfaceVariant {
    final color2025 = surfaceContainerHighest.copyWith(name: "surface_variant");
    return _baseSpec.surfaceVariant.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onSurfaceVariant {
    final color2025 = DynamicColor(
      name: "on_surface_variant",
      palette: (s) => s.neutralPalette,
      chromaMultiplier: (s) {
        if (s.platform == .phone) {
          if (s.variant == .neutral) {
            return 2.2;
          } else if (s.variant == .tonalSpot) {
            return 1.7;
          } else if (s.variant == .expressive) {
            return Hct.isYellow(s.neutralPalette.hue)
                ? (s.isDark ? 3.0 : 2.3)
                : 1.6;
          }
        }
        return 1.0;
      },
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return surfaceContainerHigh;
        }
      },
      contrastCurve: (s) => s.platform == .phone
          ? s.isDark
                ? _getContrastCurve(6.0)
                : _getContrastCurve(4.5)
          : _getContrastCurve(7.0),
    );
    return _baseSpec.onSurfaceVariant.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get inverseSurface {
    final color2025 = DynamicColor(
      name: "inverse_surface",
      palette: (s) => s.neutralPalette,
      tone: (s) => s.isDark ? 98.0 : 4.0,
      isBackground: true,
    );
    return _baseSpec.inverseSurface.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get inverseOnSurface {
    final color2025 = DynamicColor(
      name: "inverse_on_surface",
      palette: (s) => s.neutralPalette,
      background: (s) => inverseSurface,
      contrastCurve: (s) => _getContrastCurve(7),
    );
    return _baseSpec.inverseOnSurface.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get outline {
    final color2025 = DynamicColor(
      name: "outline",
      palette: (s) => s.neutralPalette,
      chromaMultiplier: (s) {
        if (s.platform == .phone) {
          if (s.variant == .neutral) {
            return 2.2;
          } else if (s.variant == .tonalSpot) {
            return 1.7;
          } else if (s.variant == .expressive) {
            return Hct.isYellow(s.neutralPalette.hue)
                ? (s.isDark ? 3.0 : 2.3)
                : 1.6;
          }
        }
        return 1.0;
      },
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return surfaceContainerHigh;
        }
      },
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(3) : _getContrastCurve(4.5),
    );
    return _baseSpec.outline.extendSpecVersion(SpecVersion.spec2025, color2025);
  }

  @override
  DynamicColor get outlineVariant {
    final color2025 = DynamicColor(
      name: "outline_variant",
      palette: (s) => s.neutralPalette,
      chromaMultiplier: (s) {
        if (s.platform == .phone) {
          if (s.variant == .neutral) {
            return 2.2;
          } else if (s.variant == .tonalSpot) {
            return 1.7;
          } else if (s.variant == .expressive) {
            return Hct.isYellow(s.neutralPalette.hue)
                ? (s.isDark ? 3.0 : 2.3)
                : 1.6;
          }
        }
        return 1.0;
      },
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return surfaceContainerHigh;
        }
      },
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(1.5) : _getContrastCurve(3),
    );
    return _baseSpec.outlineVariant.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get shadow => _baseSpec.shadow;

  @override
  DynamicColor get scrim => _baseSpec.scrim;

  @override
  DynamicColor get surfaceTint {
    final color2025 = primary.copyWith(name: "surface_tint");
    return _baseSpec.surfaceTint.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get primary {
    final color2025 = DynamicColor(
      name: "primary",
      palette: (s) => s.primaryPalette,
      tone: (s) {
        if (s.variant == .neutral) {
          if (s.platform == .phone) {
            return s.isDark ? 80.0 : 40.0;
          } else {
            return 90.0;
          }
        } else if (s.variant == .tonalSpot) {
          if (s.platform == .phone) {
            if (s.isDark) {
              return 80.0;
            } else {
              return _tMaxC(s.primaryPalette);
            }
          } else {
            return _tMaxC(s.primaryPalette, 0, 90);
          }
        } else if (s.variant == .expressive) {
          if (s.platform == .phone) {
            return _tMaxC(
              s.primaryPalette,
              0,
              Hct.isYellow(s.primaryPalette.hue)
                  ? 25
                  : Hct.isCyan(s.primaryPalette.hue)
                  ? 88
                  : 98,
            );
          } else {
            // WATCH
            return _tMaxC(s.primaryPalette);
          }
        } else {
          // VIBRANT
          if (s.platform == .phone) {
            return _tMaxC(
              s.primaryPalette,
              0,
              Hct.isCyan(s.primaryPalette.hue) ? 88 : 98,
            );
          } else {
            // WATCH
            return _tMaxC(s.primaryPalette);
          }
        }
      },
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return surfaceContainerHigh;
        }
      },
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(4.5) : _getContrastCurve(7),
      toneDeltaPair: (s) => s.platform == .phone
          ? ToneDeltaPair(
              roleA: primaryContainer,
              roleB: primary,
              delta: 5.0,
              polarity: .relativeLighter,
              constraint: .farther,
            )
          : null,
    );
    return _baseSpec.primary.extendSpecVersion(SpecVersion.spec2025, color2025);
  }

  @override
  DynamicColor get primaryDim {
    return DynamicColor(
      name: "primary_dim",
      palette: (s) => s.primaryPalette,
      tone: (s) {
        if (s.variant == .neutral) {
          return 85.0;
        } else if (s.variant == .tonalSpot) {
          return _tMaxC(s.primaryPalette, 0, 90);
        } else {
          return _tMaxC(s.primaryPalette);
        }
      },
      isBackground: true,
      background: (s) => surfaceContainerHigh,
      contrastCurve: (s) => _getContrastCurve(4.5),
      toneDeltaPair: (s) => ToneDeltaPair(
        roleA: primaryDim,
        roleB: primary,
        delta: 5.0,
        polarity: .darker,
        constraint: .farther,
      ),
    );
  }

  @override
  DynamicColor get onPrimary {
    final color2025 = DynamicColor(
      name: "on_primary",
      palette: (s) => s.primaryPalette,
      background: (s) => s.platform == .phone ? primary : primaryDim,
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(6) : _getContrastCurve(7),
    );
    return _baseSpec.onPrimary.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get primaryContainer {
    final color2025 = DynamicColor(
      name: "primary_container",
      palette: (s) => s.primaryPalette,
      tone: (s) {
        if (s.platform == .watch) {
          return 30.0;
        } else if (s.variant == .neutral) {
          return s.isDark ? 30.0 : 90.0;
        } else if (s.variant == .tonalSpot) {
          return s.isDark
              ? _tMinC(s.primaryPalette, 35, 93)
              : _tMaxC(s.primaryPalette, 0, 90);
        } else if (s.variant == .expressive) {
          return s.isDark
              ? _tMaxC(s.primaryPalette, 30, 93)
              : _tMaxC(
                  s.primaryPalette,
                  78,
                  Hct.isCyan(s.primaryPalette.hue) ? 88 : 90,
                );
        } else {
          // VIBRANT
          return s.isDark
              ? _tMinC(s.primaryPalette, 66, 93)
              : _tMaxC(
                  s.primaryPalette,
                  66,
                  Hct.isCyan(s.primaryPalette.hue) ? 88 : 93,
                );
        }
      },
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return null;
        }
      },
      toneDeltaPair: (s) => s.platform == .watch
          ? ToneDeltaPair(
              roleA: primaryContainer,
              roleB: primaryDim,
              delta: 10.0,
              polarity: .darker,
              constraint: .farther,
            )
          : null,
      contrastCurve: (s) => s.platform == .phone && s.contrastLevel > 0
          ? _getContrastCurve(1.5)
          : null,
    );
    return _baseSpec.primaryContainer.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onPrimaryContainer {
    final color2025 = DynamicColor(
      name: "on_primary_container",
      palette: (s) => s.primaryPalette,
      background: (s) => primaryContainer,
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(6) : _getContrastCurve(7),
    );
    return _baseSpec.onPrimaryContainer.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get inversePrimary {
    final color2025 = DynamicColor(
      name: "inverse_primary",
      palette: (s) => s.primaryPalette,
      tone: (s) => _tMaxC(s.primaryPalette),
      background: (s) => inverseSurface,
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(6) : _getContrastCurve(7),
    );
    return _baseSpec.inversePrimary.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get secondary {
    final color2025 = DynamicColor(
      name: "secondary",
      palette: (s) => s.secondaryPalette,
      tone: (s) {
        if (s.platform == .watch) {
          return s.variant == .neutral
              ? 90.0
              : _tMaxC(s.secondaryPalette, 0, 90);
        } else if (s.variant == .neutral) {
          return s.isDark
              ? _tMinC(s.secondaryPalette, 0, 98)
              : _tMaxC(s.secondaryPalette);
        } else if (s.variant == .vibrant) {
          return _tMaxC(s.secondaryPalette, 0, s.isDark ? 90 : 98);
        } else {
          // EXPRESSIVE and TONAL_SPOT
          return s.isDark ? 80.0 : _tMaxC(s.secondaryPalette);
        }
      },
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return surfaceContainerHigh;
        }
      },
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(4.5) : _getContrastCurve(7),
      toneDeltaPair: (s) => s.platform == .phone
          ? ToneDeltaPair(
              roleA: secondaryContainer,
              roleB: secondary,
              delta: 5.0,
              polarity: .relativeLighter,
              constraint: .farther,
            )
          : null,
    );
    return _baseSpec.secondary.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get secondaryDim {
    return DynamicColor(
      name: "secondary_dim",
      palette: (s) => s.secondaryPalette,
      tone: (s) {
        if (s.variant == .neutral) {
          return 85.0;
        } else {
          return _tMaxC(s.secondaryPalette, 0, 90);
        }
      },
      isBackground: true,
      background: (s) => surfaceContainerHigh,
      contrastCurve: (s) => _getContrastCurve(4.5),
      toneDeltaPair: (s) => ToneDeltaPair(
        roleA: secondaryDim,
        roleB: secondary,
        delta: 5.0,
        polarity: .darker,
        constraint: .farther,
      ),
    );
  }

  @override
  DynamicColor get onSecondary {
    final color2025 = DynamicColor(
      name: "on_secondary",
      palette: (s) => s.secondaryPalette,
      background: (s) => s.platform == .phone ? secondary : secondaryDim,
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(6) : _getContrastCurve(7),
    );
    return _baseSpec.onSecondary.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get secondaryContainer {
    final color2025 = DynamicColor(
      name: "secondary_container",
      palette: (s) => s.secondaryPalette,
      tone: (s) {
        if (s.platform == .watch) {
          return 30.0;
        } else if (s.variant == .vibrant) {
          return s.isDark
              ? _tMinC(s.secondaryPalette, 30, 40)
              : _tMaxC(s.secondaryPalette, 84, 90);
        } else if (s.variant == .expressive) {
          return s.isDark ? 15.0 : _tMaxC(s.secondaryPalette, 90, 95);
        } else {
          return s.isDark ? 25.0 : 90.0;
        }
      },
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return null;
        }
      },
      toneDeltaPair: (s) => s.platform == .watch
          ? ToneDeltaPair(
              roleA: secondaryContainer,
              roleB: secondaryDim,
              delta: 10.0,
              polarity: .darker,
              constraint: .farther,
            )
          : null,
      contrastCurve: (s) => s.platform == .phone && s.contrastLevel > 0.0
          ? _getContrastCurve(1.5)
          : null,
    );
    return _baseSpec.secondaryContainer.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onSecondaryContainer {
    final color2025 = DynamicColor(
      name: "on_secondary_container",
      palette: (s) => s.secondaryPalette,
      background: (s) => secondaryContainer,
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(6) : _getContrastCurve(7),
    );
    return _baseSpec.onSecondaryContainer.extendSpecVersion(
      .spec2025,
      color2025,
    );
  }

  @override
  DynamicColor get tertiary {
    final color2025 = DynamicColor(
      name: "tertiary",
      palette: (s) => s.tertiaryPalette,
      tone: (s) {
        if (s.platform == .watch) {
          return s.variant == .tonalSpot
              ? _tMaxC(s.tertiaryPalette, 0, 90)
              : _tMaxC(s.tertiaryPalette);
        } else if (s.variant == .expressive || s.variant == .vibrant) {
          return _tMaxC(
            s.tertiaryPalette,
            /* lowerBound= */ 0,
            /* upperBound= */ Hct.isCyan(s.tertiaryPalette.hue)
                ? 88
                : (s.isDark ? 98 : 100),
          );
        } else {
          // NEUTRAL and TONAL_SPOT
          return s.isDark
              ? _tMaxC(s.tertiaryPalette, 0, 98)
              : _tMaxC(s.tertiaryPalette);
        }
      },
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return surfaceContainerHigh;
        }
      },
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(4.5) : _getContrastCurve(7),
      toneDeltaPair: (s) => s.platform == .phone
          ? ToneDeltaPair(
              roleA: tertiaryContainer,
              roleB: tertiary,
              delta: 5.0,
              polarity: .relativeLighter,
              constraint: .farther,
            )
          : null,
    );
    return _baseSpec.tertiary.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get tertiaryDim {
    return DynamicColor(
      name: "tertiary_dim",
      palette: (s) => s.tertiaryPalette,
      tone: (s) {
        if (s.variant == .tonalSpot) {
          return _tMaxC(s.tertiaryPalette, 0, 90);
        } else {
          return _tMaxC(s.tertiaryPalette);
        }
      },
      isBackground: true,
      background: (s) => surfaceContainerHigh,
      contrastCurve: (s) => _getContrastCurve(4.5),
      toneDeltaPair: (s) => ToneDeltaPair(
        roleA: tertiaryDim,
        roleB: tertiary,
        delta: 5.0,
        polarity: .darker,
        constraint: .farther,
      ),
    );
  }

  @override
  DynamicColor get onTertiary {
    final color2025 = DynamicColor(
      name: "on_tertiary",
      palette: (s) => s.tertiaryPalette,
      background: (s) => s.platform == .phone ? tertiary : tertiaryDim,
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(6) : _getContrastCurve(7),
    );
    return _baseSpec.onTertiary.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get tertiaryContainer {
    final color2025 = DynamicColor(
      name: "tertiary_container",
      palette: (s) => s.tertiaryPalette,
      tone: (s) {
        if (s.platform == .watch) {
          return s.variant == .tonalSpot
              ? _tMaxC(s.tertiaryPalette, 0, 90)
              : _tMaxC(s.tertiaryPalette);
        } else {
          if (s.variant == .neutral) {
            return s.isDark
                ? _tMaxC(s.tertiaryPalette, 0, 93)
                : _tMaxC(s.tertiaryPalette, 0, 96);
          } else if (s.variant == .tonalSpot) {
            return _tMaxC(s.tertiaryPalette, 0, s.isDark ? 93 : 100);
          } else if (s.variant == .expressive) {
            return _tMaxC(
              s.tertiaryPalette,
              /* lowerBound= */ 75,
              /* upperBound= */ Hct.isCyan(s.tertiaryPalette.hue)
                  ? 88
                  : (s.isDark ? 93 : 100),
            );
          } else {
            // VIBRANT
            return s.isDark
                ? _tMaxC(s.tertiaryPalette, 0, 93)
                : _tMaxC(s.tertiaryPalette, 72, 100);
          }
        }
      },
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return null;
        }
      },
      toneDeltaPair: (s) => s.platform == .watch
          ? ToneDeltaPair(
              roleA: tertiaryContainer,
              roleB: tertiaryDim,
              delta: 10.0,
              polarity: .darker,
              constraint: .farther,
            )
          : null,
      contrastCurve: (s) => s.platform == .phone && s.contrastLevel > 0
          ? _getContrastCurve(1.5)
          : null,
    );
    return _baseSpec.tertiaryContainer.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onTertiaryContainer {
    final color2025 = DynamicColor(
      name: "on_tertiary_container",
      palette: (s) => s.tertiaryPalette,
      background: (s) => tertiaryContainer,
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(6) : _getContrastCurve(7),
    );
    return _baseSpec.onTertiaryContainer.extendSpecVersion(
      .spec2025,
      color2025,
    );
  }

  @override
  DynamicColor get error {
    final color2025 = DynamicColor(
      name: "error",
      palette: (s) => s.errorPalette,
      tone: (s) {
        if (s.platform == .phone) {
          return s.isDark
              ? _tMinC(s.errorPalette, 0, 98)
              : _tMaxC(s.errorPalette);
        } else {
          return _tMinC(s.errorPalette);
        }
      },
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return surfaceContainerHigh;
        }
      },
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(4.5) : _getContrastCurve(7),
      toneDeltaPair: (s) => s.platform == .phone
          ? ToneDeltaPair(
              roleA: errorContainer,
              roleB: error,
              delta: 5.0,
              polarity: .relativeLighter,
              constraint: .farther,
            )
          : null,
    );
    return _baseSpec.error.extendSpecVersion(SpecVersion.spec2025, color2025);
  }

  @override
  DynamicColor get errorDim {
    return DynamicColor(
      name: "error_dim",
      palette: (s) => s.errorPalette,
      tone: (s) => _tMinC(s.errorPalette),
      isBackground: true,
      background: (s) => surfaceContainerHigh,
      contrastCurve: (s) => _getContrastCurve(4.5),
      toneDeltaPair: (s) => ToneDeltaPair(
        roleA: errorDim,
        roleB: error,
        delta: 5.0,
        polarity: .darker,
        constraint: .farther,
      ),
    );
  }

  @override
  DynamicColor get onError {
    final color2025 = DynamicColor(
      name: "on_error",
      palette: (s) => s.errorPalette,
      background: (s) => s.platform == .phone ? error : errorDim,
      contrastCurve: (s) =>
          s.platform == .phone ? _getContrastCurve(6) : _getContrastCurve(7),
    );
    return _baseSpec.onError.extendSpecVersion(SpecVersion.spec2025, color2025);
  }

  @override
  DynamicColor get errorContainer {
    final color2025 = DynamicColor(
      name: "error_container",
      palette: (s) => s.errorPalette,
      tone: (s) {
        if (s.platform == .watch) {
          return 30.0;
        } else {
          return s.isDark
              ? _tMinC(s.errorPalette, 30, 93)
              : _tMaxC(s.errorPalette, 0, 90);
        }
      },
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return null;
        }
      },
      toneDeltaPair: (s) => s.platform == .watch
          ? ToneDeltaPair(
              roleA: errorContainer,
              roleB: errorDim,
              delta: 10.0,
              polarity: .darker,
              constraint: .farther,
            )
          : null,
      contrastCurve: (s) => s.platform == .phone && s.contrastLevel > 0
          ? _getContrastCurve(1.5)
          : null,
    );
    return _baseSpec.errorContainer.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onErrorContainer {
    final color2025 = DynamicColor(
      name: "on_error_container",
      palette: (s) => s.errorPalette,
      background: (s) => errorContainer,
      contrastCurve: (s) => s.platform == .phone
          ? _getContrastCurve(4.5)
          : _getContrastCurve(7.0),
    );
    return _baseSpec.onErrorContainer.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get primaryFixed {
    final color2025 = DynamicColor(
      name: "primary_fixed",
      palette: (s) => s.primaryPalette,
      tone: (s) {
        return primaryContainer.getTone(.from(s, false, 0.0));
      },
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return null;
        }
      },
      contrastCurve: (s) => s.platform == .phone && s.contrastLevel > 0.0
          ? _getContrastCurve(1.5)
          : null,
    );
    return _baseSpec.primaryFixed.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get primaryFixedDim {
    final color2025 = DynamicColor(
      name: "primary_fixed_dim",
      palette: (s) => s.primaryPalette,
      tone: (s) => primaryFixed.getTone(s),
      isBackground: true,
      toneDeltaPair: (s) => ToneDeltaPair(
        roleA: primaryFixedDim,
        roleB: primaryFixed,
        delta: 5.0,
        polarity: .darker,
        constraint: .exact,
      ),
    );
    return _baseSpec.primaryFixedDim.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onPrimaryFixed {
    final color2025 = DynamicColor(
      name: "on_primary_fixed",
      palette: (s) => s.primaryPalette,
      background: (s) => primaryFixedDim,
      contrastCurve: (s) => _getContrastCurve(7),
    );
    return _baseSpec.onPrimaryFixed.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onPrimaryFixedVariant {
    final color2025 = DynamicColor(
      name: "on_primary_fixed_variant",
      palette: (s) => s.primaryPalette,
      background: (s) => primaryFixedDim,
      contrastCurve: (s) => _getContrastCurve(4.5),
    );
    return _baseSpec.onPrimaryFixedVariant.extendSpecVersion(
      .spec2025,
      color2025,
    );
  }

  @override
  DynamicColor get secondaryFixed {
    final color2025 = DynamicColor(
      name: "secondary_fixed",
      palette: (s) => s.secondaryPalette,
      tone: (s) => secondaryContainer.getTone(.from(s, false, 0.0)),
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return null;
        }
      },
      contrastCurve: (s) => s.platform == .phone && s.contrastLevel > 0.0
          ? _getContrastCurve(1.5)
          : null,
    );
    return _baseSpec.secondaryFixed.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get secondaryFixedDim {
    final color2025 = DynamicColor(
      name: "secondary_fixed_dim",
      palette: (s) => s.secondaryPalette,
      tone: (s) => secondaryFixed.getTone(s),
      isBackground: true,
      toneDeltaPair: (s) => ToneDeltaPair(
        roleA: secondaryFixedDim,
        roleB: secondaryFixed,
        delta: 5.0,
        polarity: .darker,
        constraint: .exact,
      ),
    );
    return _baseSpec.secondaryFixedDim.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onSecondaryFixed {
    final color2025 = DynamicColor(
      name: "on_secondary_fixed",
      palette: (s) => s.secondaryPalette,
      background: (s) => secondaryFixedDim,
      contrastCurve: (s) => _getContrastCurve(7),
    );
    return _baseSpec.onSecondaryFixed.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onSecondaryFixedVariant {
    final color2025 = DynamicColor(
      name: "on_secondary_fixed_variant",
      palette: (s) => s.secondaryPalette,
      background: (s) => secondaryFixedDim,
      contrastCurve: (s) => _getContrastCurve(4.5),
    );
    return _baseSpec.onSecondaryFixedVariant.extendSpecVersion(
      .spec2025,
      color2025,
    );
  }

  @override
  DynamicColor get tertiaryFixed {
    final color2025 = DynamicColor(
      name: "tertiary_fixed",
      palette: (s) => s.tertiaryPalette,
      tone: (s) => tertiaryContainer.getTone(.from(s, false, 0.0)),
      isBackground: true,
      background: (s) {
        if (s.platform == .phone) {
          return s.isDark ? surfaceBright : surfaceDim;
        } else {
          return null;
        }
      },
      contrastCurve: (s) => s.platform == .phone && s.contrastLevel > 0.0
          ? _getContrastCurve(1.5)
          : null,
    );
    return _baseSpec.tertiaryFixed.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get tertiaryFixedDim {
    final color2025 = DynamicColor(
      name: "tertiary_fixed_dim",
      palette: (s) => s.tertiaryPalette,
      tone: (s) => tertiaryFixed.getTone(s),
      isBackground: true,
      toneDeltaPair: (s) => ToneDeltaPair(
        roleA: tertiaryFixedDim,
        roleB: tertiaryFixed,
        delta: 5.0,
        polarity: .darker,
        constraint: .exact,
      ),
    );
    return _baseSpec.tertiaryFixedDim.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onTertiaryFixed {
    final color2025 = DynamicColor(
      name: "on_tertiary_fixed",
      palette: (s) => s.tertiaryPalette,
      background: (s) => tertiaryFixedDim,
      contrastCurve: (s) => _getContrastCurve(7.0),
    );
    return _baseSpec.onTertiaryFixed.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get onTertiaryFixedVariant {
    final color2025 = DynamicColor(
      name: "on_tertiary_fixed_variant",
      palette: (s) => s.tertiaryPalette,
      background: (s) => tertiaryFixedDim,
      contrastCurve: (s) => _getContrastCurve(4.5),
    );
    return _baseSpec.onTertiaryFixedVariant.extendSpecVersion(
      .spec2025,
      color2025,
    );
  }

  @override
  DynamicColor get controlActivated {
    // Remapped to primaryContainer for 2025 spec.
    final color2025 = primaryContainer.copyWith(name: "control_activated");
    return _baseSpec.controlActivated.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get controlNormal {
    // Remapped to onSurfaceVariant for 2025 spec.
    final color2025 = onSurfaceVariant.copyWith(name: "control_normal");
    return _baseSpec.controlNormal.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get controlHighlight => _baseSpec.controlHighlight;

  @override
  DynamicColor get textPrimaryInverse {
    // Remapped to inverseOnSurface for 2025 spec.
    final color2025 = inverseOnSurface.copyWith(name: "text_primary_inverse");
    return _baseSpec.textPrimaryInverse.extendSpecVersion(.spec2025, color2025);
  }

  @override
  DynamicColor get textSecondaryAndTertiaryInverse =>
      _baseSpec.textSecondaryAndTertiaryInverse;

  @override
  DynamicColor get textPrimaryInverseDisableOnly =>
      _baseSpec.textPrimaryInverseDisableOnly;

  @override
  DynamicColor get textSecondaryAndTertiaryInverseDisabled =>
      _baseSpec.textSecondaryAndTertiaryInverseDisabled;

  @override
  DynamicColor get textHintInverse => _baseSpec.textHintInverse;

  @override
  DynamicColor highestSurface(DynamicScheme scheme) {
    return _baseSpec.highestSurface(scheme);
  }

  @override
  Hct getHct(DynamicScheme scheme, DynamicColor color) {
    // This is crucial for aesthetics: we aren't simply the taking the standard color
    // and changing its tone for contrast. Rather, we find the tone for contrast, then
    // use the specified chroma from the palette to construct a new color.
    //
    // For example, this enables colors with standard tone of T90, which has limited chroma, to
    // "recover" intended chroma as contrast increases.
    final palette = color.palette(scheme);
    final tone = getTone(scheme, color);
    final hue = palette.hue;
    final chromaMultiplier = color.chromaMultiplier?.call(scheme) ?? 1.0;
    final chroma = palette.chroma * chromaMultiplier;

    return Hct.from(hue, chroma, tone);
  }

  @override
  double getTone(DynamicScheme scheme, DynamicColor color) {
    final toneDeltaPair = color.toneDeltaPair?.call(scheme);

    // Case 0: tone delta pair.
    if (toneDeltaPair != null) {
      final roleA = toneDeltaPair.roleA;
      final roleB = toneDeltaPair.roleB;
      final polarity = toneDeltaPair.polarity;
      final constraint = toneDeltaPair.constraint;
      final absoluteDelta =
          polarity == .darker ||
              (polarity == .relativeLighter && scheme.isDark) ||
              (polarity == .relativeDarker && !scheme.isDark)
          ? -toneDeltaPair.delta
          : toneDeltaPair.delta;

      final amRoleA = color.name == roleA.name;
      final selfRole = amRoleA ? roleA : roleB;
      final referenceRole = amRoleA ? roleB : roleA;
      var selfTone = selfRole.tone(scheme);
      final referenceTone = referenceRole.getTone(scheme);
      final relativeDelta = absoluteDelta * (amRoleA ? 1.0 : -1.0);

      switch (constraint) {
        case .exact:
          selfTone = MathUtils.clampDouble(
            0.0,
            100.0,
            referenceTone + relativeDelta,
          );
          break;
        case .nearer:
          if (relativeDelta > 0.0) {
            selfTone = MathUtils.clampDouble(
              0.0,
              100.0,
              MathUtils.clampDouble(
                referenceTone,
                referenceTone + relativeDelta,
                selfTone,
              ),
            );
          } else {
            selfTone = MathUtils.clampDouble(
              0.0,
              100.0,
              MathUtils.clampDouble(
                referenceTone + relativeDelta,
                referenceTone,
                selfTone,
              ),
            );
          }
          break;
        case .farther:
          if (relativeDelta > 0.0) {
            selfTone = MathUtils.clampDouble(
              referenceTone + relativeDelta,
              100.0,
              selfTone,
            );
          } else {
            selfTone = MathUtils.clampDouble(
              0.0,
              referenceTone + relativeDelta,
              selfTone,
            );
          }
          break;
      }

      if (color.background != null && color.contrastCurve != null) {
        final background = color.background!(scheme);
        final contrastCurve = color.contrastCurve!(scheme);
        if (background != null && contrastCurve != null) {
          final bgTone = background.getTone(scheme);
          final selfContrast = contrastCurve.get(scheme.contrastLevel);
          selfTone =
              Contrast.ratioOfTones(bgTone, selfTone) >= selfContrast &&
                  scheme.contrastLevel >= 0.0
              ? selfTone
              : DynamicColor.foregroundTone(bgTone, selfContrast);
        }
      }

      // This can avoid the awkward tones for background colors including the access fixed colors.
      // Accent fixed dim colors should not be adjusted.
      if (color.isBackground && !color.name.endsWith("_fixed_dim")) {
        if (selfTone >= 57) {
          selfTone = MathUtils.clampDouble(65.0, 100.0, selfTone);
        } else {
          selfTone = MathUtils.clampDouble(0.0, 49.0, selfTone);
        }
      }

      return selfTone;
    } else {
      // Case 1: No tone delta pair; just solve for itself.
      double answer = color.tone(scheme);

      if (color.background?.call(scheme) == null ||
          color.contrastCurve?.call(scheme) == null) {
        return answer; // No adjustment for colors with no background.
      }

      final bgTone = color.background!(scheme)!.getTone(scheme);
      final desiredRatio = color.contrastCurve!(scheme)!.get(
        scheme.contrastLevel,
      );

      // Recalculate the tone from desired contrast ratio if the current
      // contrast ratio is not enough or desired contrast level is decreasing
      // (<0).
      answer =
          Contrast.ratioOfTones(bgTone, answer) >= desiredRatio &&
              scheme.contrastLevel >= 0.0
          ? answer
          : DynamicColor.foregroundTone(bgTone, desiredRatio);

      // This can avoid the awkward tones for background colors including the access fixed colors.
      // Accent fixed dim colors should not be adjusted.
      if (color.isBackground && !color.name.endsWith("_fixed_dim")) {
        if (answer >= 57.0) {
          answer = MathUtils.clampDouble(65.0, 100.0, answer);
        } else {
          answer = MathUtils.clampDouble(0.0, 49.0, answer);
        }
      }

      if (color.secondBackground?.call(scheme) == null) {
        return answer;
      }

      // Case 2: Adjust for dual backgrounds.
      final bgTone1 = color.background!(scheme)!.getTone(scheme);
      final bgTone2 = color.secondBackground!(scheme)!.getTone(scheme);
      final upper = math.max(bgTone1, bgTone2);
      final lower = math.min(bgTone1, bgTone2);

      if (Contrast.ratioOfTones(upper, answer) >= desiredRatio &&
          Contrast.ratioOfTones(lower, answer) >= desiredRatio) {
        return answer;
      }

      // The darkest light tone that satisfies the desired ratio,
      // or -1 if such ratio cannot be reached.
      final lightOption = Contrast.lighter(upper, desiredRatio);

      // The lightest dark tone that satisfies the desired ratio,
      // or -1 if such ratio cannot be reached.
      final darkOption = Contrast.darker(lower, desiredRatio);

      // Tones suitable for the foreground.
      final availables = <double>[?lightOption, ?darkOption];
      final prefersLight =
          DynamicColor.tonePrefersLightForeground(bgTone1) ||
          DynamicColor.tonePrefersLightForeground(bgTone2);
      if (prefersLight) {
        return lightOption ?? 100.0;
      }
      return availables.length == 1 ? availables[0] : (darkOption ?? 0.0);
    }
  }

  @override
  TonalPalette getPrimaryPalette(
    Variant variant,
    Hct sourceColorHct,
    bool isDark,
    Platform platform,
    double contrastLevel,
  ) => switch (variant) {
    .neutral => .fromHueAndChroma(
      sourceColorHct.hue,
      platform == .phone
          ? (Hct.isBlue(sourceColorHct.hue) ? 12.0 : 8.0)
          : (Hct.isBlue(sourceColorHct.hue) ? 16.0 : 12.0),
    ),
    .tonalSpot => .fromHueAndChroma(
      sourceColorHct.hue,
      platform == .phone && isDark ? 26.0 : 32.0,
    ),
    .expressive => .fromHueAndChroma(
      sourceColorHct.hue,
      platform == .phone ? (isDark ? 36.0 : 48.0) : 40.0,
    ),
    .vibrant => .fromHueAndChroma(
      sourceColorHct.hue,
      platform == .phone ? 74.0 : 56.0,
    ),
    _ => _baseSpec.getPrimaryPalette(
      variant,
      sourceColorHct,
      isDark,
      platform,
      contrastLevel,
    ),
  };

  @override
  TonalPalette getSecondaryPalette(
    Variant variant,
    Hct sourceColorHct,
    bool isDark,
    Platform platform,
    double contrastLevel,
  ) => switch (variant) {
    .neutral => .fromHueAndChroma(
      sourceColorHct.hue,
      platform == .phone
          ? (Hct.isBlue(sourceColorHct.hue) ? 6.0 : 4.0)
          : (Hct.isBlue(sourceColorHct.hue) ? 10.0 : 6.0),
    ),
    .tonalSpot => .fromHueAndChroma(sourceColorHct.hue, 16.0),
    .expressive => .fromHueAndChroma(
      DynamicScheme.getRotatedHue(
        sourceColorHct,
        const [0.0, 105.0, 140.0, 204.0, 253.0, 278.0, 300.0, 333.0, 360.0],
        const [-160.0, 155.0, -100.0, 96.0, -96.0, -156.0, -165.0, -160.0],
      ),
      platform == .phone ? (isDark ? 16.0 : 24.0) : 24.0,
    ),
    .vibrant => .fromHueAndChroma(
      DynamicScheme.getRotatedHue(
        sourceColorHct,
        const [0.0, 38.0, 105.0, 140.0, 333.0, 360.0],
        const [-14.0, 10.0, -14.0, 10.0, -14.0],
      ),
      platform == .phone ? 56.0 : 36.0,
    ),
    _ => _baseSpec.getSecondaryPalette(
      variant,
      sourceColorHct,
      isDark,
      platform,
      contrastLevel,
    ),
  };

  @override
  TonalPalette getTertiaryPalette(
    Variant variant,
    Hct sourceColorHct,
    bool isDark,
    Platform platform,
    double contrastLevel,
  ) => switch (variant) {
    .neutral => .fromHueAndChroma(
      DynamicScheme.getRotatedHue(
        sourceColorHct,
        const [0.0, 38.0, 105.0, 161.0, 204.0, 278.0, 333.0, 360.0],
        const [-32.0, 26.0, 10.0, -39.0, 24.0, -15.0, -32.0],
      ),
      platform == .phone ? 20.0 : 36.0,
    ),
    .tonalSpot => .fromHueAndChroma(
      DynamicScheme.getRotatedHue(
        sourceColorHct,
        const [0.0, 20.0, 71.0, 161.0, 333.0, 360.0],
        const [-40.0, 48.0, -32.0, 40.0, -32.0],
      ),
      platform == .phone ? 28.0 : 32.0,
    ),
    .expressive => .fromHueAndChroma(
      DynamicScheme.getRotatedHue(
        sourceColorHct,
        const [0.0, 105.0, 140.0, 204.0, 253.0, 278.0, 300.0, 333.0, 360.0],
        const [-165.0, 160.0, -105.0, 101.0, -101.0, -160.0, -170.0, -165.0],
      ),
      48.0,
    ),
    .vibrant => .fromHueAndChroma(
      DynamicScheme.getRotatedHue(
        sourceColorHct,
        const [0.0, 38.0, 71.0, 105.0, 140.0, 161.0, 253.0, 333.0, 360.0],
        const [-72.0, 35.0, 24.0, -24.0, 62.0, 50.0, 62.0, -72.0],
      ),
      56.0,
    ),
    _ => _baseSpec.getTertiaryPalette(
      variant,
      sourceColorHct,
      isDark,
      platform,
      contrastLevel,
    ),
  };

  @override
  TonalPalette getNeutralPalette(
    Variant variant,
    Hct sourceColorHct,
    bool isDark,
    Platform platform,
    double contrastLevel,
  ) => switch (variant) {
    .neutral => .fromHueAndChroma(
      sourceColorHct.hue,
      platform == .phone ? 1.4 : 6.0,
    ),
    .tonalSpot => .fromHueAndChroma(
      sourceColorHct.hue,
      platform == .phone ? 5.0 : 10.0,
    ),
    .expressive => .fromHueAndChroma(
      _getExpressiveNeutralHue(sourceColorHct),
      _getExpressiveNeutralChroma(sourceColorHct, isDark, platform),
    ),
    .vibrant => .fromHueAndChroma(
      _getVibrantNeutralHue(sourceColorHct),
      _getVibrantNeutralChroma(sourceColorHct, platform),
    ),
    _ => _baseSpec.getNeutralPalette(
      variant,
      sourceColorHct,
      isDark,
      platform,
      contrastLevel,
    ),
  };

  @override
  TonalPalette getNeutralVariantPalette(
    Variant variant,
    Hct sourceColorHct,
    bool isDark,
    Platform platform,
    double contrastLevel,
  ) {
    switch (variant) {
      case .neutral:
        return .fromHueAndChroma(
          sourceColorHct.hue,
          (platform == .phone ? 1.4 : 6.0) * 2.2,
        );
      case .tonalSpot:
        return .fromHueAndChroma(
          sourceColorHct.hue,
          (platform == .phone ? 5.0 : 10.0) * 1.7,
        );
      case .expressive:
        final expressiveNeutralHue = _getExpressiveNeutralHue(sourceColorHct);
        final expressiveNeutralChroma = _getExpressiveNeutralChroma(
          sourceColorHct,
          isDark,
          platform,
        );
        return .fromHueAndChroma(
          expressiveNeutralHue,
          expressiveNeutralChroma *
              (expressiveNeutralHue >= 105.0 && expressiveNeutralHue < 125.0
                  ? 1.6
                  : 2.3),
        );
      case .vibrant:
        final vibrantNeutralHue = _getVibrantNeutralHue(sourceColorHct);
        final vibrantNeutralChroma = _getVibrantNeutralChroma(
          sourceColorHct,
          platform,
        );
        return .fromHueAndChroma(
          vibrantNeutralHue,
          vibrantNeutralChroma * 1.29,
        );
      default:
        return _baseSpec.getNeutralVariantPalette(
          variant,
          sourceColorHct,
          isDark,
          platform,
          contrastLevel,
        );
    }
  }

  @override
  TonalPalette getErrorPalette(
    Variant variant,
    Hct sourceColorHct,
    bool isDark,
    Platform platform,
    double contrastLevel,
  ) {
    final errorHue = DynamicScheme.getPiecewiseValue(
      sourceColorHct,
      const [0.0, 3.0, 13.0, 23.0, 33.0, 43.0, 153.0, 273.0, 360.0],
      const [12.0, 22.0, 32.0, 12.0, 22.0, 32.0, 22.0, 12.0],
    );
    return switch (variant) {
      .neutral => .fromHueAndChroma(errorHue, platform == .phone ? 50.0 : 40.0),
      .tonalSpot => .fromHueAndChroma(
        errorHue,
        platform == .phone ? 60.0 : 48.0,
      ),
      .expressive => .fromHueAndChroma(
        errorHue,
        platform == .phone ? 64.0 : 48.0,
      ),
      .vibrant => .fromHueAndChroma(errorHue, platform == .phone ? 80.0 : 60.0),
      _ => _baseSpec.getErrorPalette(
        variant,
        sourceColorHct,
        isDark,
        platform,
        contrastLevel,
      ),
    };
  }

  static double _getExpressiveNeutralHue(Hct sourceColorHct) =>
      DynamicScheme.getRotatedHue(
        sourceColorHct,
        const [0.0, 71.0, 124.0, 253.0, 278.0, 300.0, 360.0],
        const [10.0, 0.0, 10.0, 0.0, 10.0, 0.0],
      );

  static double _getExpressiveNeutralChroma(
    Hct sourceColorHct,
    bool isDark,
    Platform platform,
  ) => platform == .phone
      ? (isDark
            ? (Hct.isYellow(_getExpressiveNeutralHue(sourceColorHct))
                  ? 6.0
                  : 14.0)
            : 18.0)
      : 12.0;

  static double _getVibrantNeutralHue(Hct sourceColorHct) =>
      DynamicScheme.getRotatedHue(
        sourceColorHct,
        const [0.0, 38.0, 105.0, 140.0, 333.0, 360.0],
        const [-14.0, 10.0, -14.0, 10.0, -14.0],
      );

  static double _getVibrantNeutralChroma(
    Hct sourceColorHct,
    Platform platform,
  ) => platform == .phone
      ? 28.0
      : (Hct.isBlue(_getVibrantNeutralHue(sourceColorHct)) ? 28.0 : 20.0);

  static double _tMaxC(
    TonalPalette palette, [
    double lowerBound = 0.0,
    double upperBound = 100.0,
    double chromaMultiplier = 1.0,
  ]) {
    final answer = _findBestToneForChroma(
      palette.hue,
      palette.chroma * chromaMultiplier,
      100.0,
      true,
    );
    return MathUtils.clampDouble(lowerBound, upperBound, answer);
  }

  static double _tMinC(
    TonalPalette palette, [
    double lowerBound = 0.0,
    double upperBound = 100.0,
  ]) {
    final answer = _findBestToneForChroma(
      palette.hue,
      palette.chroma,
      0.0,
      false,
    );
    return MathUtils.clampDouble(lowerBound, upperBound, answer);
  }

  static double _findBestToneForChroma(
    double hue,
    double chroma,
    double tone,
    bool byDecreasingTone,
  ) {
    var answer = tone;
    var bestCandidate = Hct.from(hue, chroma, answer);
    while (bestCandidate.chroma < chroma) {
      if (tone < 0.0 || tone > 100.0) {
        break;
      }
      tone += byDecreasingTone ? -1.0 : 1.0;
      final newCandidate = Hct.from(hue, chroma, tone);
      if (bestCandidate.chroma < newCandidate.chroma) {
        bestCandidate = newCandidate;
        answer = tone;
      }
    }
    return answer;
  }

  static ContrastCurve _getContrastCurve(double defaultContrast) {
    return switch (defaultContrast) {
      1.5 => const ContrastCurve(1.5, 1.5, 3.0, 5.5),
      3.0 => const ContrastCurve(3.0, 3.0, 4.5, 7.0),
      4.5 => const ContrastCurve(4.5, 4.5, 7.0, 11.0),
      6.0 => const ContrastCurve(6.0, 6.0, 7.0, 11.0),
      7.0 => const ContrastCurve(7.0, 7.0, 11.0, 21.0),
      9.0 => const ContrastCurve(9.0, 9.0, 11.0, 21.0),
      11.0 => const ContrastCurve(11.0, 11.0, 21.0, 21.0),
      21.0 => const ContrastCurve(21.0, 21.0, 21.0, 21.0),
      _ => ContrastCurve(defaultContrast, defaultContrast, 7.0, 21.0),
    };
  }
}
