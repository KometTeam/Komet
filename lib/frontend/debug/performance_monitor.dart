import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

// #***! простое in-app APM — родной FrameTiming callback Flutter, без
// внешних зависимостей и без похода в DevTools. Копится в кольцевом
// буфере, чтобы можно было снять отчёт/скопировать лог из debug-меню.
//
// Помимо тайминга кадров копит "метки" (mark) — что происходило в
// приложении (роут, скролл, ресайз, генерация нагрузки) — чтобы в отчёте
// можно было увидеть НЕ ТОЛЬКО "кадр стоил 900мс", но и "что при этом
// делалось", не гадая по времени вручную.
class PerfSample {
  final DateTime time;
  final double buildMs;
  final double rasterMs;
  final double totalMs;
  final String context;

  const PerfSample(
    this.time,
    this.buildMs,
    this.rasterMs,
    this.totalMs,
    this.context,
  );
}

class PerfMark {
  final DateTime time;
  final String label;

  const PerfMark(this.time, this.label);
}

class FrameTimeDistribution {
  final double p50;
  final double p95;
  final double p99;
  final double maximum;
  final int over8Ms;
  final int over16Ms;
  final int over33Ms;

  const FrameTimeDistribution({
    this.p50 = 0,
    this.p95 = 0,
    this.p99 = 0,
    this.maximum = 0,
    this.over8Ms = 0,
    this.over16Ms = 0,
    this.over33Ms = 0,
  });

  factory FrameTimeDistribution.fromValues(Iterable<double> values) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return const FrameTimeDistribution();
    double percentile(double fraction) =>
        sorted[math.max(0, (sorted.length * fraction).ceil() - 1)];
    return FrameTimeDistribution(
      p50: percentile(0.50),
      p95: percentile(0.95),
      p99: percentile(0.99),
      maximum: sorted.last,
      over8Ms: sorted.where((value) => value > 1000 / 120).length,
      over16Ms: sorted.where((value) => value > 1000 / 60).length,
      over33Ms: sorted.where((value) => value > 1000 / 30).length,
    );
  }

  String get summary =>
      'p50=${p50.toStringAsFixed(2)}, p95=${p95.toStringAsFixed(2)}, '
      'p99=${p99.toStringAsFixed(2)}, max=${maximum.toStringAsFixed(2)} ms; '
      '>8.33ms=$over8Ms, >16.67ms=$over16Ms, >33.33ms=$over33Ms';
}

class PerfStats {
  final double avgMs;
  final double worstMs;
  final int sampleCount;
  final FrameTimeDistribution build;
  final FrameTimeDistribution raster;
  final FrameTimeDistribution total;

  const PerfStats({
    required this.avgMs,
    required this.worstMs,
    required this.sampleCount,
    this.build = const FrameTimeDistribution(),
    this.raster = const FrameTimeDistribution(),
    this.total = const FrameTimeDistribution(),
  });

  static const empty = PerfStats(avgMs: 0, worstMs: 0, sampleCount: 0);
}

class PerformanceMonitor {
  PerformanceMonitor._();
  static final instance = PerformanceMonitor._();

  static const int maxSamples = 4000;
  static const double jankThresholdMs = 16.67;
  static const double bigJankThresholdMs = 32.0;

  final Queue<PerfSample> _samples = Queue();
  final Queue<PerfMark> _marks = Queue();
  static const int maxMarks = 500;
  String _currentContext = 'idle';
  String _lastRouteContext = 'idle';
  bool _active = false;
  int _jankCount = 0;
  int _bigJankCount = 0;

  bool get isActive => _active;
  int get sampleCount => _samples.length;
  int get jankCount => _jankCount;
  int get bigJankCount => _bigJankCount;

  void start() {
    if (_active) return;
    _active = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void stop() {
    if (!_active) return;
    _active = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void clear() {
    _samples.clear();
    _marks.clear();
    _jankCount = 0;
    _bigJankCount = 0;
  }

  /// Записывает, что именно сейчас происходит в приложении (роут, скролл,
  /// ресайз, генерация нагрузки и т.д.) — не сам по себе кадр, а контекст,
  /// в котором последующие кадры снимаются. Дёшево, можно звать часто —
  /// ничего не делает, если мониторинг выключен.
  void mark(String label) {
    if (!_active) return;
    if (_currentContext == label) return;
    _currentContext = label;
    _marks.addLast(PerfMark(DateTime.now(), label));
    while (_marks.length > maxMarks) {
      _marks.removeFirst();
    }
  }

  /// Помечает переход экрана/роута — отдельно от [mark], потому что запоминает
  /// его как "контекст покоя", к которому нужно вернуться после того как
  /// временная активность (скролл/ресайз) закончится.
  void markRoute(String label) {
    _lastRouteContext = label;
    mark(label);
  }

  /// Помечает конец временной активности (скролл/ресайз) — возвращает
  /// контекст к последнему известному роуту.
  void markActivityEnd() {
    mark(_lastRouteContext);
  }

  void _onTimings(List<FrameTiming> timings) {
    final now = DateTime.now();
    for (final t in timings) {
      final buildMs = t.buildDuration.inMicroseconds / 1000;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000;
      final totalMs = t.totalSpan.inMicroseconds / 1000;
      _samples.addLast(
        PerfSample(now, buildMs, rasterMs, totalMs, _currentContext),
      );
      if (totalMs > jankThresholdMs) _jankCount++;
      if (totalMs > bigJankThresholdMs) _bigJankCount++;
    }
    while (_samples.length > maxSamples) {
      _samples.removeFirst();
    }
  }

  /// Топ контекстов по суммарному "джанковому" времени (>16.7мс сверх
  /// бюджета) — самый быстрый способ увидеть, что именно жрёт кадры.
  List<MapEntry<String, double>> worstContexts({int top = 8}) {
    final totals = <String, double>{};
    for (final s in _samples) {
      if (s.totalMs <= jankThresholdMs) continue;
      totals.update(
        s.context,
        (v) => v + (s.totalMs - jankThresholdMs),
        ifAbsent: () => s.totalMs - jankThresholdMs,
      );
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(top).toList();
  }

  PerfStats statsForLast(Duration window) {
    if (_samples.isEmpty) return PerfStats.empty;
    final cutoff = DateTime.now().subtract(window);
    final recent = [
      for (final s in _samples)
        if (s.time.isAfter(cutoff)) s,
    ];
    if (recent.isEmpty) return PerfStats.empty;
    var sum = 0.0;
    var worst = 0.0;
    for (final s in recent) {
      sum += s.totalMs;
      if (s.totalMs > worst) worst = s.totalMs;
    }
    final avg = sum / recent.length;
    return PerfStats(
      avgMs: avg,
      worstMs: worst,
      build: FrameTimeDistribution.fromValues(recent.map((s) => s.buildMs)),
      raster: FrameTimeDistribution.fromValues(recent.map((s) => s.rasterMs)),
      total: FrameTimeDistribution.fromValues(recent.map((s) => s.totalMs)),
      sampleCount: recent.length,
    );
  }

  /// Статистика за весь захваченный буфер (для отчёта стресс-теста).
  PerfStats statsAll() => statsForLast(const Duration(days: 1));

  String exportLog() {
    final buffer = StringBuffer();
    buffer.writeln('time,build_ms,raster_ms,total_ms,context');
    for (final s in _samples) {
      buffer.writeln(
        '${s.time.toIso8601String()},${s.buildMs.toStringAsFixed(2)},'
        '${s.rasterMs.toStringAsFixed(2)},${s.totalMs.toStringAsFixed(2)},'
        '${s.context}',
      );
    }
    final stats = statsAll();
    buffer.writeln('---');
    buffer.writeln(
      'samples: ${_samples.length}, avg: ${stats.avgMs.toStringAsFixed(2)}ms, '
      'worst: ${stats.worstMs.toStringAsFixed(2)}ms, '
      'jank(>${jankThresholdMs}ms): $_jankCount, '
      'big jank(>${bigJankThresholdMs}ms): $_bigJankCount',
    );
    buffer.writeln('buffer build: ${stats.build.summary}');
    buffer.writeln('buffer raster: ${stats.raster.summary}');
    buffer.writeln('buffer totalSpan: ${stats.total.summary}');
    buffer.writeln(
      'Threshold counts are timing samples, not measured display FPS.',
    );
    final worst = worstContexts();
    if (worst.isNotEmpty) {
      buffer.writeln('worst contexts by jank-time:');
      for (final e in worst) {
        buffer.writeln(
          '  ${e.key}: ${e.value.toStringAsFixed(1)}ms over budget',
        );
      }
    }
    if (_marks.isNotEmpty) {
      buffer.writeln('---marks---');
      for (final m in _marks) {
        buffer.writeln('${m.time.toIso8601String()},${m.label}');
      }
    }
    return buffer.toString();
  }
}

/// Помечает APM переходами между экранами — вешается в
/// MaterialApp.navigatorObservers рядом с уже существующими обсерверами.
class PerfRouteObserver extends NavigatorObserver {
  String _nameOf(Route<dynamic>? route) =>
      route?.settings.name ?? route?.runtimeType.toString() ?? 'unknown';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    PerformanceMonitor.instance.markRoute('route:${_nameOf(route)}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    PerformanceMonitor.instance.markRoute('route:${_nameOf(previousRoute)}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    PerformanceMonitor.instance.markRoute('route:${_nameOf(newRoute)}');
  }
}
