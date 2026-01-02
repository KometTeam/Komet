import 'dart:math' as math;

abstract final class MathUtils {
  static T signum<T extends num>(T num) => num.sign as T;

  static double lerp(double start, double stop, double amount) =>
      (1.0 - amount) * start + amount * stop;

  static int clampInt(int min, int max, int input) {
    if (input < min) {
      return min;
    } else if (input > max) {
      return max;
    }
    return input;
  }

  static double clampDouble(double min, double max, double input) {
    if (input < min) {
      return min;
    } else if (input > max) {
      return max;
    }
    return input;
  }

  static int sanitizeDegreesInt(int degrees) {
    degrees = degrees % 360;
    if (degrees < 0) {
      degrees = degrees + 360;
    }
    return degrees;
  }

  static double sanitizeDegreesDouble(double degrees) {
    degrees = degrees % 360.0;
    if (degrees < 0.0) {
      degrees = degrees + 360.0;
    }
    return degrees;
  }

  static double rotationDirection(double from, double to) =>
      sanitizeDegreesDouble(to - from) <= 180.0 ? 1.0 : -1.0;

  static double differenceDegrees(double a, double b) =>
      180.0 - ((a - b).abs() - 180.0).abs();

  static List<double> matrixMultiply(
    List<double> row,
    List<List<double>> matrix,
  ) => [
    row[0] * matrix[0][0] + row[1] * matrix[0][1] + row[2] * matrix[0][2],
    row[0] * matrix[1][0] + row[1] * matrix[1][1] + row[2] * matrix[1][2],
    row[0] * matrix[2][0] + row[1] * matrix[2][1] + row[2] * matrix[2][2],
  ];

  static double toRadians(double degrees) => degrees * math.pi / 180.0;

  static double toDegrees(double radians) => radians * 180.0 / math.pi;

  static double hypot(double a, double b) => math.sqrt(a * a + b * b);
}
