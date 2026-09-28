import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/debug/performance_monitor.dart';

void main() {
  test('reports tail latency instead of hiding it in an average', () {
    final values = List<double>.filled(98, 4).toList()..addAll([40, 120]);
    final stats = FrameTimeDistribution.fromValues(values.reversed);
    expect(stats.p50, 4);
    expect(stats.p95, 4);
    expect(stats.p99, 40);
    expect(stats.maximum, 120);
    expect(stats.over8Ms, 2);
    expect(stats.over16Ms, 2);
    expect(stats.over33Ms, 2);
  });

  test('uses separate frame-time thresholds', () {
    final stats = FrameTimeDistribution.fromValues([4, 9, 17, 34]);
    expect(stats.over8Ms, 3);
    expect(stats.over16Ms, 2);
    expect(stats.over33Ms, 1);
  });

  test('empty and single-frame captures are valid', () {
    final empty = FrameTimeDistribution.fromValues([]);
    expect(empty.maximum, 0);
    expect(empty.p99, 0);
    final single = FrameTimeDistribution.fromValues([12]);
    expect(single.p50, 12);
    expect(single.p95, 12);
    expect(single.p99, 12);
  });
}
