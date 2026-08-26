import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../core/utils/haptics.dart';

@immutable
class FloatingDockGeometry {
  const FloatingDockGeometry({
    required this.bounds,
    required this.size,
    required this.safeArea,
    this.edge = 12,
    this.restingBottomGap = 96,
  });

  final Size bounds;
  final Size size;
  final EdgeInsets safeArea;
  final double edge;
  final double restingBottomGap;

  static const double flingSeconds = 0.09;
  static const double flingThreshold = 320;

  double get minX => edge;
  double get maxX => math.max(minX, bounds.width - size.width - edge);
  double get minY => safeArea.top + edge;
  double get maxY =>
      math.max(minY, bounds.height - size.height - safeArea.bottom - edge);

  Offset get resting => clamp(
    Offset(
      maxX,
      bounds.height - size.height - safeArea.bottom - restingBottomGap,
    ),
  );

  Offset clamp(Offset value) =>
      Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));

  Offset snap(Offset value, Offset velocity) {
    final center = value.dx + size.width / 2;
    final toRight = velocity.dx.abs() > flingThreshold
        ? velocity.dx > 0
        : center >= bounds.width / 2;
    return clamp(
      Offset(toRight ? maxX : minX, value.dy + velocity.dy * flingSeconds),
    );
  }
}

class DraggableFloatingLayer extends StatefulWidget {
  const DraggableFloatingLayer({
    super.key,
    required this.storageKey,
    required this.size,
    required this.child,
    this.onTap,
    this.onDragStart,
    this.onDragEnd,
    this.edge = 12,
    this.restingBottomGap = 96,
  });

  final String storageKey;
  final Size size;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final double edge;
  final double restingBottomGap;

  @override
  State<DraggableFloatingLayer> createState() => _DraggableFloatingLayerState();
}

class _DraggableFloatingLayerState extends State<DraggableFloatingLayer>
    with TickerProviderStateMixin {
  static final Map<String, Offset> _remembered = {};

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 520,
    ratio: 1.0,
  );

  final ValueNotifier<Offset?> _offset = ValueNotifier(null);

  late final AnimationController _settle =
      AnimationController.unbounded(vsync: this)
        ..addListener(_onSettle)
        ..addStatusListener(_onSettleStatus);

  late final AnimationController _lift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    reverseDuration: const Duration(milliseconds: 220),
  );

  FloatingDockGeometry _dock = const FloatingDockGeometry(
    bounds: Size.zero,
    size: Size.zero,
    safeArea: EdgeInsets.zero,
  );

  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  Timer? _resizeSettle;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _offset.value = _remembered[widget.storageKey];
  }

  @override
  void didUpdateWidget(DraggableFloatingLayer old) {
    super.didUpdateWidget(old);
    if (widget.size == old.size || _dragging) return;
    _resizeSettle?.cancel();
    _resizeSettle = Timer(const Duration(milliseconds: 90), _redock);
  }

  @override
  void dispose() {
    _resizeSettle?.cancel();
    _settle.dispose();
    _lift.dispose();
    _offset.dispose();
    super.dispose();
  }

  Offset get _current => _dock.clamp(_offset.value ?? _dock.resting);

  void _redock() {
    if (!mounted || _dragging || _dock.bounds.isEmpty) return;
    _animateTo(_dock.snap(_current, Offset.zero), Offset.zero);
  }

  void _animateTo(Offset target, Offset velocity) {
    final start = _current;
    final delta = target - start;
    final distance = delta.distance;
    if (distance < 0.5) {
      _apply(target);
      return;
    }
    final along =
        (velocity.dx * delta.dx + velocity.dy * delta.dy) /
        (distance * distance);
    _from = start;
    _to = target;
    _settle.stop();
    _settle.value = 0;
    _settle.animateWith(
      SpringSimulation(_spring, 0, 1, along.clamp(-12.0, 12.0)),
    );
  }

  void _onSettle() => _apply(Offset.lerp(_from, _to, _settle.value)!);

  void _onSettleStatus(AnimationStatus status) {
    if (status.isAnimating) return;
    _apply(_to);
  }

  void _apply(Offset value) {
    final position = _dock.clamp(value);
    _offset.value = position;
    _remembered[widget.storageKey] = position;
  }

  void _onPanStart(DragStartDetails details) {
    _settle.stop();
    _resizeSettle?.cancel();
    _dragging = true;
    _lift.forward();
    Haptics.selection();
    widget.onDragStart?.call();
  }

  void _onPanUpdate(DragUpdateDetails details) =>
      _apply(_current + details.delta);

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond;
    _dragging = false;
    _lift.reverse();
    widget.onDragEnd?.call();
    _animateTo(_dock.snap(_current, velocity), velocity);
  }

  void _onPanCancel() {
    if (!_dragging) return;
    _dragging = false;
    _lift.reverse();
    widget.onDragEnd?.call();
    _redock();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _dock = FloatingDockGeometry(
          bounds: constraints.biggest,
          size: widget.size,
          safeArea: MediaQuery.paddingOf(context),
          edge: widget.edge,
          restingBottomGap: widget.restingBottomGap,
        );
        return ValueListenableBuilder<Offset?>(
          valueListenable: _offset,
          child: RepaintBoundary(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onPanCancel: _onPanCancel,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1, end: 1.06).animate(
                  CurvedAnimation(parent: _lift, curve: Curves.easeOutCubic),
                ),
                child: widget.child,
              ),
            ),
          ),
          builder: (context, offset, child) {
            final position = _dock.clamp(offset ?? _dock.resting);
            return Stack(
              children: [Transform.translate(offset: position, child: child)],
            );
          },
        );
      },
    );
  }
}
