import '../hct/hct.dart';

/// A convenience class for retrieving colors that are
/// in hue and chroma, but vary in tone.
///
/// TonalPalette is intended for use in a single thread due to
/// its stateful caching.
final class TonalPalette {
  TonalPalette._(this.hue, this.chroma, this.keyColor);

  TonalPalette.fromInt(int argb) : this.fromHct(Hct.fromInt(argb));

  TonalPalette.fromHct(Hct hct) : this._(hct.hue, hct.chroma, hct);

  TonalPalette.fromHueAndChroma(double hue, double chroma)
    : this._(hue, chroma, _KeyColor(hue, chroma).create());

  final Map<int, int> _cache = <int, int>{};
  final double hue;
  final double chroma;
  final Hct keyColor;

  /// Create an ARGB color with HCT hue and chroma of this Tones instance,
  /// and the provided HCT tone.
  int tone(int tone) => _cache.putIfAbsent(
    tone,
    () => tone == 99 && Hct.isYellow(hue)
        ? _averageArgb(this.tone(98), this.tone(100))
        : Hct.from(hue, chroma, tone.toDouble()).toInt(),
  );

  /// Given a tone, use hue and chroma of palette to create a color,
  /// and return it as HCT.
  Hct getHct(double tone) => Hct.from(hue, chroma, tone);

  static int _averageArgb(int argb1, int argb2) {
    final red1 = (argb1 >>> 16) & 0xff;
    final green1 = (argb1 >>> 8) & 0xff;
    final blue1 = argb1 & 0xff;
    final red2 = (argb2 >>> 16) & 0xff;
    final green2 = (argb2 >>> 8) & 0xff;
    final blue2 = argb2 & 0xff;
    final red = ((red1 + red2) / 2.0).round();
    final green = ((green1 + green2) / 2.0).round();
    final blue = ((blue1 + blue2) / 2.0).round();
    return (255 << 24 |
            (red & 255) << 16 |
            (green & 255) << 8 |
            (blue & 255)) >>>
        0;
  }
}

/// Key color is a color that represents the hue and chroma of a tonal palette.
final class _KeyColor {
  _KeyColor(double hue, double requestedChroma)
    : _hue = hue,
      _requestedChroma = requestedChroma;

  final double _hue;
  final double _requestedChroma;

  /// Cache that maps tone to max chroma to avoid duplicated HCT calculation.
  final Map<int, double> _chromaCache = <int, double>{};

  /// Creates a key color from a [hue] and a [chroma].
  /// The key color is the first tone, starting from T50,
  /// matching the given hue and chroma.
  ///
  /// Returns key color [Hct].
  Hct create() {
    // Pivot around T50 because T50 has the most chroma available, on
    // average. Thus it is most likely to have a direct answer.
    const pivotTone = 50;
    const toneStepSize = 1;

    // Epsilon to accept values slightly higher than the requested chroma.
    const epsilon = 0.01;

    // Binary search to find the tone that can provide a chroma that is closest
    // to the requested chroma.
    var lowerTone = 0;
    var upperTone = 100;
    while (lowerTone < upperTone) {
      final midTone = (lowerTone + upperTone) ~/ 2;
      final isAscending =
          _maxChroma(midTone) < _maxChroma(midTone + toneStepSize);
      final sufficientChroma =
          _maxChroma(midTone) >= _requestedChroma - epsilon;

      if (sufficientChroma) {
        // Either range [lowerTone, midTone] or [midTone, upperTone] has
        // the answer, so search in the range that is closer the pivot tone.
        if ((lowerTone - pivotTone).abs() < (upperTone - pivotTone).abs()) {
          upperTone = midTone;
        } else {
          if (lowerTone == midTone) {
            return Hct.from(_hue, _requestedChroma, lowerTone.toDouble());
          }
          lowerTone = midTone;
        }
      } else {
        // As there is no sufficient chroma in the midTone, follow the direction to the chroma
        // peak.
        if (isAscending) {
          lowerTone = midTone + toneStepSize;
        } else {
          // Keep midTone for potential chroma peak.
          upperTone = midTone;
        }
      }
    }
    return Hct.from(_hue, _requestedChroma, lowerTone.toDouble());
  }

  /// Find the maximum chroma for a given tone.
  double _maxChroma(int tone) => _chromaCache.putIfAbsent(
    tone,
    () => Hct.from(_hue, _maxChromaValue, tone.toDouble()).chroma,
  );

  static const _maxChromaValue = 200.0;
}
