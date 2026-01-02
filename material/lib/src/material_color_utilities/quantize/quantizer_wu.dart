import '../utils/color_utils.dart';

import 'quantizer.dart';
import 'quantizer_map.dart';
import 'quantizer_result.dart';

const int _indexBits = 5;
const int _indexCount = ((1 << _indexBits) + 1);
const int _totalSize = _indexCount * _indexCount * _indexCount;

// const int _indexBits = 5;
// const int _indexCount = 33; // ((1 << _indexBits) + 1)
// const int _totalSize = 35937; // _indexCount * _indexCount * _indexCount

final class QuantizerWu implements Quantizer {
  late List<int> _weights;
  late List<int> _momentsR;
  late List<int> _momentsG;
  late List<int> _momentsB;
  late List<double> _moments;
  late List<_Box> _cubes;

  @override
  QuantizerResult quantize(List<int> pixels, int maxColors) {
    final mapResult = const QuantizerMap().quantize(pixels, maxColors);
    _constructHistogram(mapResult.colorToCount);
    _createMoments();
    final createBoxesResult = _createBoxes(maxColors);
    final colors = _createResult(createBoxesResult.resultCount);
    final resultMap = <int, int>{};
    for (final color in colors) {
      resultMap[color] = 0;
    }
    return QuantizerResult(colorToCount: resultMap);
  }

  void _constructHistogram(Map<int, int> pixels) {
    _weights = List.filled(_totalSize, 0);
    _momentsR = List.filled(_totalSize, 0);
    _momentsG = List.filled(_totalSize, 0);
    _momentsB = List.filled(_totalSize, 0);
    _moments = List.filled(_totalSize, 0.0);

    for (final MapEntry(key: pixel, value: count) in pixels.entries) {
      final red = ColorUtils.redFromArgb(pixel);
      final green = ColorUtils.greenFromArgb(pixel);
      final blue = ColorUtils.blueFromArgb(pixel);
      final bitsToRemove = 8 - _indexBits;
      final iR = (red >> bitsToRemove) + 1;
      final iG = (green >> bitsToRemove) + 1;
      final iB = (blue >> bitsToRemove) + 1;
      final index = _getIndex(iR, iG, iB);
      _weights[index] += count;
      _momentsR[index] += (red * count);
      _momentsG[index] += (green * count);
      _momentsB[index] += (blue * count);
      _moments[index] +=
          (count * ((red * red) + (green * green) + (blue * blue)));
    }
  }

  void _createMoments() {
    for (var r = 1; r < _indexCount; ++r) {
      final List<int> area = List.filled(_indexCount, 0);
      final List<int> areaR = List.filled(_indexCount, 0);
      final List<int> areaG = List.filled(_indexCount, 0);
      final List<int> areaB = List.filled(_indexCount, 0);
      final List<double> area2 = List.filled(_indexCount, 0.0);

      for (var g = 1; g < _indexCount; ++g) {
        var line = 0;
        var lineR = 0;
        var lineG = 0;
        var lineB = 0;
        var line2 = 0.0;
        for (var b = 1; b < _indexCount; ++b) {
          final index = _getIndex(r, g, b);
          line += _weights[index];
          lineR += _momentsR[index];
          lineG += _momentsG[index];
          lineB += _momentsB[index];
          line2 += _moments[index];

          area[b] += line;
          areaR[b] += lineR;
          areaG[b] += lineG;
          areaB[b] += lineB;
          area2[b] += line2;

          final previousIndex = _getIndex(r - 1, g, b);
          _weights[index] = _weights[previousIndex] + area[b];
          _momentsR[index] = _momentsR[previousIndex] + areaR[b];
          _momentsG[index] = _momentsG[previousIndex] + areaG[b];
          _momentsB[index] = _momentsB[previousIndex] + areaB[b];
          _moments[index] = _moments[previousIndex] + area2[b];
        }
      }
    }
  }

  _CreateBoxesResult _createBoxes(int maxColorCount) {
    _cubes = List.generate(maxColorCount, (_) => _Box());
    final List<double> volumeVariance = List.filled(maxColorCount, 0.0);
    _cubes.first
      ..r1 = _indexCount - 1
      ..g1 = _indexCount - 1
      ..b1 = _indexCount - 1;

    var generatedColorCount = maxColorCount;
    var next = 0;
    for (var i = 1; i < maxColorCount; i++) {
      if (_cut(_cubes[next], _cubes[i])) {
        volumeVariance[next] = (_cubes[next].vol > 1)
            ? _variance(_cubes[next])
            : 0.0;
        volumeVariance[i] = (_cubes[i].vol > 1) ? _variance(_cubes[i]) : 0.0;
      } else {
        volumeVariance[next] = 0.0;
        i--;
      }

      next = 0;

      var temp = volumeVariance[0];
      for (var j = 1; j <= i; j++) {
        if (volumeVariance[j] > temp) {
          temp = volumeVariance[j];
          next = j;
        }
      }
      if (temp <= 0.0) {
        generatedColorCount = i + 1;
        break;
      }
    }
    return _CreateBoxesResult(maxColorCount, generatedColorCount);
  }

  List<int> _createResult(int colorCount) {
    final colors = <int>[];
    for (var i = 0; i < colorCount; ++i) {
      final cube = _cubes[i];
      final weight = _volume(cube, _weights);
      if (weight > 0) {
        final r = _volume(cube, _momentsR) ~/ weight;
        final g = _volume(cube, _momentsG) ~/ weight;
        final b = _volume(cube, _momentsB) ~/ weight;
        final color =
            (255 << 24) | ((r & 255) << 16) | ((g & 255) << 8) | (b & 255);
        colors.add(color);
      }
    }
    return colors;
  }

  double _variance(_Box cube) {
    final dr = _volume(cube, _momentsR);
    final dg = _volume(cube, _momentsG);
    final db = _volume(cube, _momentsB);
    final xx =
        _moments[_getIndex(cube.r1, cube.g1, cube.b1)] -
        _moments[_getIndex(cube.r1, cube.g1, cube.b0)] -
        _moments[_getIndex(cube.r1, cube.g0, cube.b1)] +
        _moments[_getIndex(cube.r1, cube.g0, cube.b0)] -
        _moments[_getIndex(cube.r0, cube.g1, cube.b1)] +
        _moments[_getIndex(cube.r0, cube.g1, cube.b0)] +
        _moments[_getIndex(cube.r0, cube.g0, cube.b1)] -
        _moments[_getIndex(cube.r0, cube.g0, cube.b0)];
    final hypotenuse = dr * dr + dg * dg + db * db;
    final volume = _volume(cube, _weights);
    return xx - hypotenuse / volume.toDouble();
  }

  bool _cut(_Box one, _Box two) {
    final wholeR = _volume(one, _momentsR);
    final wholeG = _volume(one, _momentsG);
    final wholeB = _volume(one, _momentsB);
    final wholeW = _volume(one, _weights);

    final maxRResult = _maximize(
      one,
      .red,
      one.r0 + 1,
      one.r1,
      wholeR,
      wholeG,
      wholeB,
      wholeW,
    );
    final maxGResult = _maximize(
      one,
      .green,
      one.g0 + 1,
      one.g1,
      wholeR,
      wholeG,
      wholeB,
      wholeW,
    );
    final maxBResult = _maximize(
      one,
      .blue,
      one.b0 + 1,
      one.b1,
      wholeR,
      wholeG,
      wholeB,
      wholeW,
    );
    final _Direction cutDirection;
    final maxR = maxRResult.maximum;
    final maxG = maxGResult.maximum;
    final maxB = maxBResult.maximum;
    if (maxR >= maxG && maxR >= maxB) {
      if (maxRResult.cutLocation < 0) {
        return false;
      }
      cutDirection = .red;
    } else if (maxG >= maxR && maxG >= maxB) {
      cutDirection = .green;
    } else {
      cutDirection = .blue;
    }

    two
      ..r1 = one.r1
      ..g1 = one.g1
      ..b1 = one.b1;

    switch (cutDirection) {
      case .red:
        one.r1 = maxRResult.cutLocation;
        two.r0 = one.r1;
        two.g0 = one.g0;
        two.b0 = one.b0;
        break;
      case .green:
        one.g1 = maxGResult.cutLocation;
        two.r0 = one.r0;
        two.g0 = one.g1;
        two.b0 = one.b0;
        break;
      case .blue:
        one.b1 = maxBResult.cutLocation;
        two.r0 = one.r0;
        two.g0 = one.g0;
        two.b0 = one.b1;
        break;
    }

    one.vol = (one.r1 - one.r0) * (one.g1 - one.g0) * (one.b1 - one.b0);
    two.vol = (two.r1 - two.r0) * (two.g1 - two.g0) * (two.b1 - two.b0);

    return true;
  }

  _MaximizeResult _maximize(
    _Box cube,
    _Direction direction,
    int first,
    int last,
    int wholeR,
    int wholeG,
    int wholeB,
    int wholeW,
  ) {
    final bottomR = _bottom(cube, direction, _momentsR);
    final bottomG = _bottom(cube, direction, _momentsG);
    final bottomB = _bottom(cube, direction, _momentsB);
    final bottomW = _bottom(cube, direction, _weights);

    var max = 0.0;
    var cut = -1;

    var halfR = 0;
    var halfG = 0;
    var halfB = 0;
    var halfW = 0;
    for (var i = first; i < last; i++) {
      halfR = bottomR + _top(cube, direction, i, _momentsR);
      halfG = bottomG + _top(cube, direction, i, _momentsG);
      halfB = bottomB + _top(cube, direction, i, _momentsB);
      halfW = bottomW + _top(cube, direction, i, _weights);
      if (halfW == 0) {
        continue;
      }

      var tempNumerator = (halfR * halfR + halfG * halfG + halfB * halfB)
          .toDouble();
      var tempDenominator = halfW.toDouble();
      var temp = tempNumerator / tempDenominator;

      halfR = wholeR - halfR;
      halfG = wholeG - halfG;
      halfB = wholeB - halfB;
      halfW = wholeW - halfW;
      if (halfW == 0) {
        continue;
      }

      tempNumerator = (halfR * halfR + halfG * halfG + halfB * halfB)
          .toDouble();
      tempDenominator = halfW.toDouble();
      temp += (tempNumerator / tempDenominator);

      if (temp > max) {
        max = temp;
        cut = i;
      }
    }
    return _MaximizeResult(cut, max);
  }

  static int _getIndex(int r, int g, int b) =>
      (r << (_indexBits * 2)) +
      (r << (_indexBits + 1)) +
      r +
      (g << _indexBits) +
      g +
      b;

  static int _volume(_Box cube, List<int> moment) =>
      (moment[_getIndex(cube.r1, cube.g1, cube.b1)] -
      moment[_getIndex(cube.r1, cube.g1, cube.b0)] -
      moment[_getIndex(cube.r1, cube.g0, cube.b1)] +
      moment[_getIndex(cube.r1, cube.g0, cube.b0)] -
      moment[_getIndex(cube.r0, cube.g1, cube.b1)] +
      moment[_getIndex(cube.r0, cube.g1, cube.b0)] +
      moment[_getIndex(cube.r0, cube.g0, cube.b1)] -
      moment[_getIndex(cube.r0, cube.g0, cube.b0)]);

  static int _bottom(_Box cube, _Direction direction, List<int> moment) =>
      switch (direction) {
        .red =>
          -moment[_getIndex(cube.r0, cube.g1, cube.b1)] +
              moment[_getIndex(cube.r0, cube.g1, cube.b0)] +
              moment[_getIndex(cube.r0, cube.g0, cube.b1)] -
              moment[_getIndex(cube.r0, cube.g0, cube.b0)],
        .green =>
          -moment[_getIndex(cube.r1, cube.g0, cube.b1)] +
              moment[_getIndex(cube.r1, cube.g0, cube.b0)] +
              moment[_getIndex(cube.r0, cube.g0, cube.b1)] -
              moment[_getIndex(cube.r0, cube.g0, cube.b0)],
        .blue =>
          -moment[_getIndex(cube.r1, cube.g1, cube.b0)] +
              moment[_getIndex(cube.r1, cube.g0, cube.b0)] +
              moment[_getIndex(cube.r0, cube.g1, cube.b0)] -
              moment[_getIndex(cube.r0, cube.g0, cube.b0)],
      };

  static int _top(
    _Box cube,
    _Direction direction,
    int position,
    List<int> moment,
  ) => switch (direction) {
    .red =>
      (moment[_getIndex(position, cube.g1, cube.b1)] -
          moment[_getIndex(position, cube.g1, cube.b0)] -
          moment[_getIndex(position, cube.g0, cube.b1)] +
          moment[_getIndex(position, cube.g0, cube.b0)]),
    .green =>
      (moment[_getIndex(cube.r1, position, cube.b1)] -
          moment[_getIndex(cube.r1, position, cube.b0)] -
          moment[_getIndex(cube.r0, position, cube.b1)] +
          moment[_getIndex(cube.r0, position, cube.b0)]),
    .blue =>
      (moment[_getIndex(cube.r1, cube.g1, position)] -
          moment[_getIndex(cube.r1, cube.g0, position)] -
          moment[_getIndex(cube.r0, cube.g1, position)] +
          moment[_getIndex(cube.r0, cube.g0, position)]),
  };
}

enum _Direction { red, green, blue }

final class _MaximizeResult {
  const _MaximizeResult(int cut, double max) : cutLocation = cut, maximum = max;

  // < 0 if cut impossible
  final int cutLocation;
  final double maximum;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is _MaximizeResult &&
          cutLocation == other.cutLocation &&
          maximum == other.maximum;

  @override
  int get hashCode => Object.hash(cutLocation, maximum);
}

final class _CreateBoxesResult {
  const _CreateBoxesResult(this.requestedCount, this.resultCount);

  final int requestedCount;
  final int resultCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      runtimeType == other.runtimeType &&
          other is _CreateBoxesResult &&
          requestedCount == other.requestedCount &&
          resultCount == other.resultCount;

  @override
  int get hashCode => Object.hash(requestedCount, resultCount);
}

final class _Box {
  _Box();

  int r0 = 0;
  int r1 = 0;
  int g0 = 0;
  int g1 = 0;
  int b0 = 0;
  int b1 = 0;
  int vol = 0;
}
