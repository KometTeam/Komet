import 'dart:async';
import 'dart:math' show exp, ln10, log, max, min, pi, pow, sin;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../widgets/animated_slash_icon.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/small_spinner.dart';

class CallControlBar extends StatelessWidget {
  final List<Widget> children;

  const CallControlBar({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final child in children) Expanded(child: child)],
      ),
    );
  }
}

class CallButton extends StatelessWidget {
  static const double maxDiameter = 62;
  static const double _minGap = 6;

  final IconData icon;
  final IconData? slashedIcon;
  final bool slashed;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool busy;
  final Stream<double>? micLevels;

  const CallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.onLongPress,
    this.slashedIcon,
    this.slashed = false,
    this.busy = false,
    this.micLevels,
  });

  Widget _buildIcon() {
    final crossed = slashedIcon;
    if (crossed == null) {
      return Icon(icon, color: foreground, size: 26, fill: 1);
    }
    return AnimatedSlashIcon(
      icon: icon,
      slashedIcon: crossed,
      slashed: slashed,
      color: foreground,
      size: 26,
      fill: 1,
    );
  }

  Widget _content(ColorScheme cs) {
    final glyph = Center(
      child: busy ? SmallSpinner(size: 22, color: foreground) : _buildIcon(),
    );
    final levels = micLevels;
    if (levels == null) return glyph;
    return Stack(
      fit: StackFit.expand,
      children: [
        MicWaterFill(
          levels: levels,
          active: !slashed && !busy,
          color: cs.primary,
        ),
        glyph,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = min(maxDiameter, constraints.maxWidth - _minGap);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: diameter,
              height: diameter,
              child: GlossyPill(
                color: background,
                borderRadius: BorderRadius.circular(diameter / 2),
                onTap: busy ? null : onTap,
                onLongPress: busy ? null : onLongPress,
                depth: 9,
                child: _content(cs),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class MicWaterFill extends StatefulWidget {
  final Stream<double> levels;
  final bool active;
  final Color color;

  const MicWaterFill({
    super.key,
    required this.levels,
    required this.active,
    required this.color,
  });

  @override
  State<MicWaterFill> createState() => _MicWaterFillState();
}

class _MicWaterFillState extends State<MicWaterFill>
    with SingleTickerProviderStateMixin {
  static const double _riseSeconds = 0.1;
  static const double _fallSeconds = 0.4;
  static const double _invisible = 0.025;

  final _WaterSurface _surface = _WaterSurface();
  final MicVoiceMeter _meter = MicVoiceMeter();
  final Stopwatch _sampleClock = Stopwatch()..start();
  late final Ticker _ticker = createTicker(_onTick);
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<double>? _subscription;
  Duration _lastTick = Duration.zero;
  double _target = 0;
  bool _onScreen = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (_) => _syncSubscription(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onScreen = TickerMode.valuesOf(context).enabled;
    _syncSubscription();
  }

  @override
  void didUpdateWidget(MicWaterFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.levels != widget.levels) _unsubscribe();
    _syncSubscription();
  }

  @override
  void dispose() {
    _unsubscribe();
    _lifecycle.dispose();
    _ticker.dispose();
    _surface.dispose();
    super.dispose();
  }

  bool get _appVisible => switch (WidgetsBinding.instance.lifecycleState) {
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
    _ => true,
  };

  void _syncSubscription() {
    if (!widget.active || !_onScreen || !_appVisible) {
      _unsubscribe();
      _aim(0);
      return;
    }
    if (_subscription != null) return;
    _sampleClock.reset();
    _subscription = widget.levels.listen(_onLevel);
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _onLevel(double level) {
    final seconds =
        _sampleClock.elapsedMicroseconds / Duration.microsecondsPerSecond;
    _sampleClock.reset();
    final fill = _meter.fill(level, seconds);
    _aim(fill < _invisible ? 0 : fill);
  }

  void _aim(double target) {
    _target = target;
    if (_ticker.isActive || (target == 0 && _surface.level == 0)) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    final current = _surface.level;
    final seconds = _target > current ? _riseSeconds : _fallSeconds;
    var level = current + (_target - current) * (1 - exp(-dt / seconds));
    if (_target == 0 && level < _invisible) level = 0;
    _surface.advance(level, dt);
    if (level == 0 && _target == 0) _ticker.stop();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _WaterPainter(_surface, widget.color)),
    );
  }
}

class MicVoiceMeter {
  static const double _gateAboveNoiseDb = 9;
  static const double _quietestGateDb = -45;
  static const double _noiseCeilingDb = -24;
  static const double _noiseClimbDbPerSecond = 3;
  static const double _voiceRangeDb = 28;
  static const double _curve = 1.25;

  double? _noiseDb;

  double fill(double level, double secondsSinceLast) {
    if (level <= 0) return 0;
    final db = 20 * log(level) / ln10;
    final noise = _noiseDb;
    final tracked = noise == null || db < noise
        ? db
        : min(db, noise + _noiseClimbDbPerSecond * secondsSinceLast);
    final floor = min(tracked, _noiseCeilingDb);
    _noiseDb = floor;
    final gate = max(floor + _gateAboveNoiseDb, _quietestGateDb);
    final voice = ((db - gate) / _voiceRangeDb).clamp(0.0, 1.0);
    return pow(voice, _curve).toDouble();
  }
}

class _WaterSurface extends ChangeNotifier {
  static const double _wavesPerSecond = 0.8;

  double level = 0;
  double phase = 0;

  void advance(double nextLevel, double dt) {
    level = nextLevel;
    phase = (phase + dt * _wavesPerSecond * 2 * pi) % (2 * pi);
    notifyListeners();
  }
}

class _WaterPainter extends CustomPainter {
  static const double _maxHeight = 0.88;
  static const double _amplitude = 0.045;
  static const double _calmBelow = 0.25;

  final _WaterSurface surface;
  final Color color;
  final Paint _backPaint;
  final Paint _frontPaint;

  _WaterPainter(this.surface, this.color)
    : _backPaint = Paint()..color = color.withValues(alpha: color.a * 0.35),
      _frontPaint = Paint()..color = color.withValues(alpha: color.a * 0.6),
      super(repaint: surface);

  @override
  void paint(Canvas canvas, Size size) {
    final level = surface.level;
    if (level <= 0) return;
    final top = size.height * (1 - level * _maxHeight);
    final amplitude = size.height * _amplitude * min(1.0, level / _calmBelow);
    canvas.drawPath(
      _wave(size, top, amplitude, size.width * 1.4, pi - surface.phase * 0.8),
      _backPaint,
    );
    canvas.drawPath(
      _wave(size, top, amplitude, size.width, surface.phase),
      _frontPaint,
    );
  }

  Path _wave(
    Size size,
    double top,
    double amplitude,
    double length,
    double phase,
  ) {
    double crest(double x) =>
        top + amplitude * sin(2 * pi * x / length + phase);
    final path = Path()..moveTo(0, size.height);
    for (var x = 0.0; x < size.width; x += 2) {
      path.lineTo(x, crest(x));
    }
    return path
      ..lineTo(size.width, crest(size.width))
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldRepaint(_WaterPainter oldDelegate) =>
      oldDelegate.surface != surface || oldDelegate.color != color;
}
