import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class FpsOverlayLayer extends StatefulWidget {
  const FpsOverlayLayer({super.key});

  @override
  State<FpsOverlayLayer> createState() => _FpsOverlayLayerState();
}

class _FpsOverlayLayerState extends State<FpsOverlayLayer> {
  static const int _maxSamples = 90;
  static const int _minUiRefreshMs = 160;
  static const double _initialWidthGuess = 96;
  static const double _initialHeightGuess = 36;

  final List<int> _frameMicros = <int>[];
  final GlobalKey _badgeKey = GlobalKey();
  double _fps = 0;
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
    if (_left != null && _top != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(_clampPositionToScreen);
        }
      });
    }
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
    final bw = box?.hasSize == true
        ? box!.size.width
        : _initialWidthGuess;
    final bh = box?.hasSize == true
        ? box!.size.height
        : _initialHeightGuess;

    _left = _left!.clamp(0.0, math.max(0.0, screen.width - bw));
    _top = _top!.clamp(topMin, math.max(topMin, bottomMax - bh));
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final us = t.totalSpan.inMicroseconds;
      if (us <= 0) continue;
      _frameMicros.add(us);
      while (_frameMicros.length > _maxSamples) {
        _frameMicros.removeAt(0);
      }
    }
    final now = DateTime.now();
    if (now.difference(_lastUiUpdate).inMilliseconds < _minUiRefreshMs) {
      return;
    }
    _lastUiUpdate = now;
    if (!mounted || _frameMicros.isEmpty) return;
    final sum = _frameMicros.fold<int>(0, (a, b) => a + b);
    final avg = sum / _frameMicros.length;
    final fps = avg > 0 ? (1000000.0 / avg).clamp(0.0, 999.0) : 0.0;
    setState(() => _fps = fps);
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialPosition();
    _clampPositionToScreen();

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
              child: Text(
                '${_fps.round()} FPS',
                style: TextStyle(
                  color: _fps >= 55
                      ? const Color(0xFFB8F5C6)
                      : _fps >= 30
                      ? const Color(0xFFFFE082)
                      : const Color(0xFFFFAB91),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
