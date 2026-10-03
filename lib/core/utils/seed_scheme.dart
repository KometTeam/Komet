import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

const double kAchromaticSeedChroma = 10;

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
