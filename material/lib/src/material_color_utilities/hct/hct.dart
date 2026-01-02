import '../utils/color_utils.dart';

import 'viewing_conditions.dart';
import 'cam16.dart';
import 'hct_solver.dart';

final class Hct {
  Hct._(int argb) {
    _setInternalState(argb);
  }

  factory Hct.from(double hue, double chroma, double tone) =>
      ._(HctSolver.solveToInt(hue, chroma, tone));

  factory Hct.fromInt(int argb) => ._(argb);

  late int _argb;
  late double _hue;
  late double _chroma;
  late double _tone;

  double get hue => _hue;
  set hue(double newHue) {
    _setInternalState(HctSolver.solveToInt(newHue, chroma, tone));
  }

  double get chroma => _chroma;
  set chroma(double newChroma) {
    _setInternalState(HctSolver.solveToInt(hue, newChroma, tone));
  }

  double get tone => _tone;
  set tone(double newTone) {
    _setInternalState(HctSolver.solveToInt(hue, chroma, newTone));
  }

  int toInt() => _argb;

  Hct inViewingConditions(ViewingConditions vc) {
    // 1. Use CAM16 to find XYZ coordinates of color in specified VC.
    final cam16 = Cam16.fromInt(toInt());
    final viewedInVc = cam16.xyzInViewingConditions(vc);

    // 2. Create CAM16 of those XYZ coordinates in default VC.
    final recastInVc = Cam16.fromXyzInViewingConditions(
      viewedInVc[0],
      viewedInVc[1],
      viewedInVc[2],
      ViewingConditions.sRgb,
    );

    // 3. Create HCT from:
    // - CAM16 using default VC with XYZ coordinates in specified VC.
    // - L* converted from Y in XYZ coordinates in specified VC.
    return .from(
      recastInVc.hue,
      recastInVc.chroma,
      ColorUtils.lstarFromY(viewedInVc[1]),
    );
  }

  void _setInternalState(int argb) {
    _argb = argb;
    final cam = Cam16.fromInt(argb);
    _hue = cam.hue;
    _chroma = cam.chroma;
    _tone = ColorUtils.lstarFromArgb(argb);
  }

  @override
  String toString() =>
      "HCT("
      "${_hue.round()}, "
      "${_chroma.round()}, "
      "${_tone.round()}"
      ")";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is Hct &&
          _argb == other._argb &&
          _hue == other._hue &&
          _chroma == other._chroma &&
          _tone == other._tone;

  @override
  int get hashCode => Object.hash(_argb, _hue, _chroma, _tone);

  static bool isBlue(double hue) => hue >= 250.0 && hue < 270.0;

  static bool isYellow(double hue) => hue >= 105.0 && hue < 125.0;

  static bool isCyan(double hue) => hue >= 170.0 && hue < 207.0;
}
