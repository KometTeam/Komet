import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SwipeToPop extends StatefulWidget {
  final Widget child;
  final double edgeWidth;
  final double popThreshold;
  final double velocityThreshold;
  final bool fullWidth;
  final bool enabled;
  final VoidCallback? onPop;

  const SwipeToPop({
    super.key,
    required this.child,
    this.edgeWidth = 28,
    this.popThreshold = 0.35,
    this.velocityThreshold = 700,
    this.fullWidth = false,
    this.enabled = true,
    this.onPop,
  });

  @override
  State<SwipeToPop> createState() => _SwipeToPopState();
}

class _SwipeToPopState extends State<SwipeToPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canPop {
    if (!widget.enabled) return false;
    if (widget.onPop != null) return true;
    final route = ModalRoute.of(context);
    if (route == null) return false;
    return route.canPop;
  }

  void _onDragStart(DragStartDetails _) {
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails d, double width) {
    if (width <= 0) return;
    final next = (_controller.value + d.delta.dx / width).clamp(0.0, 1.0);
    _controller.value = next;
  }

  Future<void> _onDragEnd(DragEndDetails d, double width) async {
    final velocity = d.primaryVelocity ?? 0;
    final pastThreshold = _controller.value > widget.popThreshold ||
        velocity > widget.velocityThreshold;
    if (pastThreshold) {
      final remaining = 1.0 - _controller.value;
      _controller.duration = Duration(
        milliseconds: (remaining * 220).clamp(80, 220).round(),
      );
      await _controller.animateTo(1.0, curve: Curves.easeOutCubic);
      if (!mounted) return;
      if (widget.onPop != null) {
        widget.onPop!();
      } else {
        Navigator.of(context).maybePop();
      }
    } else {
      _controller.duration = const Duration(milliseconds: 200);
      await _controller.animateBack(0.0, curve: Curves.easeOutCubic);
    }
  }

  void _onDragCancel() {
    _controller.duration = const Duration(milliseconds: 200);
    _controller.animateBack(0.0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    if (!_canPop) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gestureChild = GestureDetector(
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
          onHorizontalDragEnd: (d) => _onDragEnd(d, width),
          onHorizontalDragCancel: _onDragCancel,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  return Transform.translate(
                    offset: Offset(t * width, 0),
                    child: Opacity(
                      opacity: (1.0 - t * 0.35).clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: widget.child,
              ),
            ),
            if (widget.fullWidth)
              Positioned.fill(child: gestureChild)
            else
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: widget.edgeWidth,
                child: gestureChild,
              ),
          ],
        );
      },
    );
  }
}
