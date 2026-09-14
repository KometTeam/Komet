abstract final class AlbumLayout {
  static const int maxTiles = 10;
  static const double _targetRowHeight = 0.4;

  static List<int> rows(List<double> ratios) {
    final count = ratios.length;
    if (count <= 3) return [count];

    final cost = List<double>.filled(count + 1, double.infinity);
    final lastRow = List<int>.filled(count + 1, 0);
    cost[0] = 0;
    for (var end = 2; end <= count; end++) {
      for (final size in const [3, 2]) {
        final start = end - size;
        if (start < 0 || cost[start] == double.infinity) continue;
        var sum = 0.0;
        for (var i = start; i < end; i++) {
          sum += ratios[i];
        }
        final deviation = 1 / sum - _targetRowHeight;
        final total = cost[start] + deviation * deviation;
        if (total < cost[end]) {
          cost[end] = total;
          lastRow[end] = size;
        }
      }
    }

    final result = <int>[];
    for (var end = count; end > 0; end -= lastRow[end]) {
      result.add(lastRow[end]);
    }
    return result.reversed.toList();
  }
}
