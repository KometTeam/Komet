import '../utils/color_utils.dart';

import 'point_provider.dart';

/// Provides conversions needed for K-Means quantization. Converting input to points, and converting
/// the final state of the K-Means algorithm to colors.
final class PointProviderLab implements PointProvider {
  const PointProviderLab();

  /// Convert a color represented in ARGB to a 3-element array of L*a*b* coordinates of the color.
  @override
  List<double> fromInt(int argb) {
    final lab = ColorUtils.labFromArgb(argb);
    return [lab[0], lab[1], lab[2]];
  }

  /// Convert a 3-element array to a color represented in ARGB.
  @override
  int toInt(List<double> lab) {
    return ColorUtils.argbFromLab(lab[0], lab[1], lab[2]);
  }

  /// Standard CIE 1976 delta E formula also takes the square root, unneeded here.
  /// This method is used by quantization algorithms to compare distance,
  /// and the relative ordering is the same,
  /// with or without a square root.
  ///
  /// This relatively minor optimization is helpful
  /// because this method is called at least once for each pixel in an image.
  @override
  double distance(List<double> one, List<double> two) {
    final dL = (one[0] - two[0]);
    final dA = (one[1] - two[1]);
    final dB = (one[2] - two[2]);
    return (dL * dL + dA * dA + dB * dB);
  }
}
