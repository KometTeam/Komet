import 'dart:math' as math;

import '../utils/math_utils.dart';
import '../utils/color_utils.dart';
import '../hct/cam16.dart';
import '../hct/hct.dart';

/// Functions for blending in HCT and CAM16.
abstract final class Blend {
  /// Blend the design color's HCT hue towards the key color's HCT hue,
  /// in a way that leaves the original color recognizable and recognizably
  /// shifted towards the key color.
  ///
  /// Returns the design color with a hue shifted towards the system's color,
  /// a slightly warmer/cooler variant of the design color's hue.
  static int harmonize(int designColor, int sourceColor) {
    final fromHct = Hct.fromInt(designColor);
    final toHct = Hct.fromInt(sourceColor);
    final differenceDegrees = MathUtils.differenceDegrees(
      fromHct.hue,
      toHct.hue,
    );
    final rotationDegrees = math.min(differenceDegrees * 0.5, 15.0);
    final outputHue = MathUtils.sanitizeDegreesDouble(
      fromHct.hue +
          rotationDegrees * MathUtils.rotationDirection(fromHct.hue, toHct.hue),
    );
    return Hct.from(outputHue, fromHct.chroma, fromHct.tone).toInt();
  }

  /// Blends hue from one color into another.
  /// The chroma and tone of the original color are maintained.
  static int hctHue(int from, int to, double amount) {
    final ucs = cam16Ucs(from, to, amount);
    final ucsCam = Cam16.fromInt(ucs);
    final fromCam = Cam16.fromInt(from);
    final blended = Hct.from(
      ucsCam.hue,
      fromCam.chroma,
      ColorUtils.lstarFromArgb(from),
    );
    return blended.toInt();
  }

  /// Blend in CAM16-UCS space.
  static int cam16Ucs(int from, int to, double amount) {
    final fromCam = Cam16.fromInt(from);
    final toCam = Cam16.fromInt(to);
    final jstar = MathUtils.lerp(fromCam.jstar, toCam.jstar, amount);
    final astar = MathUtils.lerp(fromCam.astar, toCam.astar, amount);
    final bstar = MathUtils.lerp(fromCam.bstar, toCam.bstar, amount);
    return Cam16.fromUcs(jstar, astar, bstar).toInt();
  }
}
