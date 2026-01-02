import 'color_spec.dart';
import 'color_spec_2021.dart';
import 'color_spec_2025.dart';

/// A utility class to get the correct color spec for a given spec version.
abstract final class ColorSpecs {
  static const ColorSpec _spec2021 = ColorSpec2021();
  static const ColorSpec _spec2025 = ColorSpec2025();

  static ColorSpec get([
    SpecVersion specVersion = .spec2021,
    bool isExtendedFidelity = false,
  ]) => specVersion == .spec2025 ? _spec2025 : _spec2021;
}
