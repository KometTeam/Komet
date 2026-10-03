import 'dart:math' as math;

import 'package:flutter/widgets.dart';

final Set<_ToastObstructionState> _obstructions = {};

class ToastObstruction extends StatefulWidget {
  final Widget child;

  const ToastObstruction({super.key, required this.child});

  @override
  State<ToastObstruction> createState() => _ToastObstructionState();
}

class _ToastObstructionState extends State<ToastObstruction> {
  @override
  void initState() {
    super.initState();
    _obstructions.add(this);
  }

  @override
  void dispose() {
    _obstructions.remove(this);
    super.dispose();
  }

  Rect? rectIn(RenderBox overlay) {
    if (!mounted || !TickerMode.valuesOf(context).enabled) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      Offset.zero & box.size,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

typedef _Placement = ({double left, double right, double clearance});

class ToastBottomPositioned extends StatefulWidget {
  static const double obstructionGap = 10;
  static const Duration _move = Duration(milliseconds: 220);

  final double left;
  final double right;
  final double minBottom;
  final double bandHeight;
  final double minWidth;
  final Widget child;

  const ToastBottomPositioned({
    super.key,
    required this.left,
    required this.right,
    required this.minBottom,
    required this.bandHeight,
    this.minWidth = 240,
    required this.child,
  });

  @override
  State<ToastBottomPositioned> createState() => _ToastBottomPositionedState();
}

class _ToastBottomPositionedState extends State<ToastBottomPositioned> {
  _Placement? _placement;
  double _floor = 0;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  _Placement _measure() {
    final base = (left: widget.left, right: widget.right, clearance: 0.0);
    final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
    if (overlay is! RenderBox || !overlay.hasSize) return base;
    final size = overlay.size;
    const gap = ToastBottomPositioned.obstructionGap;

    final rects = [
      for (final obstruction in _obstructions)
        if (obstruction.rectIn(overlay) case final rect?
            when !rect.isEmpty && rect.center.dy > size.height / 2)
          rect,
    ];
    final wide = rects.where((r) => r.width >= size.width / 2);
    final narrow = rects.where((r) => r.width < size.width / 2).toList();

    var bottom = _floor;
    for (final rect in wide) {
      bottom = math.max(bottom, size.height - rect.top + gap);
    }
    final bandTop = size.height - bottom - widget.bandHeight;
    final bandBottom = size.height - bottom;
    final beside = [
      for (final rect in narrow)
        if (rect.top < bandBottom && rect.bottom > bandTop) rect,
    ];

    var left = widget.left;
    var right = widget.right;
    for (final rect in beside) {
      if (rect.center.dx > size.width / 2) {
        right = math.max(right, size.width - rect.left + gap);
      } else {
        left = math.max(left, rect.right + gap);
      }
    }
    if (size.width - left - right >= widget.minWidth) {
      return (left: left, right: right, clearance: bottom);
    }
    for (final rect in beside) {
      bottom = math.max(bottom, size.height - rect.top + gap);
    }
    return (left: widget.left, right: widget.right, clearance: bottom);
  }

  void _follow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final placement = _measure();
      if (placement != _placement) setState(() => _placement = placement);
      _follow();
    });
  }

  @override
  Widget build(BuildContext context) {
    _floor =
        MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom +
        widget.minBottom;
    final placement = _placement ??= _measure();
    return AnimatedPositioned(
      duration: ToastBottomPositioned._move,
      curve: Curves.easeOutCubic,
      left: placement.left,
      right: placement.right,
      bottom: math.max(_floor, placement.clearance),
      child: widget.child,
    );
  }
}
