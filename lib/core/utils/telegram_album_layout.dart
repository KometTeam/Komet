import 'dart:math' as math;

class AlbumMediaSize {
  final double width;
  final double height;

  const AlbumMediaSize(this.width, this.height);

  double get ratio {
    if (width <= 0 || height <= 0) return 1;
    return (width / height).clamp(0.45, 2.4);
  }
}

class AlbumTile {
  final int index;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool leftEdge;
  final bool rightEdge;
  final bool topEdge;
  final bool bottomEdge;

  const AlbumTile({
    required this.index,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.leftEdge,
    required this.rightEdge,
    required this.topEdge,
    required this.bottomEdge,
  });
}

class AlbumLayout {
  final double width;
  final double height;
  final List<AlbumTile> tiles;

  const AlbumLayout({
    required this.width,
    required this.height,
    required this.tiles,
  });
}

const double kAlbumGap = 2;

AlbumLayout layoutTelegramAlbum(
  List<AlbumMediaSize> items, {
  required double maxWidth,
  double? maxHeight,
}) {
  if (items.isEmpty) {
    return const AlbumLayout(width: 0, height: 0, tiles: []);
  }

  final capH = maxHeight ?? maxWidth * 1.15;
  if (items.length == 1) {
    return _layoutSingle(items.first, maxWidth, capH);
  }

  final ratios = [for (final item in items) item.ratio];
  final props = StringBuffer();
  var avg = 0.0;
  var force = false;
  for (final ratio in ratios) {
    if (ratio > 1.2) {
      props.write('w');
    } else if (ratio < 0.8) {
      props.write('n');
    } else {
      props.write('q');
    }
    avg += ratio;
    if (ratio > 2.0) force = true;
  }
  avg /= ratios.length;
  final pattern = props.toString();

  if (!force) {
    if (items.length == 2) {
      return _layoutTwo(ratios, pattern, avg, maxWidth, capH);
    }
    if (items.length == 3) {
      return _layoutThree(ratios, pattern, maxWidth, capH);
    }
    if (items.length == 4) {
      return _layoutFour(ratios, pattern, maxWidth, capH);
    }
  }
  return _layoutMulti(ratios, maxWidth, capH);
}

AlbumLayout _layoutSingle(AlbumMediaSize item, double maxW, double maxH) {
  var w = item.width;
  var h = item.height;
  if (w <= 0 || h <= 0) {
    w = maxW * 0.75;
    h = maxW * 0.75;
  }
  final down = math.min(1.0, math.min(maxW / w, maxH / h));
  w *= down;
  h *= down;
  return AlbumLayout(
    width: w,
    height: h,
    tiles: [
      AlbumTile(
        index: 0,
        left: 0,
        top: 0,
        width: w,
        height: h,
        leftEdge: true,
        rightEdge: true,
        topEdge: true,
        bottomEdge: true,
      ),
    ],
  );
}

AlbumLayout _layoutTwo(
  List<double> ratios,
  String pattern,
  double avg,
  double maxW,
  double maxH,
) {
  if (pattern == 'ww' &&
      avg > 1.4 * 1.4 &&
      (ratios[0] - ratios[1]).abs() < 0.2) {
    final h0 = math.min(maxW / ratios[0], maxH / 2);
    final h1 = math.min(maxW / ratios[1], maxH / 2);
    return _fromRects(maxW, [
      _Rect(0, 0, maxW, h0),
      _Rect(0, h0 + kAlbumGap, maxW, h1),
    ]);
  }

  final height = math.min(
    (maxW - kAlbumGap) / (ratios[0] + ratios[1]),
    maxH,
  );
  final w0 = height * ratios[0];
  final w1 = maxW - w0 - kAlbumGap;
  return _fromRects(maxW, [
    _Rect(0, 0, w0, height),
    _Rect(w0 + kAlbumGap, 0, w1, height),
  ]);
}

AlbumLayout _layoutThree(
  List<double> ratios,
  String pattern,
  double maxW,
  double maxH,
) {
  if (pattern.startsWith('n')) {
    final rightW = math.min(maxW * 0.42, maxW / 2);
    final leftW = maxW - rightW - kAlbumGap;
    var leftH = leftW / ratios[0];
    var rightH = (rightW / ratios[1]) + kAlbumGap + (rightW / ratios[2]);
    final scale = math.min(1.0, maxH / math.max(leftH, rightH));
    leftH *= scale;
    final h1 = rightW / ratios[1] * scale;
    final h2 = leftH - h1 - kAlbumGap;
    return _fromRects(maxW, [
      _Rect(0, 0, leftW, leftH),
      _Rect(leftW + kAlbumGap, 0, rightW, h1),
      _Rect(leftW + kAlbumGap, h1 + kAlbumGap, rightW, h2),
    ]);
  }

  final topH = math.min(maxW / ratios[0], maxH * 0.62);
  final bottomH = math.min(
    (maxW - kAlbumGap) / (ratios[1] + ratios[2]),
    math.max(48, maxH - topH - kAlbumGap),
  );
  final w1 = bottomH * ratios[1];
  final w2 = maxW - w1 - kAlbumGap;
  return _fromRects(maxW, [
    _Rect(0, 0, maxW, topH),
    _Rect(0, topH + kAlbumGap, w1, bottomH),
    _Rect(w1 + kAlbumGap, topH + kAlbumGap, w2, bottomH),
  ]);
}

AlbumLayout _layoutFour(
  List<double> ratios,
  String pattern,
  double maxW,
  double maxH,
) {
  if (pattern.startsWith('n')) {
    final rightW = math.min(maxW * 0.38, maxW / 2.2);
    final leftW = maxW - rightW - kAlbumGap;
    var leftH = leftW / ratios[0];
    final rawRight =
        (rightW / ratios[1]) +
        (rightW / ratios[2]) +
        (rightW / ratios[3]) +
        kAlbumGap * 2;
    final scale = math.min(1.0, maxH / math.max(leftH, rawRight));
    leftH *= scale;
    final h1 = rightW / ratios[1] * scale;
    final h2 = rightW / ratios[2] * scale;
    final h3 = leftH - h1 - h2 - kAlbumGap * 2;
    return _fromRects(maxW, [
      _Rect(0, 0, leftW, leftH),
      _Rect(leftW + kAlbumGap, 0, rightW, h1),
      _Rect(leftW + kAlbumGap, h1 + kAlbumGap, rightW, h2),
      _Rect(leftW + kAlbumGap, h1 + h2 + kAlbumGap * 2, rightW, h3),
    ]);
  }

  if (pattern.startsWith('w')) {
    final topH = math.min(maxW / ratios[0], maxH * 0.5);
    final rest = ratios.sublist(1);
    final bottomH = math.min(
      (maxW - kAlbumGap * 2) / rest.fold(0.0, (a, b) => a + b),
      math.max(48, maxH - topH - kAlbumGap),
    );
    var x = 0.0;
    final rects = <_Rect>[_Rect(0, 0, maxW, topH)];
    for (var i = 0; i < rest.length; i++) {
      final isLast = i == rest.length - 1;
      final w = isLast ? maxW - x : bottomH * rest[i];
      rects.add(_Rect(x, topH + kAlbumGap, w, bottomH));
      x += w + kAlbumGap;
    }
    return _fromRects(maxW, rects);
  }

  final rowH = math.min((maxW - kAlbumGap) / 2, maxH / 2);
  return _fromRects(maxW, [
    _Rect(0, 0, (maxW - kAlbumGap) / 2, rowH),
    _Rect((maxW + kAlbumGap) / 2, 0, (maxW - kAlbumGap) / 2, rowH),
    _Rect(0, rowH + kAlbumGap, (maxW - kAlbumGap) / 2, rowH),
    _Rect(
      (maxW + kAlbumGap) / 2,
      rowH + kAlbumGap,
      (maxW - kAlbumGap) / 2,
      rowH,
    ),
  ]);
}

AlbumLayout _layoutMulti(List<double> ratios, double maxW, double maxH) {
  final n = ratios.length;
  final target = math.min(maxW / 0.8, maxH);
  _Attempt? best;

  void consider(List<int> counts) {
    final attempt = _attempt(ratios, counts, maxW);
    if (attempt == null) return;
    final score =
        (attempt.height - target).abs() + attempt.variance * 40;
    if (best == null || score < best!.score) {
      best = attempt..score = score;
    }
  }

  for (var lines = 2; lines <= math.min(4, n); lines++) {
    _walkCounts(n, lines, consider);
  }

  final chosen = best ?? _fallbackRows(ratios, maxW);
  return _fromRects(maxW, chosen.rects);
}

class _Attempt {
  final List<_Rect> rects;
  final double height;
  final double variance;
  double score;

  _Attempt(this.rects, this.height, this.variance, {this.score = 0});
}

void _walkCounts(int n, int lines, void Function(List<int> counts) emit) {
  final counts = List<int>.filled(lines, 1);
  var left = n - lines;

  void rec(int index) {
    if (index == lines - 1) {
      counts[index] = 1 + left;
      if (counts[index] <= 4) emit(List<int>.from(counts));
      return;
    }
    final maxTake = math.min(3, left);
    for (var extra = 0; extra <= maxTake; extra++) {
      counts[index] = 1 + extra;
      left -= extra;
      rec(index + 1);
      left += extra;
    }
  }

  rec(0);
}

_Attempt? _attempt(List<double> ratios, List<int> counts, double maxW) {
  final rects = <_Rect>[];
  var y = 0.0;
  var i = 0;
  final heights = <double>[];
  for (final count in counts) {
    final slice = ratios.sublist(i, i + count);
    final height = (maxW - kAlbumGap * (count - 1)) /
        slice.fold(0.0, (a, b) => a + b);
    if (height < 36 || height > 240) return null;
    heights.add(height);
    var x = 0.0;
    for (var c = 0; c < count; c++) {
      final isLast = c == count - 1;
      final w = isLast ? maxW - x : height * slice[c];
      rects.add(_Rect(x, y, w, height));
      x += w + kAlbumGap;
    }
    y += height + kAlbumGap;
    i += count;
  }
  final mean = heights.reduce((a, b) => a + b) / heights.length;
  var variance = 0.0;
  for (final h in heights) {
    variance += (h - mean) * (h - mean);
  }
  return _Attempt(rects, y - kAlbumGap, variance / heights.length);
}

_Attempt _fallbackRows(List<double> ratios, double maxW) {
  final counts = <int>[];
  var left = ratios.length;
  while (left > 0) {
    final take = left == 4 ? 2 : math.min(3, left);
    counts.add(take);
    left -= take;
  }
  return _attempt(ratios, counts, maxW) ??
      _Attempt([_Rect(0, 0, maxW, maxW)], maxW, 0);
}

class _Rect {
  final double left;
  final double top;
  final double width;
  final double height;

  const _Rect(this.left, this.top, this.width, this.height);

  double get right => left + width;
  double get bottom => top + height;
}

AlbumLayout _fromRects(double maxW, List<_Rect> raw) {
  var maxRight = 0.0;
  var maxBottom = 0.0;
  for (final rect in raw) {
    maxRight = math.max(maxRight, rect.right);
    maxBottom = math.max(maxBottom, rect.bottom);
  }
  final tiles = <AlbumTile>[
    for (var i = 0; i < raw.length; i++)
      AlbumTile(
        index: i,
        left: raw[i].left,
        top: raw[i].top,
        width: math.max(1, raw[i].width),
        height: math.max(1, raw[i].height),
        leftEdge: raw[i].left <= 0.6,
        rightEdge: raw[i].right >= maxRight - 0.6,
        topEdge: raw[i].top <= 0.6,
        bottomEdge: raw[i].bottom >= maxBottom - 0.6,
      ),
  ];
  return AlbumLayout(width: maxRight, height: maxBottom, tiles: tiles);
}
