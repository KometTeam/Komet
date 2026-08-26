import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FpsOverlayLayer extends StatefulWidget {
  const FpsOverlayLayer({super.key});

  @override
  State<FpsOverlayLayer> createState() => _FpsOverlayLayerState();
}

class _FrameSample {
  const _FrameSample({
    required this.endMicros,
    required this.costMicros,
    required this.rasterBound,
  });

  final int endMicros;
  final int costMicros;
  final bool rasterBound;
}

class _FpsOverlayLayerState extends State<FpsOverlayLayer> {
  static const int _fpsWindowMicros = 1000000;
  static const int _jankWindowMicros = 3000000;
  static const int _minUiRefreshMs = 100;
  static const double _initialWidthGuess = 132;
  static const double _initialHeightGuess = 36;

  final List<_FrameSample> _recent = <_FrameSample>[];
  final List<_FrameSample> _janky = <_FrameSample>[];
  final GlobalKey _badgeKey = GlobalKey();
  double _refreshRate = 60;
  double _budgetMicros = 1000000 / 60;
  double _fps = 0;
  int _worstMicros = 0;
  int _jankCount = 0;
  bool _worstRasterBound = false;
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  double? _left;
  double? _top;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshRate = _resolveRefreshRate();
    _budgetMicros = 1000000 / _refreshRate;
    if (_left != null && _top != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(_clampPositionToScreen);
        }
      });
    }
  }

  double _resolveRefreshRate() {
    final hz = View.of(context).display.refreshRate;
    return hz.isFinite && hz >= 30 ? hz : 60;
  }

  void _ensureInitialPosition() {
    if (_left != null) return;
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    _left = w - _initialWidthGuess - 8;
    _top = mq.padding.top + 8;
  }

  void _clampPositionToScreen() {
    if (_left == null || _top == null) return;
    final mq = MediaQuery.of(context);
    final screen = mq.size;
    final topMin = mq.padding.top;
    final bottomMax = screen.height - mq.padding.bottom;

    final box = _badgeKey.currentContext?.findRenderObject() as RenderBox?;
    final bw = box?.hasSize == true ? box!.size.width : _initialWidthGuess;
    final bh = box?.hasSize == true ? box!.size.height : _initialHeightGuess;

    _left = _left!.clamp(0.0, math.max(0.0, screen.width - bw));
    _top = _top!.clamp(topMin, math.max(topMin, bottomMax - bh));
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final build = t.buildDuration.inMicroseconds;
      final raster = t.rasterDuration.inMicroseconds;
      final sample = _FrameSample(
        endMicros: t.timestampInMicroseconds(ui.FramePhase.rasterFinish),
        costMicros: build > raster ? build : raster,
        rasterBound: raster >= build,
      );
      _recent.add(sample);
      if (sample.costMicros > _budgetMicros) _janky.add(sample);
    }
    if (_recent.isEmpty) return;

    final newest = _recent.last.endMicros;
    _recent.removeWhere((s) => newest - s.endMicros > _fpsWindowMicros);
    _janky.removeWhere((s) => newest - s.endMicros > _jankWindowMicros);

    var sum = 0;
    for (final s in _recent) {
      sum += s.costMicros;
    }
    var worst = 0;
    var worstRasterBound = false;
    for (final s in _janky) {
      if (s.costMicros > worst) {
        worst = s.costMicros;
        worstRasterBound = s.rasterBound;
      }
    }

    final mean = sum / _recent.length;
    final fps = 1000000 / math.max(mean, _budgetMicros);

    final now = DateTime.now();
    if (now.difference(_lastUiUpdate).inMilliseconds < _minUiRefreshMs) return;
    _lastUiUpdate = now;
    if (!mounted) return;
    setState(() {
      _fps = fps;
      _worstMicros = worst;
      _jankCount = _janky.length;
      _worstRasterBound = worstRasterBound;
    });
  }

  Color get _tint {
    if (_jankCount == 0) return const Color(0xFFB8F5C6);
    if (_worstMicros > _budgetMicros * 3) return const Color(0xFFFFAB91);
    return const Color(0xFFFFE082);
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialPosition();
    _clampPositionToScreen();

    final tint = _tint;
    return Positioned(
      left: _left,
      top: _top,
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            setState(() {
              _left = _left! + details.delta.dx;
              _top = _top! + details.delta.dy;
              _clampPositionToScreen();
            });
          },
          child: Material(
            key: _badgeKey,
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xCC000000),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_fps.round()} FPS · ${_refreshRate.round()} Hz',
                    style: TextStyle(
                      color: tint,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (_jankCount > 0)
                    Text(
                      '${(_worstMicros / 1000).round()} ms ×$_jankCount '
                      '${_worstRasterBound ? 'gpu' : 'ui'}',
                      style: TextStyle(
                        color: tint,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
