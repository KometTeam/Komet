import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// #***! анимированный mesh-градиент, портировано с нативного generateGradient
// Telegram (свёрл-дисторсия + радиальное смешение цветов по опорным точкам)
class MeshGradient {
  static const String _asset = 'shaders/mesh_gradient.frag';

  static ui.FragmentProgram? _program;
  static bool _loadAttempted = false;

  static bool get isSupported => _program != null;

  static Future<void> load() async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    try {
      _program = await ui.FragmentProgram.fromAsset(_asset);
    } catch (_) {
      _program = null;
    }
  }

  static ui.FragmentShader? newShader() => _program?.fragmentShader();
}

class MeshGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final bool animate;
  // #***! позиция опорных точек при animate == false, в шагах (0..8, дробная
  // часть — прогресс между соседними шагами); позволяет вручную повернуть
  // статичный градиент
  final double rotation;
  // #***! длительность одного шага смены опорных точек
  final Duration stepDuration;

  const MeshGradientBackground({
    super.key,
    required this.colors,
    this.animate = true,
    this.rotation = 0,
    this.stepDuration = const Duration(milliseconds: 4200),
  });

  @override
  State<MeshGradientBackground> createState() =>
      _MeshGradientBackgroundState();
}

class _MeshGradientBackgroundState extends State<MeshGradientBackground>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  Ticker? _ticker;
  int _phase = 0;
  double _progress = 0;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _shader = MeshGradient.newShader();
    if (_shader != null && widget.animate && widget.colors.length > 1) {
      _startTicker();
    }
  }

  void _startTicker() {
    _lastTick = Duration.zero;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant MeshGradientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.animate && widget.colors.length > 1;
    if (shouldAnimate && _ticker == null) {
      _startTicker();
    } else if (!shouldAnimate && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastTick;
    _lastTick = elapsed;
    final stepMs = widget.stepDuration.inMilliseconds;
    if (stepMs <= 0) return;
    final next = _progress + delta.inMilliseconds / stepMs;
    if (next >= 1) {
      _phase = (_phase + 1) % 8;
      _progress = next - next.floorToDouble();
    } else {
      _progress = next;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    if (colors.isEmpty) return const SizedBox.shrink();
    final shader = _shader;
    if (shader == null || colors.length == 1) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: colors.length > 1
              ? LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: colors.length == 1 ? colors.first : null,
        ),
      );
    }
    int phase;
    double progress;
    if (widget.animate) {
      phase = _phase;
      progress = _progress;
    } else {
      final r = widget.rotation % 8;
      final normalized = r < 0 ? r + 8 : r;
      phase = normalized.floor();
      progress = normalized - phase;
    }
    return CustomPaint(
      painter: _MeshGradientPainter(
        shader: shader,
        colors: colors,
        phase: phase,
        progress: progress,
      ),
      size: Size.infinite,
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final List<Color> colors;
  final int phase;
  final double progress;

  _MeshGradientPainter({
    required this.shader,
    required this.colors,
    required this.phase,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, colors.length.toDouble())
      ..setFloat(i++, phase.toDouble())
      ..setFloat(i++, progress);
    for (var c = 0; c < 6; c++) {
      final color = c < colors.length ? colors[c] : colors.last;
      shader
        ..setFloat(i++, color.r)
        ..setFloat(i++, color.g)
        ..setFloat(i++, color.b)
        ..setFloat(i++, color.a);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.progress != progress ||
      !_sameColors(oldDelegate.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
