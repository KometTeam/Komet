/// An interface to allow use of different color spaces by quantizers.
abstract interface class PointProvider {
  /// The four components in the color space of an sRGB color.
  List<double> fromInt(int argb);

  /// The ARGB (i.e. hex code) representation of this color.
  int toInt(List<double> point);

  /// Squared distance between two colors.
  /// Distance is defined by scientific color spaces and
  /// referred to as delta E.
  double distance(List<double> a, List<double> b);
}
