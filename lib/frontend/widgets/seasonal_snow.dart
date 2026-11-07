import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/config/komet_settings.dart';

bool isSeasonalSnowDate(DateTime date) =>
    (date.month == DateTime.december && date.day >= 1) ||
    (date.month == DateTime.january && date.day <= 3);

/// Decorative snow shown automatically from December 1 through January 3.
/// [KometSettings.debugSnow] can force it on outside that period.
class SeasonalSnowLayer extends StatefulWidget {
  const SeasonalSnowLayer({
    super.key,
    this.flakeCount = 52,
    this.seed = 2027,
    this.opacity = 1,
  });

  final int flakeCount;
  final int seed;
  final double opacity;

  @override
  State<SeasonalSnowLayer> createState() => _SeasonalSnowLayerState();
}

class _SeasonalSnowLayerState extends State<SeasonalSnowLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late List<_Snowflake> _flakes;
  Timer? _dateTimer;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _flakes = _makeFlakes();
    KometSettings.debugSnow.addListener(_refreshEnabled);
    _refreshEnabled(notify: false);
    _scheduleDateRefresh();
  }

  @override
  void didUpdateWidget(SeasonalSnowLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.flakeCount != widget.flakeCount) {
      _flakes = _makeFlakes();
    }
  }

  List<_Snowflake> _makeFlakes() {
    final random = math.Random(widget.seed);
    return List.generate(
      widget.flakeCount,
      (_) => _Snowflake(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: 1.15 + random.nextDouble() * 2.15,
        speed: random.nextBool() ? 1 : 2,
        drift: 0.012 + random.nextDouble() * 0.038,
        phase: random.nextDouble() * math.pi * 2,
        alpha: 0.48 + random.nextDouble() * 0.42,
      ),
      growable: false,
    );
  }

  void _refreshEnabled({bool notify = true}) {
    final enabled =
        KometSettings.debugSnow.value || isSeasonalSnowDate(DateTime.now());
    if (_enabled == enabled) return;
    _enabled = enabled;
    if (enabled) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
    if (notify && mounted) setState(() {});
  }

  void _scheduleDateRefresh() {
    _dateTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    _dateTimer = Timer(
      nextDay.difference(now) + const Duration(seconds: 1),
      () {
        _refreshEnabled();
        _scheduleDateRefresh();
      },
    );
  }

  @override
  void dispose() {
    _dateTimer?.cancel();
    KometSettings.debugSnow.removeListener(_refreshEnabled);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled || widget.flakeCount <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: widget.opacity.clamp(0.0, 1.0),
          child: RepaintBoundary(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _SnowPainter(animation: _controller, flakes: _flakes),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Snowflake {
  const _Snowflake({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.drift,
    required this.phase,
    required this.alpha,
  });

  final double x;
  final double y;
  final double radius;
  final int speed;
  final double drift;
  final double phase;
  final double alpha;
}

class _SnowPainter extends CustomPainter {
  _SnowPainter({required this.animation, required this.flakes})
    : super(repaint: animation);

  final Animation<double> animation;
  final List<_Snowflake> flakes;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final progress = animation.value;
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.14);
    final snow = Paint()..color = Colors.white;

    for (final flake in flakes) {
      final travel = (flake.y + progress * flake.speed) % 1.0;
      final wave = math.sin(progress * math.pi * 2 * flake.speed + flake.phase);
      final x = ((flake.x + wave * flake.drift) % 1.0) * size.width;
      final y = (travel * 1.12 - 0.08) * size.height;
      shadow.color = Colors.black.withValues(alpha: flake.alpha * 0.16);
      snow.color = Colors.white.withValues(alpha: flake.alpha);
      canvas.drawCircle(Offset(x + 0.8, y + 1.1), flake.radius + 0.35, shadow);
      canvas.drawCircle(Offset(x, y), flake.radius, snow);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) =>
      oldDelegate.flakes != flakes;
}
