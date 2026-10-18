import 'dart:async';
import 'dart:math' show exp, ln10, log, max, min, pi, pow, sin;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../widgets/animated_slash_icon.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/lottie_slash_icon.dart';
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

class CallPressScale extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final double pressedScale;

  const CallPressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.88,
  });

  @override
  State<CallPressScale> createState() => _CallPressScaleState();
}

class _CallPressScaleState extends State<CallPressScale> {
  bool _pressed = false;

  void _press(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _press(widget.enabled),
      onPointerUp: (_) => _press(false),
      onPointerCancel: (_) => _press(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: _pressed
            ? const Duration(milliseconds: 90)
            : const Duration(milliseconds: 280),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

class CallColorTransition extends StatelessWidget {
  static const Duration duration = Duration(milliseconds: 220);

  final Color background;
  final Color foreground;
  final Widget Function(
    BuildContext context,
    Color background,
    Color foreground,
  )
  builder;

  const CallColorTransition({
    super.key,
    required this.background,
    required this.foreground,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: background),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, bg, _) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: foreground),
        duration: duration,
        curve: Curves.easeOut,
        builder: (context, fg, _) =>
            builder(context, bg ?? background, fg ?? foreground),
      ),
    );
  }
}

class CallButton extends StatelessWidget {
  static const double maxDiameter = 62;
  static const double _minGap = 6;

  final IconData icon;
  final IconData? slashedIcon;
  final String? slashAsset;
  final Widget? glyph;
  final bool slashed;
  final bool badge;
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
    this.slashAsset,
    this.glyph,
    this.slashed = false,
    this.badge = false,
    this.busy = false,
    this.micLevels,
  });

  Widget _buildIcon(Color color) {
    final custom = glyph;
    if (custom != null) {
      return IconTheme.merge(
        data: IconThemeData(color: color, size: 26),
        child: custom,
      );
    }
    final asset = slashAsset;
    if (asset != null) {
      return LottieSlashIcon(
        asset: asset,
        slashed: slashed,
        color: color,
        size: 26,
      );
    }
    final crossed = slashedIcon;
    if (crossed == null) {
      return Icon(icon, color: color, size: 26, fill: 1);
    }
    return AnimatedSlashIcon(
      icon: icon,
      slashedIcon: crossed,
      slashed: slashed,
      color: color,
      size: 26,
      fill: 1,
    );
  }

  Widget _content(ColorScheme cs, Color color) {
    final content = Center(
      child: busy ? SmallSpinner(size: 22, color: color) : _buildIcon(color),
    );
    final levels = micLevels;
    if (levels == null) return content;
    return Stack(
      fit: StackFit.expand,
      children: [
        MicWaterFill(
          levels: levels,
          active: !slashed && !busy,
          color: cs.primary,
        ),
        content,
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
              child: CallPressScale(
                enabled: !busy,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CallColorTransition(
                        background: background,
                        foreground: foreground,
                        builder: (context, bg, fg) => GlossyPill(
                          color: bg,
                          borderRadius: BorderRadius.circular(diameter / 2),
                          onTap: busy ? null : onTap,
                          onLongPress: busy ? null : onLongPress,
                          depth: 9,
                          child: _content(cs, fg),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IgnorePointer(
                        child: AnimatedScale(
                          scale: badge ? 1 : 0,
                          duration: const Duration(milliseconds: 240),
                          curve: badge ? Curves.easeOutBack : Curves.easeIn,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  label,
                  key: ValueKey((CallButton, label)),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
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
