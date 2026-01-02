import '../utils/math_utils.dart';
import '../hct/hct.dart';

/// Given a large set of colors, remove colors that are unsuitable for
/// a UI theme, and rank the rest based on suitability.
///
/// Enables use of a high cluster count for image quantization, thus ensuring
/// colors aren't muddied, while curating the high cluster count
/// to a much smaller number of appropriate choices.
abstract final class Score {
  static const double _targetChroma = 48.0; // A1 Chroma
  static const double _weightProportion = 0.7;
  static const double _weightChromaAbove = 0.3;
  static const double _weightChromaBelow = 0.1;
  static const double _cutoffChroma = 5.0;
  static const double _cutoffExcitedProportion = 0.01;

  static List<int> score(
    Map<int, int> colorsToPopulation, [
    int desired = 4,
    int fallbackColorArgb = 0xff4285f4,
    bool filter = true,
  ]) {
    // Get the HCT color for each Argb value, while finding the per hue count and
    // total count.
    final colorsHct = <Hct>[];
    final List<int> huePopulation = List.filled(360, 0);
    var populationSum = 0.0;
    for (final MapEntry(:key, :value) in colorsToPopulation.entries) {
      final hct = Hct.fromInt(key);
      colorsHct.add(hct);
      final hue = hct.hue.floor();
      huePopulation[hue] += value;
      populationSum += value.toDouble();
    }

    // Hues with more usage in neighboring 30 degree slice get a larger number.
    final List<double> hueExcitedProportions = List.filled(360, 0.0);
    for (var hue = 0; hue < 360; hue++) {
      final proportion = huePopulation[hue].toDouble() / populationSum;
      for (var i = hue - 14; i < hue + 16; i++) {
        final neighborHue = MathUtils.sanitizeDegreesInt(i);
        hueExcitedProportions[neighborHue] += proportion;
      }
    }

    // Scores each HCT color based on usage and chroma, while optionally
    // filtering out values that do not have enough chroma or usage.
    final scoredHcts = <_ScoredHct>[];
    for (final hct in colorsHct) {
      final hue = MathUtils.sanitizeDegreesInt(hct.hue.round());
      final proportion = hueExcitedProportions[hue];
      if (filter &&
          (hct.chroma < _cutoffChroma ||
              proportion <= _cutoffExcitedProportion)) {
        continue;
      }
      final proportionScore = proportion * 100.0 * _weightProportion;
      final chromaWeight = hct.chroma < _targetChroma
          ? _weightChromaBelow
          : _weightChromaAbove;
      final chromaScore = (hct.chroma - _targetChroma) * chromaWeight;
      final score = proportionScore + chromaScore;
      scoredHcts.add(_ScoredHct(hct, score));
    }

    // Sorted so that colors with higher scores come first.
    scoredHcts.sort((a, b) => b.score.compareTo(a.score));

    // Iterates through potential hue differences in degrees in order to select
    // the colors with the largest distribution of hues possible. Starting at
    // 90 degrees(maximum difference for 4 colors) then decreasing down to a
    // 15 degree minimum.
    final chosenColors = <Hct>[];
    for (
      var differenceDegrees = 90;
      differenceDegrees >= 15;
      differenceDegrees--
    ) {
      chosenColors.clear();
      for (final entry in scoredHcts) {
        final hct = entry.hct;
        var hasDuplicateHue = false;
        for (final chosenHct in chosenColors) {
          if (MathUtils.differenceDegrees(hct.hue, chosenHct.hue) <
              differenceDegrees) {
            hasDuplicateHue = true;
            break;
          }
        }
        if (!hasDuplicateHue) {
          chosenColors.add(hct);
        }
        if (chosenColors.length >= desired) {
          break;
        }
      }
      if (chosenColors.length >= desired) {
        break;
      }
    }
    final colors = <int>[];
    if (chosenColors.isEmpty) {
      colors.add(fallbackColorArgb);
    }
    for (final chosenHct in chosenColors) {
      colors.add(chosenHct.toInt());
    }
    return colors;
  }
}

final class _ScoredHct {
  const _ScoredHct(this.hct, this.score);

  final Hct hct;
  final double score;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is _ScoredHct &&
          hct == other.hct &&
          score == other.score;

  @override
  int get hashCode => Object.hash(hct, score);
}
