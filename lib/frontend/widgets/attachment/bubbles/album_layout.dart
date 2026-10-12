import 'dart:math' as math;
import 'dart:ui' show Rect;

class AlbumGrid {
  final List<Rect> tiles;
  final double aspectRatio;

  const AlbumGrid({required this.tiles, required this.aspectRatio});
}

abstract final class AlbumLayout {
  static const int maxTiles = 10;

  static const double _width = 800;
  static const double _height = 814;
  static const double _targetHeight = _width / 3 * 4;
  static const double _minWidth = 233;
  static const double _sideColumnPadding = 78;
  static const double _minRowHeight = 195;
  static const double _minMiddleWidth = 113;
  static const double _minCroppedRatio = 2 / 3;
  static const double _maxCroppedRatio = 1.7;

  static AlbumGrid layout(List<double> aspectRatios) {
    final ratios = [
      for (final ratio in aspectRatios)
        ratio.isFinite && ratio > 0 ? ratio : 1.0,
    ];
    return _normalize(_place(ratios));
  }

  static List<Rect> _place(List<double> ratios) {
    final count = ratios.length;
    if (count == 0) return const [];
    if (count == 1) {
      return [Rect.fromLTWH(0, 0, _width, _width / ratios.single)];
    }
    final hasPanorama = ratios.any((ratio) => ratio > 2);
    if (!hasPanorama) {
      final shape = ratios.map(_orientation).join();
      switch (count) {
        case 2:
          return _placeTwo(ratios, shape);
        case 3:
          return _placeThree(ratios, shape);
        case 4:
          return _placeFour(ratios, shape);
      }
    }
    return _placeRows(ratios);
  }

  static String _orientation(double ratio) {
    if (ratio > 1.2) return 'w';
    if (ratio < 0.8) return 'n';
    return 'q';
  }

  static double _average(List<double> ratios) =>
      ratios.reduce((a, b) => a + b) / ratios.length;

  static List<Rect> _placeTwo(List<double> r, String shape) {
    final stacked =
        shape == 'ww' &&
        _average(r) > 1.4 * (_width / _height) &&
        r[0] - r[1] < 0.2;
    if (stacked) {
      final height = [
        _width / r[0],
        _width / r[1],
        _height / 2,
      ].reduce(math.min);
      return [
        Rect.fromLTWH(0, 0, _width, height),
        Rect.fromLTWH(0, height, _width, height),
      ];
    }
    if (shape == 'ww' || shape == 'qq') {
      const width = _width / 2;
      final height = [width / r[0], width / r[1], _height].reduce(math.min);
      return [
        Rect.fromLTWH(0, 0, width, height),
        Rect.fromLTWH(width, 0, width, height),
      ];
    }
    var second = math.max(0.4 * _width, _width / r[0] / (1 / r[0] + 1 / r[1]));
    var first = _width - second;
    if (first < _minWidth) {
      second -= _minWidth - first;
      first = _minWidth;
    }
    final height = math.min(_height, math.min(first / r[0], second / r[1]));
    return [
      Rect.fromLTWH(0, 0, first, height),
      Rect.fromLTWH(first, 0, second, height),
    ];
  }

  static List<Rect> _placeThree(List<double> r, String shape) {
    if (shape[0] == 'n') {
      final thirdHeight = math.min(_height / 2, r[1] * _width / (r[2] + r[1]));
      final secondHeight = _height - thirdHeight;
      final rightWidth = math.max(
        _minWidth,
        math.min(_width / 2, math.min(thirdHeight * r[2], secondHeight * r[1])),
      );
      final leftWidth = math.min(
        _height * r[0] + _sideColumnPadding,
        _width - rightWidth,
      );
      return [
        Rect.fromLTWH(0, 0, leftWidth, _height),
        Rect.fromLTWH(leftWidth, 0, rightWidth, secondHeight),
        Rect.fromLTWH(leftWidth, secondHeight, rightWidth, thirdHeight),
      ];
    }
    final firstHeight = math.min(_width / r[0], _height * 0.66);
    const halfWidth = _width / 2;
    final secondHeight = math.max(
      _minRowHeight,
      math.min(
        _height - firstHeight,
        math.min(halfWidth / r[1], halfWidth / r[2]),
      ),
    );
    return [
      Rect.fromLTWH(0, 0, _width, firstHeight),
      Rect.fromLTWH(0, firstHeight, halfWidth, secondHeight),
      Rect.fromLTWH(halfWidth, firstHeight, halfWidth, secondHeight),
    ];
  }

  static List<Rect> _placeFour(List<double> r, String shape) {
    if (shape[0] == 'w') {
      final topHeight = math.min(_width / r[0], _height * 0.66);
      final rowHeight = _width / (r[1] + r[2] + r[3]);
      var left = math.max(_minWidth, math.min(_width * 0.4, rowHeight * r[1]));
      var right = math.max(
        math.max(_minWidth, _width * 0.33),
        rowHeight * r[3],
      );
      var middle = _width - left - right;
      if (middle < _minMiddleWidth) {
        final deficit = _minMiddleWidth - middle;
        middle = _minMiddleWidth;
        left -= deficit / 2;
        right -= deficit / 2;
      }
      final bottomHeight = math.max(
        _minRowHeight,
        math.min(_height - topHeight, rowHeight),
      );
      return [
        Rect.fromLTWH(0, 0, _width, topHeight),
        Rect.fromLTWH(0, topHeight, left, bottomHeight),
        Rect.fromLTWH(left, topHeight, middle, bottomHeight),
        Rect.fromLTWH(left + middle, topHeight, right, bottomHeight),
      ];
    }
    final columnWidth = math.min(
      _height / (1 / r[1] + 1 / r[2] + 1 / r[3]),
      _height,
    );
    final maxCell = _height * 0.33;
    final first = math.min(maxCell, math.max(_minWidth, columnWidth / r[1]));
    final second = math.min(maxCell, math.max(_minWidth, columnWidth / r[2]));
    final third = _height - first - second;
    final leftWidth = math.min(
      _height * r[0] + _sideColumnPadding,
      _width - columnWidth,
    );
    return [
      Rect.fromLTWH(0, 0, leftWidth, _height),
      Rect.fromLTWH(leftWidth, 0, columnWidth, first),
      Rect.fromLTWH(leftWidth, first, columnWidth, second),
      Rect.fromLTWH(leftWidth, first + second, columnWidth, third),
    ];
  }

  static List<Rect> _placeRows(List<double> ratios) {
    final wide = _average(ratios) > 1.1;
    final cropped = [
      for (final ratio in ratios)
        (wide ? math.max(1.0, ratio) : math.min(1.0, ratio)).clamp(
          _minCroppedRatio,
          _maxCroppedRatio,
        ),
    ];
    final lines = rows(cropped, narrow: _average(ratios) < 0.85);

    final tiles = <Rect>[];
    var start = 0;
    var top = 0.0;
    for (final size in lines) {
      final end = start + size;
      final lineHeight = _lineHeight(cropped, start, end);
      final height = math.max(_minRowHeight, lineHeight);
      var left = 0.0;
      for (var i = start; i < end; i++) {
        final width = i == end - 1 ? _width - left : cropped[i] * lineHeight;
        tiles.add(Rect.fromLTWH(left, top, width, height));
        left += width;
      }
      top += height;
      start = end;
    }
    return tiles;
  }

  static List<int> rows(List<double> cropped, {bool narrow = false}) {
    final count = cropped.length;
    if (count < 2) return [count];

    List<int>? best;
    var bestScore = double.infinity;
    void consider(List<int> lines) {
      final score = _score(cropped, lines);
      if (score < bestScore) {
        bestScore = score;
        best = lines;
      }
    }

    for (var first = 1; first < count; first++) {
      final second = count - first;
      if (first > 3 || second > 3) continue;
      consider([first, second]);
    }
    for (var first = 1; first < count - 1; first++) {
      for (var second = 1; second < count - first; second++) {
        final third = count - first - second;
        if (first > 3 || second > (narrow ? 4 : 3) || third > 3) continue;
        consider([first, second, third]);
      }
    }
    for (var first = 1; first < count - 2; first++) {
      for (var second = 1; second < count - first - 1; second++) {
        for (var third = 1; third < count - first - second; third++) {
          final fourth = count - first - second - third;
          if (first > 3 || second > 3 || third > 3 || fourth > 3) continue;
          consider([first, second, third, fourth]);
        }
      }
    }
    return best ?? [count];
  }

  static double _score(List<double> cropped, List<int> lines) {
    var total = 0.0;
    var lowest = double.infinity;
    var start = 0;
    for (final size in lines) {
      final height = _lineHeight(cropped, start, start + size);
      total += height;
      lowest = math.min(lowest, height);
      start += size;
    }
    var score = (total - _targetHeight).abs();
    for (var i = 0; i + 1 < lines.length; i++) {
      if (lines[i] > lines[i + 1]) {
        score *= 1.2;
        break;
      }
    }
    if (lowest < _minWidth) score *= 1.5;
    return score;
  }

  static double _lineHeight(List<double> cropped, int start, int end) {
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      sum += cropped[i];
    }
    return _width / sum;
  }

  static AlbumGrid _normalize(List<Rect> tiles) {
    if (tiles.isEmpty) return const AlbumGrid(tiles: [], aspectRatio: 1);
    final width = tiles.map((tile) => tile.right).reduce(math.max);
    final height = tiles.map((tile) => tile.bottom).reduce(math.max);
    return AlbumGrid(
      tiles: [
        for (final tile in tiles)
          Rect.fromLTRB(
            tile.left / width,
            tile.top / height,
            tile.right / width,
            tile.bottom / height,
          ),
      ],
      aspectRatio: width / height,
    );
  }
}
