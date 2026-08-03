import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'spectrum_tint.dart';

class SpectrumTuning {
  const SpectrumTuning._();

  static const double barWidth = 1;
  static const double barGap = 0.6;
  static const double heightFraction = 0.75;
  static const double surfaceLift = 0.06;
  static const double tintStrength = 0.3;
  static const double tintRadius = 190;
  static const double tintFollowRate = 3.5;
  static const double frameInterval = 1 / 60;
  static const double tintInterval = 0.2;
  static const double parallax = 0.06;
  static const int minBars = 4;
  static const int maxBars = 1024;

  static Color baseColor(ColorScheme cs) {
    final surface = cs.surface;
    final lift = surface.computeLuminance() < 0.5 ? Colors.white : Colors.black;
    return Color.alphaBlend(lift.withValues(alpha: surfaceLift), surface);
  }
}

class SpectrumBackground extends StatefulWidget {
  const SpectrumBackground({super.key});

  @override
  State<SpectrumBackground> createState() => _SpectrumBackgroundState();
}

class _SpectrumBackgroundState extends State<SpectrumBackground>
    with SingleTickerProviderStateMixin {
  static const double _maxStep = 0.25;

  final List<SpectrumTintSample> _samples = <SpectrumTintSample>[];

  late final Ticker _ticker;
  _SpectrumField? _field;
  _SpectrumPalette? _palette;
  Duration _lastElapsed = Duration.zero;
  double _frameAccumulator = 0;
  double _tintAccumulator = SpectrumTuning.tintInterval;
  double _pitch = SpectrumTuning.barWidth + SpectrumTuning.barGap;
  double _leftInset = 0;
  Color _baseColor = const Color(0xFF000000);

  @override
  void initState() {
    super.initState();
    SpectrumTintRegistry.instance.listenForResolvedColors(_onColorResolved);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    SpectrumTintRegistry.instance.listenForResolvedColors(null);
    _ticker.dispose();
    _field?.dispose();
    super.dispose();
  }

  void _onColorResolved() => _tintAccumulator = SpectrumTuning.tintInterval;

  void _onTick(Duration elapsed) {
    final delta =
        (elapsed - _lastElapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    if (delta <= 0) return;

    final step = delta > _maxStep ? _maxStep : delta;

    _tintAccumulator += step;
    if (_tintAccumulator >= SpectrumTuning.tintInterval) {
      _tintAccumulator = 0;
      _refreshTints();
    }

    _frameAccumulator += step;
    if (_frameAccumulator < SpectrumTuning.frameInterval) return;

    final frameStep = _frameAccumulator;
    _frameAccumulator = 0;
    _palette?.advance(frameStep);
    _field?.update(frameStep);
  }

  void _refreshTints() {
    final palette = _palette;
    if (palette == null) return;

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;

    final origin = box.localToGlobal(Offset.zero);
    final viewport = (origin & box.size).inflate(SpectrumTuning.tintRadius);
    SpectrumTintRegistry.instance.collect(_samples, viewport);

    palette.retarget(
      base: _baseColor,
      samples: _samples,
      zoneLeft: origin.dx + _zoneLeft,
      zoneRight: origin.dx + _zoneRight,
      baselineY: origin.dy + box.size.height,
    );
  }

  double get _zoneLeft => _leftInset;

  double get _zoneRight =>
      _leftInset +
      (_field == null ? 0 : (_field!.barCount - 1) * _pitch) +
      SpectrumTuning.barWidth;

  void _syncMetrics(Size size, Color base) {
    _baseColor = base;
    if (size.width <= 0 || size.height <= 0) return;

    final pitch = SpectrumTuning.barWidth + SpectrumTuning.barGap;
    final count = ((size.width + SpectrumTuning.barGap) / pitch).floor().clamp(
      SpectrumTuning.minBars,
      SpectrumTuning.maxBars,
    );
    final occupied = count * pitch - SpectrumTuning.barGap;

    _pitch = pitch;
    _leftInset = (size.width - occupied) / 2;

    if (_field?.barCount == count) return;

    _field?.dispose();
    _field = _SpectrumField(count);
    _palette = _SpectrumPalette(base);
  }

  @override
  Widget build(BuildContext context) {
    final base = SpectrumTuning.baseColor(Theme.of(context).colorScheme);

    return LayoutBuilder(
      builder: (context, constraints) {
        _syncMetrics(constraints.biggest, base);

        final field = _field;
        final palette = _palette;
        if (field == null || palette == null) return const SizedBox.expand();

        return CustomPaint(
          size: Size.infinite,
          isComplex: false,
          willChange: true,
          painter: _SpectrumPainter(
            field: field,
            palette: palette,
            zoneLeft: _zoneLeft,
            zoneRight: _zoneRight,
            pitch: _pitch,
            leftInset: _leftInset,
          ),
        );
      },
    );
  }
}

class _SpectrumField extends ChangeNotifier {
  _SpectrumField(this.barCount)
    : heights = Float32List(barCount),
      _targets = Float32List(barCount),
      _spread = Float32List(barCount),
      _sparks = Float32List(barCount),
      _velocities = Float32List(barCount),
      _phases = Float32List(barCount),
      _rates = Float32List(barCount) {
    final random = math.Random(barCount * 7919 + 13);
    for (var i = 0; i < barCount; i++) {
      _phases[i] = random.nextDouble() * math.pi * 2;
      _rates[i] = 0.6 + random.nextDouble() * 1.5;
    }
    final reach = (barCount * 0.03).clamp(3.0, 40.0);
    _spreadDecay = math.pow(_spreadEdge, 1 / reach).toDouble();
  }

  static const double _speed = 2.8;
  static const double _ambient = 0.22;
  static const double _reach = 1;
  static const double _sparkReach = 0.45;
  static const double _sparkDecay = 7;
  static const double _riseRate = 26;
  static const double _gravity = 5.5;
  static const double _spreadEdge = 0.1;

  final int barCount;
  final Float32List heights;
  final Float32List _targets;
  final Float32List _spread;
  final Float32List _sparks;
  final Float32List _velocities;
  final Float32List _phases;
  final Float32List _rates;
  final math.Random _random = math.Random(4409);

  late final double _spreadDecay;
  double _elapsed = 0;
  double _sparkCountdown = 0.15;

  void update(double dt) {
    _elapsed += dt;
    _driveTargets(dt);
    _spreadToNeighbours();
    _applyGravity(dt);
    notifyListeners();
  }

  void _driveTargets(double dt) {
    _sparkCountdown -= dt;
    if (_sparkCountdown <= 0) {
      _sparkCountdown = 0.08 + _random.nextDouble() * 0.3;
      _sparks[_random.nextInt(barCount)] = 0.5 + _random.nextDouble() * 0.5;
    }
    final sparkDecay = math.exp(-dt * _sparkDecay);

    final time = _elapsed * _speed;
    final peak =
        0.5 + 0.24 * math.sin(time * 0.11) + 0.09 * math.sin(time * 0.37 + 1.3);
    final width = 0.19 + 0.05 * math.sin(time * 0.23);
    final last = barCount - 1;

    for (var i = 0; i < barCount; i++) {
      final position = last == 0 ? 0.5 : i / last;
      final distance = (position - peak) / width;
      final envelope = math.exp(-distance * distance);

      final slow = 0.5 + 0.5 * math.sin(time * _rates[i] * 0.55 + _phases[i]);
      final fast =
          0.5 + 0.5 * math.sin(time * _rates[i] * 2.3 + _phases[i] * 1.7);
      final wobble = slow * fast;

      _sparks[i] *= sparkDecay;
      final driven =
          envelope * (0.3 + 0.7 * wobble) * _reach +
          _ambient * wobble +
          _sparks[i] * _sparkReach;
      _targets[i] = driven > 1 ? 1 : driven;
    }
  }

  void _spreadToNeighbours() {
    var running = 0.0;
    for (var i = 0; i < barCount; i++) {
      running *= _spreadDecay;
      final value = _targets[i];
      if (value > running) running = value;
      _spread[i] = running;
    }
    running = 0.0;
    for (var i = barCount - 1; i >= 0; i--) {
      running *= _spreadDecay;
      final value = _targets[i];
      if (value > running) running = value;
      if (running > _spread[i]) _spread[i] = running;
    }
  }

  void _applyGravity(double dt) {
    final riseFactor = 1 - math.exp(-dt * _riseRate);
    for (var i = 0; i < barCount; i++) {
      final target = _spread[i];
      final current = heights[i];
      if (target >= current) {
        heights[i] = current + (target - current) * riseFactor;
        _velocities[i] = 0;
        continue;
      }
      _velocities[i] += _gravity * dt;
      final next = current - _velocities[i] * dt;
      if (next <= target) {
        heights[i] = target;
        _velocities[i] = 0;
      } else {
        heights[i] = next;
      }
    }
  }
}

class _SpectrumPalette {
  _SpectrumPalette(Color base) {
    _writeUniform(_current, base);
    _writeUniform(_target, base);
    for (var i = 0; i < stopCount; i++) {
      colors[i] = base;
    }
  }

  static const int stopCount = 16;
  static const double _epsilon = 0.0008;
  static final double _radiusSquared =
      SpectrumTuning.tintRadius * SpectrumTuning.tintRadius;
  static final List<double> _stops = List<double>.generate(
    stopCount,
    (i) => i / (stopCount - 1),
  );

  final List<Color> colors = List<Color>.filled(
    stopCount,
    const Color(0xFF000000),
  );
  final Float32List _current = Float32List(stopCount * 3);
  final Float32List _target = Float32List(stopCount * 3);

  bool uniform = true;
  bool _targetUniform = true;
  ui.Shader? _shader;
  double _shaderLeft = double.nan;
  double _shaderRight = double.nan;

  static void _writeUniform(Float32List channels, Color color) {
    for (var i = 0; i < channels.length; i += 3) {
      channels[i] = color.r;
      channels[i + 1] = color.g;
      channels[i + 2] = color.b;
    }
  }

  void retarget({
    required Color base,
    required List<SpectrumTintSample> samples,
    required double zoneLeft,
    required double zoneRight,
    required double baselineY,
  }) {
    final baseRed = base.r;
    final baseGreen = base.g;
    final baseBlue = base.b;
    final span = zoneRight - zoneLeft;
    var anyTinted = false;

    for (var i = 0; i < stopCount; i++) {
      final x = zoneLeft + span * _stops[i];
      var sumRed = 0.0;
      var sumGreen = 0.0;
      var sumBlue = 0.0;
      var sumWeight = 0.0;

      for (var s = 0; s < samples.length; s++) {
        final sample = samples[s];
        final dx = sample.center.dx - x;
        final dy = sample.center.dy - baselineY;
        final weight =
            sample.weight / (1 + (dx * dx + dy * dy) / _radiusSquared);
        if (weight < 0.015) continue;
        sumRed += sample.color.r * weight;
        sumGreen += sample.color.g * weight;
        sumBlue += sample.color.b * weight;
        sumWeight += weight;
      }

      final index = i * 3;
      if (sumWeight <= 0) {
        _target[index] = baseRed;
        _target[index + 1] = baseGreen;
        _target[index + 2] = baseBlue;
        continue;
      }

      final influence =
          (sumWeight > 1 ? 1.0 : sumWeight) * SpectrumTuning.tintStrength;
      _target[index] = baseRed + (sumRed / sumWeight - baseRed) * influence;
      _target[index + 1] =
          baseGreen + (sumGreen / sumWeight - baseGreen) * influence;
      _target[index + 2] =
          baseBlue + (sumBlue / sumWeight - baseBlue) * influence;
      anyTinted = true;
    }

    _targetUniform = !anyTinted;
  }

  void advance(double dt) {
    final factor = 1 - math.exp(-dt * SpectrumTuning.tintFollowRate);
    var changed = false;

    for (var i = 0; i < _current.length; i++) {
      final delta = _target[i] - _current[i];
      if (delta < _epsilon && delta > -_epsilon) {
        if (_current[i] != _target[i]) {
          _current[i] = _target[i];
          changed = true;
        }
        continue;
      }
      _current[i] += delta * factor;
      changed = true;
    }

    if (!changed) {
      uniform = _targetUniform;
      return;
    }

    for (var i = 0; i < stopCount; i++) {
      final index = i * 3;
      colors[i] = Color.from(
        alpha: 1,
        red: _current[index],
        green: _current[index + 1],
        blue: _current[index + 2],
      );
    }
    uniform = false;
    _shader = null;
  }

  ui.Shader shaderFor(double left, double right) {
    final cached = _shader;
    if (cached != null && _shaderLeft == left && _shaderRight == right) {
      return cached;
    }
    _shaderLeft = left;
    _shaderRight = right;
    return _shader = ui.Gradient.linear(
      Offset(left, 0),
      Offset(right, 0),
      colors,
      _stops,
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  _SpectrumPainter({
    required this.field,
    required this.palette,
    required this.zoneLeft,
    required this.zoneRight,
    required this.pitch,
    required this.leftInset,
  }) : super(repaint: field);

  static const double _minVisibleHeight = 0.6;

  final _SpectrumField field;
  final _SpectrumPalette palette;
  final double zoneLeft;
  final double zoneRight;
  final double pitch;
  final double leftInset;

  @override
  void paint(Canvas canvas, Size size) {
    final heights = field.heights;
    if (heights.isEmpty) return;

    final maxHeight = size.height * SpectrumTuning.heightFraction;
    final baseline = size.height;
    final paint = Paint();
    if (palette.uniform) {
      paint.color = palette.colors.first;
    } else {
      paint.shader = palette.shaderFor(zoneLeft, zoneRight);
    }

    for (var i = 0; i < heights.length; i++) {
      final height = heights[i] * maxHeight;
      if (height < _minVisibleHeight) continue;
      final left = leftInset + pitch * i;
      canvas.drawRect(
        Rect.fromLTRB(
          left,
          baseline - height,
          left + SpectrumTuning.barWidth,
          baseline,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpectrumPainter old) =>
      old.field != field ||
      old.palette != palette ||
      old.pitch != pitch ||
      old.leftInset != leftInset ||
      old.zoneLeft != zoneLeft ||
      old.zoneRight != zoneRight;
}
