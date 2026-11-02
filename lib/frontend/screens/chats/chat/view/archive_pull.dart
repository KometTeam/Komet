import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/utils/haptics.dart';

const double kArchiveRowExtent = 60;

const double _snapFraction = 0.85;
const double _pullStartDistance = 4;
const Duration _minPullDuration = Duration(milliseconds: 200);
const Duration _armDelay = Duration(milliseconds: 220);

const double _resistanceAtStart = 0.45;
const double _resistanceAtRow = 0.2;
const double _overpullLimit = 72;
const double _resistanceStep = 4;

double archivePullOffset(double pulled, double offset) {
  var remaining = offset;
  var applied = 0.0;
  while (remaining > 0) {
    final step = math.min(remaining, _resistanceStep);
    applied += step * _resistanceAt(pulled + applied);
    remaining -= step;
  }
  return applied;
}

double _resistanceAt(double pulled) {
  if (pulled < kArchiveRowExtent) {
    final shown = pulled / kArchiveRowExtent;
    return _resistanceAtStart - (_resistanceAtStart - _resistanceAtRow) * shown;
  }
  final overpull = (pulled - kArchiveRowExtent) / _overpullLimit;
  return _resistanceAtRow * math.max(0.0, 1 - overpull);
}

class ArchivePullController extends ChangeNotifier {
  bool _revealed = false;
  bool _pulling = false;
  bool _armed = false;
  bool _overscrolled = false;
  final Map<int, int> _contacts = {};
  bool _wheel = false;
  double _pull = 0;
  double _pullBase = 0;
  DateTime? _pullStartedAt;

  bool get revealed => _revealed;
  double get pullBase => _pullBase;
  bool get pulling => _pulling;
  bool get armed => _armed;
  bool get touching => _wheel || _contacts.isNotEmpty;

  bool claimsDrag({required bool canPull}) =>
      !_revealed && touching && (_overscrolled ? _pulling : canPull);

  void pointerDown(PointerEvent event) =>
      _contacts[event.device] = event.pointer;

  void pointerUp(PointerEvent event) {
    if (_contacts[event.device] != event.pointer) return;
    _contacts.remove(event.device);
    if (!touching) _release();
  }

  void pointerHover(PointerEvent event) {
    if (_contacts.remove(event.device) == null) return;
    if (!touching) _release();
  }

  void wheelStart() => _wheel = true;

  void wheelEnd() {
    if (!_wheel) return;
    _wheel = false;
    if (!touching) _release();
  }

  void onScroll(double pixels, {required bool canPull}) {
    if (pixels < 0) {
      final takeOver = !_revealed && touching && canPull;
      if (!_overscrolled) {
        _overscrolled = true;
        _pullBase = 0;
        _setPulling(takeOver);
      } else if (!_pulling && takeOver) {
        _pullBase = -pixels;
        _setPulling(true);
      }
      if (_pulling && !_revealed) _track(math.max(0.0, -pixels - _pullBase));
      return;
    }
    _overscrolled = false;
    _pullBase = 0;
    _setPulling(false);
    if (_revealed && pixels >= kArchiveRowExtent) hide();
  }

  void hide() {
    if (!_revealed && !_armed) return;
    _revealed = false;
    _armed = false;
    _pullStartedAt = null;
    notifyListeners();
  }

  void _setPulling(bool value) {
    if (_pulling == value) return;
    _pulling = value;
    if (!value) {
      _pull = 0;
      _pullStartedAt = null;
      _armed = false;
    }
    notifyListeners();
  }

  void _track(double pull) {
    _pull = pull;
    if (pull < _pullStartDistance) {
      _pullStartedAt = null;
      _setArmed(false, haptic: touching);
      return;
    }
    final startedAt = _pullStartedAt ??= DateTime.now();
    if (touching) _setArmed(_ready(startedAt, _armDelay), haptic: true);
  }

  bool _ready(DateTime startedAt, Duration minDuration) =>
      _pull / kArchiveRowExtent > _snapFraction &&
      DateTime.now().difference(startedAt) >= minDuration;

  void _setArmed(bool value, {required bool haptic}) {
    if (_armed == value) return;
    _armed = value;
    if (haptic) Haptics.tap();
    notifyListeners();
  }

  void _release() {
    if (!_pulling || _revealed) return;
    final startedAt = _pullStartedAt;
    if (startedAt == null || !_ready(startedAt, _minPullDuration)) {
      _setArmed(false, haptic: false);
      return;
    }
    if (!_armed) Haptics.tap();
    _armed = true;
    _revealed = true;
    notifyListeners();
  }
}

class ArchiveWheelPull {
  ArchiveWheelPull({required TickerProvider vsync, required this.controller}) {
    _ticker = vsync.createTicker(_onTick);
  }

  static const Duration _releaseDelay = Duration(milliseconds: 220);
  static const double _smoothingMs = 60;

  final ArchivePullController controller;
  final ValueNotifier<bool> active = ValueNotifier(false);
  late final Ticker _ticker;
  Drag? _drag;
  double _pending = 0;
  Duration _lastTick = Duration.zero;
  Duration _idle = Duration.zero;

  void start(ScrollPosition position, double delta) {
    if (_drag != null) {
      add(delta);
      return;
    }
    controller.wheelStart();
    _drag = position.drag(DragStartDetails(), _onCanceled);
    _pending = delta;
    _lastTick = Duration.zero;
    _idle = Duration.zero;
    active.value = true;
    _ticker.start();
  }

  void add(double delta) {
    _pending += delta;
    _idle = Duration.zero;
  }

  void _onTick(Duration elapsed) {
    final drag = _drag;
    if (drag == null) return;
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    _idle += dt;
    final keep = math.exp(-dt.inMicroseconds / 1000 / _smoothingMs);
    final step = _pending.abs() < 0.5 ? _pending : _pending * (1 - keep);
    if (step != 0) {
      _pending -= step;
      drag.update(
        DragUpdateDetails(
          globalPosition: Offset.zero,
          delta: Offset(0, step),
          primaryDelta: step,
        ),
      );
    }
    if (_pending == 0 && _idle >= _releaseDelay) _finish(drag);
  }

  void _finish(Drag drag) {
    _stop();
    controller.wheelEnd();
    drag.end(DragEndDetails(primaryVelocity: 0));
  }

  void _onCanceled() {
    if (_drag == null) return;
    _stop();
    controller.wheelEnd();
  }

  void _stop() {
    _ticker.stop();
    _drag = null;
    _pending = 0;
    active.value = false;
  }

  void dispose() {
    _ticker.dispose();
    active.dispose();
  }
}

class SliverArchivePull extends SingleChildRenderObjectWidget {
  const SliverArchivePull({
    super.key,
    required this.controller,
    required Widget super.child,
  });

  final ArchivePullController controller;

  @override
  RenderSliverArchivePull createRenderObject(BuildContext context) =>
      RenderSliverArchivePull(controller);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverArchivePull renderObject,
  ) {
    renderObject.controller = controller;
  }
}

class RenderSliverArchivePull extends RenderSliver
    with RenderObjectWithChildMixin<RenderBox>, RenderSliverHelpers {
  RenderSliverArchivePull(this._controller)
    : _compensatedExtent = _controller.revealed ? kArchiveRowExtent : 0;

  ArchivePullController _controller;
  double _compensatedExtent;

  set controller(ArchivePullController value) {
    if (identical(value, _controller)) return;
    if (attached) _controller.removeListener(markNeedsLayout);
    _controller = value;
    if (attached) _controller.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _controller.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _controller.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    final extent = _controller.revealed ? kArchiveRowExtent : 0.0;
    if (extent != _compensatedExtent) {
      geometry = SliverGeometry(
        scrollOffsetCorrection: extent - _compensatedExtent,
      );
      _compensatedExtent = extent;
      return;
    }
    final showsPull = _controller.pulling || _controller.revealed;
    final overscroll = showsPull && constraints.overlap < 0
        ? math.max(0.0, -constraints.overlap - _controller.pullBase)
        : 0.0;
    final childExtent = extent + overscroll;
    final child = this.child;
    if (child == null || childExtent <= 0) {
      geometry = SliverGeometry.zero;
      return;
    }
    child.layout(
      BoxConstraints.tightFor(
        width: constraints.crossAxisExtent,
        height: childExtent,
      ),
    );
    final visible = math.max(0.0, childExtent - constraints.scrollOffset);
    final paintExtent = math.min(visible, constraints.remainingPaintExtent);
    geometry = SliverGeometry(
      scrollExtent: extent,
      paintOrigin: -overscroll - constraints.scrollOffset,
      paintExtent: paintExtent,
      maxPaintExtent: visible,
      layoutExtent: math.min(
        math.max(0.0, extent - constraints.scrollOffset),
        paintExtent,
      ),
      hasVisualOverflow: constraints.scrollOffset > 0,
    );
  }

  bool get _paintsChild => child != null && geometry!.paintExtent > 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_paintsChild) context.paintChild(child!, offset);
  }

  @override
  bool hitTestChildren(
    SliverHitTestResult result, {
    required double mainAxisPosition,
    required double crossAxisPosition,
  }) {
    if (!_paintsChild) return false;
    return hitTestBoxChild(
      BoxHitTestResult.wrap(result),
      child!,
      mainAxisPosition: mainAxisPosition,
      crossAxisPosition: crossAxisPosition,
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) => 0;

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {}
}

class ArchivePullCell extends StatefulWidget {
  const ArchivePullCell({
    super.key,
    required this.controller,
    required this.pullLabel,
    required this.releaseLabel,
    required this.rowBuilder,
  });

  final ArchivePullController controller;
  final String pullLabel;
  final String releaseLabel;
  final Widget Function(bool avatarVisible) rowBuilder;

  @override
  State<ArchivePullCell> createState() => _ArchivePullCellState();
}

class _ArchivePullCellState extends State<ArchivePullCell>
    with TickerProviderStateMixin {
  late final _PullVisuals _visuals = _PullVisuals(this);
  final _PullTexts _texts = _PullTexts();
  late bool _wasRevealed;
  late bool _wasArmed;
  late bool _wasPulling;

  @override
  void initState() {
    super.initState();
    _remember();
    widget.controller.addListener(_onPullChanged);
    _visuals.settle.addStatusListener(_onSettleStatus);
  }

  @override
  void didUpdateWidget(ArchivePullCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_onPullChanged);
    widget.controller.addListener(_onPullChanged);
    _remember();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPullChanged);
    _visuals.dispose();
    _texts.dispose();
    super.dispose();
  }

  void _remember() {
    final c = widget.controller;
    _wasRevealed = c.revealed;
    _wasArmed = c.armed;
    _wasPulling = c.pulling;
  }

  void _onPullChanged() {
    final c = widget.controller;
    if (c.pulling && !_wasPulling && !c.revealed) _visuals.settle.value = 0;
    if (c.revealed && !_wasRevealed) {
      _visuals.arm(true);
      _visuals.settle.forward(from: 0);
    } else if (!c.revealed && _wasRevealed) {
      _visuals.reset();
    } else if (!c.revealed && c.armed != _wasArmed) {
      _visuals.arm(c.armed);
    }
    _remember();
    setState(() {});
  }

  void _onSettleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final revealed = widget.controller.revealed;
    final foreground = !revealed || _visuals.settle.isAnimating;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: kArchiveRowExtent,
          child: IgnorePointer(
            ignoring: !revealed,
            child: widget.rowBuilder(!foreground),
          ),
        ),
        if (foreground)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ArchivePullPainter(
                  visuals: _visuals,
                  texts: _texts.configure(
                    pullLabel: widget.pullLabel,
                    releaseLabel: widget.releaseLabel,
                    style: DefaultTextStyle.of(
                      context,
                    ).style.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    textScaler: MediaQuery.textScalerOf(context),
                    textDirection: Directionality.of(context),
                    glyphColor: cs.onPrimary,
                  ),
                  idle: (
                    background: cs.surfaceContainerHighest,
                    foreground: cs.onSurfaceVariant,
                  ),
                  active: (background: cs.primary, foreground: cs.onPrimary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PullVisuals {
  _PullVisuals(TickerProvider vsync)
    : arrow = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 250),
      ),
      label = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 170),
      ),
      accentIn = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 230),
      ),
      accentOut = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 230),
        value: 1,
      ),
      settle = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: _settleMs),
      );

  static const int _settleMs = 465;
  static const int _collapseMs = 250;
  static const int _bounceInStartMs = 180;
  static const int _bounceInMs = 150;
  static const int _bounceOutMs = 135;

  final AnimationController arrow;
  final AnimationController label;
  final AnimationController accentIn;
  final AnimationController accentOut;
  final AnimationController settle;
  bool colorized = false;

  late final Listenable repaint = Listenable.merge([
    arrow,
    label,
    accentIn,
    accentOut,
    settle,
  ]);

  double get arrowTurn => Curves.easeInOut.transform(arrow.value);
  double get accentInReach => Curves.easeInQuad.transform(accentIn.value);
  double get accentOutReach => Curves.easeInQuad.transform(accentOut.value);

  double get collapse => Curves.easeOutQuint.transform(
    math.min(1.0, settle.value * _settleMs / _collapseMs),
  );

  double get bounce {
    final ms = settle.value * _settleMs;
    final bounceOutStart = _bounceInStartMs + _bounceInMs;
    if (ms < _bounceInStartMs) return -0.05;
    if (ms < bounceOutStart) {
      final t = (ms - _bounceInStartMs) / _bounceInMs;
      return 0.07 * Curves.easeInOut.transform(t) - 0.05;
    }
    final t = math.min(1.0, (ms - bounceOutStart) / _bounceOutMs);
    return 0.02 * (1 - Curves.easeInOut.transform(t));
  }

  void arm(bool armed) {
    if (armed) {
      arrow.forward();
      label.forward();
    } else {
      arrow.reverse();
      label.reverse();
    }
    if (colorized == armed) return;
    colorized = armed;
    (armed ? accentIn : accentOut).forward(from: 0);
  }

  void reset() {
    arrow.value = 0;
    label.value = 0;
    accentIn.value = 0;
    accentOut.value = 1;
    settle.value = 0;
    colorized = false;
  }

  void dispose() {
    arrow.dispose();
    label.dispose();
    accentIn.dispose();
    accentOut.dispose();
    settle.dispose();
  }
}

typedef _PullPalette = ({Color background, Color foreground});

class _Label {
  const _Label(this.painter, this.scale);

  final TextPainter painter;
  final double scale;
}

class _PullTexts {
  static const double _minLabelScale = 0.8;
  static const double _glyphSize = 24;
  static const int _alphaLevels = 16;

  int version = 0;

  String _pullLabel = '';
  String _releaseLabel = '';
  TextStyle _style = const TextStyle();
  TextScaler _textScaler = TextScaler.noScaling;
  TextDirection _textDirection = TextDirection.ltr;
  Color? _glyphColor;
  double _labelWidth = -1;
  final Map<(bool, Color), _Label> _labels = {};
  TextPainter? _glyph;

  _PullTexts configure({
    required String pullLabel,
    required String releaseLabel,
    required TextStyle style,
    required TextScaler textScaler,
    required TextDirection textDirection,
    required Color glyphColor,
  }) {
    if (pullLabel != _pullLabel ||
        releaseLabel != _releaseLabel ||
        style != _style ||
        textScaler != _textScaler ||
        textDirection != _textDirection) {
      _clearLabels();
      version++;
    }
    if (glyphColor != _glyphColor || textDirection != _textDirection) {
      _glyph?.dispose();
      _glyph = null;
      version++;
    }
    _pullLabel = pullLabel;
    _releaseLabel = releaseLabel;
    _style = style;
    _textScaler = textScaler;
    _textDirection = textDirection;
    _glyphColor = glyphColor;
    return this;
  }

  _Label? label({
    required bool release,
    required Color color,
    required double opacity,
    required double maxWidth,
  }) {
    final level = (opacity.clamp(0.0, 1.0) * _alphaLevels).round();
    if (level == 0) return null;
    if (maxWidth != _labelWidth) {
      _clearLabels();
      _labelWidth = maxWidth;
    }
    final shade = color.withValues(alpha: color.a * level / _alphaLevels);
    return _labels.putIfAbsent((release, shade), () {
      final painter = TextPainter(
        text: TextSpan(
          text: release ? _releaseLabel : _pullLabel,
          style: _style.copyWith(color: shade),
        ),
        textAlign: TextAlign.center,
        textDirection: _textDirection,
        textScaler: _textScaler,
        maxLines: 2,
      )..layout();
      final scale = painter.width <= maxWidth
          ? 1.0
          : math.max(_minLabelScale, maxWidth / painter.width);
      if (painter.width * scale > maxWidth) {
        painter.layout(maxWidth: maxWidth / scale);
      }
      return _Label(painter, scale);
    });
  }

  TextPainter get glyph => _glyph ??= _buildGlyph();

  TextPainter _buildGlyph() {
    const icon = Symbols.archive;
    const fallback = IconThemeData.fallback();
    return TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          color: _glyphColor,
          fontSize: _glyphSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontFamilyFallback: icon.fontFamilyFallback,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
          fontVariations: [
            FontVariation('FILL', fallback.fill!),
            const FontVariation('wght', 500),
            FontVariation('GRAD', fallback.grade!),
            FontVariation('opsz', fallback.opticalSize!),
          ],
        ),
      ),
      textDirection: _textDirection,
    )..layout();
  }

  void _clearLabels() {
    for (final label in _labels.values) {
      label.painter.dispose();
    }
    _labels.clear();
  }

  void dispose() {
    _clearLabels();
    _glyph?.dispose();
  }
}

class _ArchivePullPainter extends CustomPainter {
  _ArchivePullPainter({
    required this.visuals,
    required this.texts,
    required this.idle,
    required this.active,
  }) : textsVersion = texts.version,
       super(repaint: visuals.repaint);

  static const double _rowInset = 20;
  static const double _avatarRadius = 24;
  static const double _handleRadius = 9;
  static const double _handleMargin = 8;
  static const double _handleExtent = _handleRadius * 2 + _handleMargin * 2;
  static const double _handleX = _rowInset + _avatarRadius;
  static const double _labelGap = 12;
  static const double _glyphStartScale = 0.55;
  static const double _trailAlpha = 0.4;
  static const double _labelShift = 8;

  static final Path _arrowPath = Path()
    ..moveTo(9, 4.98)
    ..lineTo(4.95, 9)
    ..lineTo(13.05, 9)
    ..close()
    ..addRect(const Rect.fromLTRB(7.56, 8, 10.44, 11.1));
  static const Offset _arrowCenter = Offset(9, 8.04);

  final _PullVisuals visuals;
  final _PullTexts texts;
  final int textsVersion;
  final _PullPalette idle;
  final _PullPalette active;

  @override
  void paint(Canvas canvas, Size size) {
    final collapse = visuals.collapse;
    final handle = Offset(
      _handleX,
      size.height - _handleMargin - _handleRadius,
    );
    final avatar = Offset(_handleX, size.height - kArchiveRowExtent / 2);
    final appear = (size.height / _handleExtent).clamp(0.0, 1.0);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (collapse > 0) {
      final radius =
          _avatarRadius * (1 + visuals.bounce) +
          (size.width - _avatarRadius) * (1 - collapse);
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: avatar, radius: radius)),
      );
    }
    _paintLayer(canvas, size, idle, handle, appear, collapse);
    final accent = _accentRegion(
      Offset.lerp(handle, avatar, collapse)!,
      size.width,
    );
    if (accent != null) {
      canvas.save();
      canvas.clipPath(accent);
      _paintLayer(canvas, size, active, handle, appear, collapse);
      canvas.restore();
    }
    canvas.restore();

    if (collapse > 0) {
      _paintGlyph(
        canvas,
        Offset.lerp(handle, avatar, collapse)!,
        _glyphStartScale + (1 - _glyphStartScale) * collapse + visuals.bounce,
      );
    }
  }

  Path? _accentRegion(Offset center, double width) {
    final reachIn = visuals.accentInReach;
    final reachOut = visuals.accentOutReach;
    Path circle(double reach) =>
        Path()..addOval(Rect.fromCircle(center: center, radius: width * reach));
    if (visuals.colorized) return reachIn > 0 ? circle(reachIn) : null;
    if (reachIn <= reachOut) return null;
    if (reachOut <= 0) return circle(reachIn);
    return circle(reachIn)
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: center, radius: width * reachOut));
  }

  void _paintLayer(
    Canvas canvas,
    Size size,
    _PullPalette palette,
    Offset handle,
    double appear,
    double collapse,
  ) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    if (size.height > _handleExtent) {
      final fade = 1 - math.min(1.0, collapse * 2);
      final trail = RRect.fromLTRBR(
        _handleX - _handleRadius,
        _handleMargin,
        _handleX + _handleRadius,
        size.height - _handleMargin,
        const Radius.circular(_handleRadius),
      );
      canvas.drawRRect(
        trail,
        Paint()
          ..color = palette.foreground.withValues(
            alpha: palette.foreground.a * _trailAlpha * fade,
          ),
      );
    }
    if (collapse == 0) _paintHandle(canvas, palette, handle, appear);
    _paintLabels(canvas, size, palette, handle.dy, appear);
  }

  void _paintHandle(
    Canvas canvas,
    _PullPalette palette,
    Offset center,
    double appear,
  ) {
    canvas.drawCircle(
      center,
      _handleRadius,
      Paint()
        ..color = palette.foreground.withValues(
          alpha: palette.foreground.a * appear,
        ),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(math.pi * (1 - visuals.arrowTurn));
    canvas.translate(-_arrowCenter.dx, -_arrowCenter.dy);
    canvas.drawPath(_arrowPath, Paint()..color = palette.background);
    canvas.drawPath(
      _arrowPath,
      Paint()
        ..color = palette.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _paintLabels(
    Canvas canvas,
    Size size,
    _PullPalette palette,
    double centerY,
    double appear,
  ) {
    if (appear <= 0) return;
    final maxWidth = math.max(
      0.0,
      size.width - 2 * (_handleX + _handleRadius + _labelGap),
    );
    final swap = visuals.label.value;
    final centerX = size.width / 2;
    final swapping = swap > 0 && swap < 1;
    _paintLabel(
      canvas,
      texts.label(
        release: false,
        color: palette.foreground,
        opacity: (1 - swap) * appear,
        maxWidth: maxWidth,
      ),
      Offset(centerX, centerY + _labelShift * swap),
      scale: swapping ? 0.8 + 0.2 * (1 - swap) : 1,
      pivot: Offset(centerX, centerY + _labelShift * 2 * swap),
    );
    _paintLabel(
      canvas,
      texts.label(
        release: true,
        color: palette.foreground,
        opacity: swap * appear,
        maxWidth: maxWidth,
      ),
      Offset(centerX, centerY + _labelShift * (1 - swap)),
      scale: swapping ? 0.9 + 0.1 * swap : 1,
      pivot: Offset(centerX, centerY - _labelShift * (1 - swap)),
    );
  }

  void _paintLabel(
    Canvas canvas,
    _Label? label,
    Offset center, {
    required double scale,
    required Offset pivot,
  }) {
    if (label == null) return;
    final text = label.painter;
    canvas.save();
    if (scale != 1) {
      canvas.translate(pivot.dx, pivot.dy);
      canvas.scale(scale);
      canvas.translate(-pivot.dx, -pivot.dy);
    }
    canvas.translate(center.dx, center.dy);
    canvas.scale(label.scale);
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }

  void _paintGlyph(Canvas canvas, Offset center, double scale) {
    final glyph = texts.glyph;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArchivePullPainter oldDelegate) =>
      !identical(oldDelegate.visuals, visuals) ||
      !identical(oldDelegate.texts, texts) ||
      oldDelegate.textsVersion != textsVersion ||
      oldDelegate.idle != idle ||
      oldDelegate.active != active;
}
