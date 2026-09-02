import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class SpringyTap extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final bool enabled;

  const SpringyTap({
    super.key,
    required this.child,
    this.pressedScale = 0.98,
    this.enabled = true,
  });

  @override
  State<SpringyTap> createState() => _SpringyTapState();
}

class _SpringyTapState extends State<SpringyTap>
    with SingleTickerProviderStateMixin {
  static const Duration _pressDelay = Duration(milliseconds: 60);
  static const Duration _pressDuration = Duration(milliseconds: 90);

  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    ratio: 0.85,
    stiffness: 400,
    mass: 1,
  );

  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 1.0,
  );

  Timer? _pressTimer;
  Offset? _downPosition;
  bool _dragged = false;

  @override
  void dispose() {
    _pressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (_dragged) return;
    _controller.stop();
    _controller.animateTo(
      widget.pressedScale,
      duration: _pressDuration,
      curve: Curves.easeOut,
    );
  }

  void _release() {
    _downPosition = null;
    _dragged = false;
    if (_controller.value == 1.0 && !_controller.isAnimating) return;
    _controller.animateWith(
      SpringSimulation(_spring, _controller.value, 1.0, 0),
    );
  }

  void _cancelPending() {
    _pressTimer?.cancel();
    _pressTimer = null;
    _downPosition = null;
    _dragged = false;
  }

  void _onDown(PointerDownEvent event) {
    _pressTimer?.cancel();
    _downPosition = event.position;
    _dragged = false;
    _pressTimer = Timer(_pressDelay, () {
      _pressTimer = null;
      _press();
    });
  }

  void _onMove(PointerMoveEvent event) {
    final start = _downPosition;
    if (start == null || _dragged) return;
    if ((event.position - start).distance > kTouchSlop) {
      _dragged = true;
      _pressTimer?.cancel();
      _pressTimer = null;
      _release();
    }
  }

  void _onUp(PointerUpEvent _) {
    final wasPending = _pressTimer != null;
    _pressTimer?.cancel();
    _pressTimer = null;
    if (wasPending || _dragged) {
      _cancelPending();
      if (_controller.value != 1.0 || _controller.isAnimating) {
        _controller.stop();
        _controller.value = 1.0;
      }
      return;
    }
    _release();
  }

  void _onCancel(PointerCancelEvent _) {
    _pressTimer?.cancel();
    _pressTimer = null;
    if (_controller.value != 1.0 || _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
    _downPosition = null;
    _dragged = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: ScaleTransition(scale: _controller, child: widget.child),
    );
  }
}
