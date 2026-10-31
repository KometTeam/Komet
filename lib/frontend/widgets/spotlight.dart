import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'route_probe.dart';

abstract final class Spotlight {
  static const Duration _pulse = Duration(milliseconds: 1400);
  static const Duration _reveal = Duration(milliseconds: 420);
  static const Duration _press = Duration(milliseconds: 650);
  static const Duration _mountWait = Duration(milliseconds: 700);
  static const Duration _probeWait = Duration(milliseconds: 90);
  static const Duration _probeStep = Duration(milliseconds: 180);
  static const Duration _settleLimit = Duration(milliseconds: 600);
  static const int _probeLimit = 14;
  static const int _steadyFrames = 2;
  static const int _steadyLimit = 60;

  static final Map<String, List<SpotlightTargetState>> _targets = {};
  static final Map<String, List<Completer<void>>> _waiters = {};

  static void _register(String id, SpotlightTargetState state) {
    _targets.putIfAbsent(id, () => []).add(state);
    final waiters = _waiters.remove(id);
    if (waiters == null) return;
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
  }

  static void _unregister(String id, SpotlightTargetState state) {
    final states = _targets[id];
    if (states == null) return;
    states.remove(state);
    if (states.isEmpty) _targets.remove(id);
  }

  static SpotlightTargetState? _visible(String id) {
    final states = _targets[id];
    if (states == null) return null;
    for (final state in states.reversed) {
      if (state.mounted && state._onCurrentRoute) return state;
    }
    return null;
  }

  static Future<SpotlightTargetState?> _await(
    String id,
    Duration within,
  ) async {
    final visible = _visible(id);
    if (visible != null) return visible;
    final waiter = Completer<void>();
    _waiters.putIfAbsent(id, () => []).add(waiter);
    try {
      await waiter.future.timeout(within);
    } on TimeoutException {
      final waiters = _waiters[id];
      waiters?.remove(waiter);
      if (waiters != null && waiters.isEmpty) _waiters.remove(id);
    }
    return _visible(id);
  }

  static Future<SpotlightTargetState?> find(String id) async {
    var state = await _await(id, _mountWait);
    if (state == null) {
      final position = _scrollerFor(id);
      for (
        var i = 0;
        state == null && position != null && i < _probeLimit;
        i++
      ) {
        if (position.pixels >= position.maxScrollExtent) break;
        await position.animateTo(
          math.min(
            position.pixels + position.viewportDimension * 0.8,
            position.maxScrollExtent,
          ),
          duration: _probeStep,
          curve: Curves.easeOut,
        );
        state = await _await(id, _probeWait);
      }
    }
    if (state == null) return null;
    await state._settled();
    await state._steady();
    return state.mounted ? state : null;
  }

  static Future<BuildContext?> reveal(String id) async {
    final state = await find(id);
    if (state == null) return null;
    await state._reveal();
    return state.mounted ? state.context : null;
  }

  static Future<bool> highlight(String id) async {
    final state = await find(id);
    if (state == null) return false;
    await state._reveal();
    if (state.mounted) unawaited(state._pulse());
    return true;
  }

  static Future<bool> tap(String id) async {
    final state = await find(id);
    if (state == null || state.widget.onActivate == null) return false;
    await state._reveal();
    if (!state.mounted) return false;
    return state._press();
  }

  static Future<void> settle() async {
    final binding = SchedulerBinding.instance;
    Duration? start;
    var quiet = 0;
    while (quiet < 2) {
      await binding.endOfFrame;
      final now = binding.currentSystemFrameTimeStamp;
      start ??= now;
      if (now - start > _settleLimit) return;
      quiet = binding.hasScheduledFrame ? 0 : quiet + 1;
    }
  }

  static String _screenOf(String id) {
    final dot = id.indexOf('.');
    return dot < 0 ? id : id.substring(0, dot);
  }

  static ScrollPosition? _scrollerFor(String id) {
    final screen = _screenOf(id);
    for (final MapEntry(key: other, value: states) in _targets.entries) {
      if (_screenOf(other) != screen) continue;
      for (final state in states) {
        if (!state.mounted || !state._onCurrentRoute) continue;
        final position = state._verticalScroller()?.position;
        if (position != null && position.hasContentDimensions) return position;
      }
    }
    return mainScrollPosition();
  }

  static ScrollPosition? mainScrollPosition() {
    final binding = WidgetsBinding.instance;
    final view =
        binding.platformDispatcher.implicitView ??
        binding.platformDispatcher.views.firstOrNull;
    if (view == null) return null;
    final size = view.physicalSize / view.devicePixelRatio;
    final result = HitTestResult();
    binding.hitTestInView(
      result,
      Offset(size.width / 2, size.height * 0.55),
      view.viewId,
    );
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderViewportBase && target.axis == Axis.vertical) {
        final offset = target.offset;
        if (offset is ScrollPosition && offset.hasContentDimensions) {
          return offset;
        }
      }
    }
    return null;
  }
}

class SpotlightTarget extends StatefulWidget {
  const SpotlightTarget({
    super.key,
    required this.id,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.onActivate,
    required this.child,
  });

  final String id;
  final BorderRadius borderRadius;
  final VoidCallback? onActivate;
  final Widget child;

  @override
  State<SpotlightTarget> createState() => SpotlightTargetState();
}

class SpotlightTargetState extends State<SpotlightTarget>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  ModalRoute<Object?>? _route;
  bool _lit = false;

  bool get _onCurrentRoute => _route?.isCurrent ?? true;

  AnimationController get _pulseController => _controller ??=
      AnimationController(vsync: this, duration: Spotlight._pulse);

  @override
  void initState() {
    super.initState();
    Spotlight._register(widget.id, this);
  }

  @override
  void didUpdateWidget(SpotlightTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id == widget.id) return;
    Spotlight._unregister(oldWidget.id, this);
    Spotlight._register(widget.id, this);
  }

  @override
  void dispose() {
    Spotlight._unregister(widget.id, this);
    _controller?.dispose();
    super.dispose();
  }

  ScrollableState? _verticalScroller() {
    var scrollable = context.findAncestorStateOfType<ScrollableState>();
    while (scrollable != null &&
        axisDirectionToAxis(scrollable.axisDirection) != Axis.vertical) {
      scrollable = scrollable.context
          .findAncestorStateOfType<ScrollableState>();
    }
    return scrollable;
  }

  Rect? _globalRect() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _settled() async {
    final animation = _route?.animation;
    if (animation == null || animation.isCompleted) return;
    final done = Completer<void>();
    void listener(AnimationStatus status) {
      if (status.isCompleted && !done.isCompleted) done.complete();
    }

    animation.addStatusListener(listener);
    await done.future.timeout(const Duration(seconds: 1), onTimeout: () {});
    animation.removeStatusListener(listener);
  }

  Future<void> _steady() async {
    Rect? last;
    var still = 0;
    for (
      var frame = 0;
      frame < Spotlight._steadyLimit && still < Spotlight._steadyFrames;
      frame++
    ) {
      await SchedulerBinding.instance.endOfFrame;
      if (!mounted) return;
      final rect = _globalRect();
      still = rect != null && rect == last ? still + 1 : 0;
      last = rect;
    }
  }

  Future<void> _reveal() async {
    if (!mounted) return;
    final still = MediaQuery.disableAnimationsOf(context);
    await Scrollable.ensureVisible(
      context,
      alignment: 0.35,
      duration: still ? Duration.zero : Spotlight._reveal,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _pulse() async {
    setState(() => _lit = true);
    try {
      await _pulseController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) setState(() => _lit = false);
  }

  Future<bool> _press() async {
    setState(() => _lit = true);
    try {
      await _pulseController
          .animateTo(0.5, duration: Spotlight._press)
          .orCancel;
    } on TickerCanceled {
      return false;
    }
    if (!mounted) return false;
    _pulseController.value = 0;
    setState(() => _lit = false);
    widget.onActivate?.call();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return RouteProbe(
      onRoute: (route) => _route = route,
      child: CustomPaint(
        foregroundPainter: _lit && controller != null
            ? _PulsePainter(
                progress: controller,
                color: Theme.of(context).colorScheme.primary,
                borderRadius: widget.borderRadius,
                steady: MediaQuery.disableAnimationsOf(context),
              )
            : null,
        child: widget.child,
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
    required this.steady,
  }) : super(repaint: progress);

  static const int _pulses = 2;

  final Animation<double> progress;
  final Color color;
  final BorderRadius borderRadius;
  final bool steady;

  double get _strength {
    final t = progress.value;
    if (t <= 0 || t >= 1) return 0;
    if (steady) return 1;
    return math.sin((t * _pulses % 1) * math.pi);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final strength = _strength;
    if (strength <= 0) return;
    final rect = borderRadius.toRRect(Offset.zero & size);
    canvas.drawRRect(
      rect,
      Paint()..color = color.withValues(alpha: 0.16 * strength),
    );
    canvas.drawRRect(
      rect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.85 * strength),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.steady != steady ||
      !identical(oldDelegate.progress, progress);
}
