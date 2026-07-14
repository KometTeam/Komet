import 'dart:async';

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
    ratio: 0.8,
    stiffness: 350,
    mass: 1,
  );

  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    value: 1.0,
  );

  Timer? _pressTimer;

  @override
  void dispose() {
    _pressTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    _controller.stop();
    _controller.animateTo(
      widget.pressedScale,
      duration: _pressDuration,
      curve: Curves.easeOut,
    );
  }

  void _release() {
    if (_controller.value == 1.0 && !_controller.isAnimating) return;
    _controller.animateWith(
      SpringSimulation(_spring, _controller.value, 1.0, 1.5),
    );
  }

  Future<void> _pulse() async {
    _controller.stop();
    await _controller.animateTo(
      widget.pressedScale,
      duration: _pressDuration,
      curve: Curves.easeOut,
    );
    if (mounted) _release();
  }

  void _onDown(PointerDownEvent _) {
    _pressTimer?.cancel();
    _pressTimer = Timer(_pressDelay, () {
      _pressTimer = null;
      _press();
    });
  }

  void _onUp(PointerUpEvent _) {
    if (_pressTimer != null) {
      _pressTimer!.cancel();
      _pressTimer = null;
      unawaited(_pulse());
    } else {
      _release();
    }
  }

  void _onCancel(PointerCancelEvent _) {
    _pressTimer?.cancel();
    _pressTimer = null;
    _release();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _onDown,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: ScaleTransition(scale: _controller, child: widget.child),
    );
  }
}
