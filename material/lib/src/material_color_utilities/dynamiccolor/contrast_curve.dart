import '../utils/math_utils.dart';

/// A class containing a value that changes with the contrast level.
///
/// Usually represents the contrast requirements for a dynamic color on its
/// background. The four values correspond to values for contrast levels
/// -1.0, 0.0, 0.5, and 1.0, respectively.
final class ContrastCurve {
  const ContrastCurve(this.low, this.normal, this.medium, this.high);

  /// Value for contrast level -1.0.
  final double low;

  /// Value for contrast level 0.0.
  final double normal;

  /// Value for contrast level 0.5.
  final double medium;

  /// Value for contrast level 1.0.
  final double high;

  /// Returns the value at a given contrast level.
  double get(double contrastLevel) => contrastLevel <= -1.0
      ? low
      : contrastLevel < 0.0
      ? MathUtils.lerp(low, normal, (contrastLevel - -1.0) / 1.0)
      : contrastLevel < 0.5
      ? MathUtils.lerp(normal, medium, (contrastLevel - 0.0) / 0.5)
      : contrastLevel < 1.0
      ? MathUtils.lerp(medium, high, (contrastLevel - 0.5) / 0.5)
      : high;

  @override
  String toString() => "ContrastCurve($low, $normal, $medium, $high)";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is ContrastCurve &&
          low == other.low &&
          normal == other.normal &&
          medium == other.medium &&
          high == other.high;

  @override
  int get hashCode => Object.hash(low, normal, medium, high);
}
