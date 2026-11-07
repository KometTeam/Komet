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
    this.flakeCount = 24,
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
    with WidgetsBindingObserver {
  static const _frameInterval = Duration(milliseconds: 125);

  final ValueNotifier<double> _elapsedSeconds = ValueNotifier(0);
  final Stopwatch _clock = Stopwatch();
  late List<_Snowflake> _flakes;
  Timer? _frameTimer;
  Timer? _dateTimer;
  bool _enabled = false;
  bool _tickerMode = true;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _flakes = _makeFlakes();
    KometSettings.debugSnow.addListener(_refreshEnabled);
    _refreshEnabled(notify: false);
    _scheduleDateRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerMode = TickerMode.of(context);
    if (_tickerMode == tickerMode) return;
    _tickerMode = tickerMode;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(SeasonalSnowLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed != widget.seed ||
        oldWidget.flakeCount != widget.flakeCount) {
      _flakes = _makeFlakes();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    _syncAnimation();
  }

  List<_Snowflake> _makeFlakes() {
    final random = math.Random(widget.seed);
    return List.generate(
      widget.flakeCount,
      (_) => _Snowflake(
        x: random.nextDouble(),
        y: random.nextDouble(),
        radius: 1.0 + random.nextDouble() * 1.8,
        speed: 0.018 + random.nextDouble() * 0.014,
        drift: 0.01 + random.nextDouble() * 0.03,
        swaySpeed: 0.28 + random.nextDouble() * 0.3,
        phase: random.nextDouble() * math.pi * 2,
        alpha: 0.42 + random.nextDouble() * 0.38,
      ),
      growable: false,
    );
  }

  void _refreshEnabled({bool notify = true}) {
    final enabled =
        KometSettings.debugSnow.value || isSeasonalSnowDate(DateTime.now());
    if (_enabled == enabled) return;
    _enabled = enabled;
    _syncAnimation();
    if (notify && mounted) setState(() {});
  }

  void _syncAnimation() {
    final shouldRun = _enabled && _tickerMode && _appActive;
    if (shouldRun) {
      if (_frameTimer != null) return;
      _clock.start();
      _frameTimer = Timer.periodic(_frameInterval, (_) {
        _elapsedSeconds.value = _clock.elapsedMilliseconds / 1000;
      });
      return;
    }
    _frameTimer?.cancel();
    _frameTimer = null;
    _clock.stop();
    if (!_enabled) {
      _clock.reset();
      _elapsedSeconds.value = 0;
    }
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
    _frameTimer?.cancel();
    KometSettings.debugSnow.removeListener(_refreshEnabled);
    WidgetsBinding.instance.removeObserver(this);
    _elapsedSeconds.dispose();
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
                painter: _SnowPainter(
                  elapsedSeconds: _elapsedSeconds,
                  flakes: _flakes,
                ),
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
    required this.swaySpeed,
    required this.phase,
    required this.alpha,
  });

  final double x;
  final double y;
  final double radius;
  final double speed;
  final double drift;
  final double swaySpeed;
  final double phase;
  final double alpha;
}

class _SnowPainter extends CustomPainter {
  _SnowPainter({required this.elapsedSeconds, required this.flakes})
    : super(repaint: elapsedSeconds);

  final ValueListenable<double> elapsedSeconds;
  final List<_Snowflake> flakes;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final elapsed = elapsedSeconds.value;
    final shadow = Paint();
    final snow = Paint();

    for (final flake in flakes) {
      final travel = (flake.y + elapsed * flake.speed) % 1.0;
      final wave = math.sin(elapsed * flake.swaySpeed + flake.phase);
      final x = ((flake.x + wave * flake.drift) % 1.0) * size.width;
      final y = (travel * 1.1 - 0.06) * size.height;
      shadow.color = Colors.black.withValues(alpha: flake.alpha * 0.14);
      snow.color = Colors.white.withValues(alpha: flake.alpha);
      canvas.drawCircle(Offset(x + 0.7, y + 1), flake.radius + 0.3, shadow);
      canvas.drawCircle(Offset(x, y), flake.radius, snow);
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) =>
      oldDelegate.flakes != flakes;
}
