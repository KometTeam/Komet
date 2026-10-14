import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class Spoiler extends StatefulWidget {
  const Spoiler({
    super.key,
    required this.revealed,
    required this.color,
    required this.child,
  });

  final bool revealed;
  final Color color;
  final Widget child;

  @override
  State<Spoiler> createState() => _SpoilerState();
}

class _SpoilerState extends State<Spoiler> with SingleTickerProviderStateMixin {
  static const Duration _defaultRevealDuration = Duration(milliseconds: 350);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _defaultRevealDuration,
    value: widget.revealed ? 1 : 0,
  );
  late final CurvedAnimation _reveal = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  Offset? _pointer;
  double? _pointerRadius;
  Offset? _origin;

  @override
  void didUpdateWidget(Spoiler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealed == oldWidget.revealed) return;
    _origin = _pointer;
    _controller.duration = _revealDuration(_pointerRadius);
    _pointer = null;
    _pointerRadius = null;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.revealed ? 1 : 0;
    } else if (widget.revealed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _controller.dispose();
    super.dispose();
  }

  static Duration _revealDuration(double? radius) {
    if (radius == null) return _defaultRevealDuration;
    return Duration(milliseconds: (radius * 3).clamp(250, 550).round());
  }

  void _rememberPointer(PointerDownEvent event) {
    final size = context.size;
    if (size == null) return;
    _pointer = event.localPosition;
    _pointerRadius = _farthestCornerDistance(event.localPosition, size);
  }

  @override
  Widget build(BuildContext context) {
    final animate =
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    return ExcludeSemantics(
      excluding: !widget.revealed,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _rememberPointer,
        child: _SpoilerBox(
          reveal: _reveal,
          origin: _origin,
          color: widget.color,
          pixelRatio: MediaQuery.devicePixelRatioOf(context),
          animate: animate,
          child: widget.child,
        ),
      ),
    );
  }
}

double _farthestCornerDistance(Offset point, Size size) {
  final dx = math.max(point.dx, size.width - point.dx);
  final dy = math.max(point.dy, size.height - point.dy);
  return math.sqrt(dx * dx + dy * dy);
}

class _SpoilerBox extends SingleChildRenderObjectWidget {
  const _SpoilerBox({
    required this.reveal,
    required this.origin,
    required this.color,
    required this.pixelRatio,
    required this.animate,
    required Widget super.child,
  });

  final Animation<double> reveal;
  final Offset? origin;
  final Color color;
  final double pixelRatio;
  final bool animate;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSpoiler(
    reveal: reveal,
    origin: origin,
    color: color,
    pixelRatio: pixelRatio,
    animate: animate,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderSpoiler renderObject) {
    renderObject
      ..reveal = reveal
      ..origin = origin
      ..color = color
      ..pixelRatio = pixelRatio
      ..animate = animate;
  }
}

class _RenderSpoiler extends RenderProxyBox {
  _RenderSpoiler({
    required Animation<double> reveal,
    required Offset? origin,
    required Color color,
    required double pixelRatio,
    required bool animate,
  }) : _reveal = reveal,
       _origin = origin,
       _color = color,
       _pixelRatio = pixelRatio,
       _animate = animate;

  static final math.Random _phaseRandom = math.Random();

  final Offset _phase = Offset(
    _phaseRandom.nextDouble() * SpoilerParticles.tileExtent,
    _phaseRandom.nextDouble() * SpoilerParticles.tileExtent,
  );
  final LayerHandle<ClipPathLayer> _clipLayer = LayerHandle<ClipPathLayer>();
  bool _subscribed = false;

  Animation<double> _reveal;
  set reveal(Animation<double> value) {
    if (identical(value, _reveal)) return;
    if (attached) _reveal.removeListener(_onReveal);
    _reveal = value;
    if (attached) _reveal.addListener(_onReveal);
    _onReveal();
  }

  Offset? _origin;
  set origin(Offset? value) {
    if (value == _origin) return;
    _origin = value;
    markNeedsPaint();
  }

  Color _color;
  set color(Color value) {
    if (value == _color) return;
    _color = value;
    markNeedsPaint();
  }

  double _pixelRatio;
  set pixelRatio(double value) {
    if (value == _pixelRatio) return;
    _pixelRatio = value;
    markNeedsPaint();
  }

  bool _animate;
  set animate(bool value) {
    if (value == _animate) return;
    _animate = value;
    _syncSubscription();
  }

  @override
  bool get isRepaintBoundary => true;

  void _onReveal() {
    _syncSubscription();
    markNeedsPaint();
  }

  void _syncSubscription() {
    final wanted = attached && _animate && _reveal.value < 1;
    if (wanted == _subscribed) return;
    _subscribed = wanted;
    if (wanted) {
      SpoilerParticles.instance.addListener(markNeedsPaint);
    } else {
      SpoilerParticles.instance.removeListener(markNeedsPaint);
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _reveal.addListener(_onReveal);
    _syncSubscription();
  }

  @override
  void detach() {
    _reveal.removeListener(_onReveal);
    super.detach();
    _syncSubscription();
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final progress = _reveal.value.clamp(0.0, 1.0);
    if (progress >= 1) {
      _clipLayer.layer = null;
      super.paint(context, offset);
      return;
    }
    final bounds = Offset.zero & size;
    final center = _origin ?? size.center(Offset.zero);
    final circle = Rect.fromCircle(
      center: center,
      radius: progress * _farthestCornerDistance(center, size),
    );
    if (progress > 0) {
      _clipLayer.layer = context.pushClipPath(
        needsCompositing,
        offset,
        bounds,
        Path()..addOval(circle),
        super.paint,
        oldLayer: _clipLayer.layer,
      );
    } else {
      _clipLayer.layer = null;
    }
    final canvas = context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    if (progress > 0) {
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(bounds)
          ..addOval(circle),
      );
    }
    SpoilerParticles.instance.paint(
      canvas,
      bounds,
      color: _color.withValues(alpha: _color.a * (1 - progress)),
      pixelRatio: _pixelRatio,
      phase: _phase,
    );
    canvas.restore();
  }
}

final class SpoilerParticles extends ChangeNotifier {
  SpoilerParticles._() {
    for (var i = 0; i < _count; i++) {
      _spawn(i);
      _age[i] = _random.nextDouble() * _life[i];
    }
  }

  static final SpoilerParticles instance = SpoilerParticles._();

  static const double tileExtent = 128;
  static const double _density = 0.22;
  static const double _minSpeed = 2.5;
  static const double _speedRange = 4.5;
  static const double _minLife = 1;
  static const double _lifeRange = 2;
  static const Duration _frameInterval = Duration(microseconds: 33333);
  static const List<double> _alphas = [0.3, 0.6, 1];
  static const List<double> _strokeWidths = [1.4, 1.2, 1.2];
  static final int _count = (tileExtent * tileExtent * _density).round();

  final math.Random _random = math.Random();
  final Float32List _x = Float32List(_count);
  final Float32List _y = Float32List(_count);
  final Float32List _vx = Float32List(_count);
  final Float32List _vy = Float32List(_count);
  final Float32List _age = Float32List(_count);
  final Float32List _life = Float32List(_count);
  final Uint8List _tier = Uint8List(_count);
  final Float32List _points = Float32List(_count * 8);
  final List<Paint> _paints = [
    for (var i = 0; i < _alphas.length; i++)
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, _alphas[i])
        ..strokeWidth = _strokeWidths[i]
        ..strokeCap = StrokeCap.round,
  ];
  Timer? _timer;
  int _lastTick = 0;
  int _listenerCount = 0;
  double _pixelRatio = 0;
  ui.Image? _tile;
  ImageShader? _shader;

  @visibleForTesting
  bool get isAnimating => _timer != null;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_listenerCount++ > 0) return;
    _lastTick = 0;
    _timer = Timer.periodic(_frameInterval, _onTick);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (--_listenerCount > 0) return;
    _timer?.cancel();
    _timer = null;
  }

  void paint(
    Canvas canvas,
    Rect rect, {
    required Color color,
    required double pixelRatio,
    Offset phase = Offset.zero,
  }) {
    if (pixelRatio > _pixelRatio) {
      _pixelRatio = pixelRatio;
      _renderTile();
    }
    final shader = _shader;
    if (shader == null) return;
    canvas
      ..save()
      ..translate(-phase.dx, -phase.dy)
      ..drawRect(
        rect.shift(phase),
        Paint()
          ..shader = shader
          ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn),
      )
      ..restore();
  }

  void _onTick(Timer timer) {
    final ticks = timer.tick - _lastTick;
    _lastTick = timer.tick;
    if (!SchedulerBinding.instance.framesEnabled) return;
    final interval =
        _frameInterval.inMicroseconds / Duration.microsecondsPerSecond;
    _step(math.min(ticks * interval, 0.1));
    _renderTile();
    notifyListeners();
  }

  void _step(double dt) {
    for (var i = 0; i < _count; i++) {
      final age = _age[i] + dt;
      if (age >= _life[i]) {
        _spawn(i);
        continue;
      }
      _age[i] = age;
      _x[i] = _wrap(_x[i] + _vx[i] * dt);
      _y[i] = _wrap(_y[i] + _vy[i] * dt);
    }
  }

  static double _wrap(double value) {
    if (value < 0) return value + tileExtent;
    if (value >= tileExtent) return value - tileExtent;
    return value;
  }

  void _spawn(int i) {
    final angle = _random.nextDouble() * 2 * math.pi;
    final speed = _minSpeed + _random.nextDouble() * _speedRange;
    _x[i] = _random.nextDouble() * tileExtent;
    _y[i] = _random.nextDouble() * tileExtent;
    _vx[i] = math.cos(angle) * speed;
    _vy[i] = math.sin(angle) * speed;
    _age[i] = 0;
    _life[i] = _minLife + _random.nextDouble() * _lifeRange;
    _tier[i] = _random.nextInt(_alphas.length);
  }

  void _renderTile() {
    if (_pixelRatio <= 0) return;
    final pixels = math.max(1, (tileExtent * _pixelRatio).round());
    final scale = pixels / tileExtent;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    for (var tier = 0; tier < _alphas.length; tier++) {
      final paint = _paints[tier];
      final length = _collectPoints(tier, paint.strokeWidth / 2);
      if (length == 0) continue;
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(_points, 0, length),
        paint,
      );
    }
    final picture = recorder.endRecording();
    final tile = picture.toImageSync(pixels, pixels);
    picture.dispose();
    _shader?.dispose();
    _tile?.dispose();
    _tile = tile;
    _shader = ImageShader(
      tile,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.diagonal3Values(1 / scale, 1 / scale, 1).storage,
      filterQuality: FilterQuality.low,
    );
  }

  int _collectPoints(int tier, double halfStroke) {
    final far = tileExtent - halfStroke;
    var length = 0;
    for (var i = 0; i < _count; i++) {
      if (_tier[i] != tier) continue;
      final x = _x[i];
      final y = _y[i];
      final dx = x < halfStroke ? tileExtent : (x > far ? -tileExtent : 0.0);
      final dy = y < halfStroke ? tileExtent : (y > far ? -tileExtent : 0.0);
      length = _put(length, x, y);
      if (dx != 0) length = _put(length, x + dx, y);
      if (dy != 0) length = _put(length, x, y + dy);
      if (dx != 0 && dy != 0) length = _put(length, x + dx, y + dy);
    }
    return length;
  }

  int _put(int length, double x, double y) {
    _points[length] = x;
    _points[length + 1] = y;
    return length + 2;
  }
}
