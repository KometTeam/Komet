import 'package:flutter/material.dart';

mixin AnimatedOverlayPopup<T extends StatefulWidget>
    on State<T>, TickerProvider {
  Duration get overlayForwardDuration;
  Duration get overlayReverseDuration;
  VoidCallback get onOverlayDismiss;

  late final AnimationController _overlayController;
  late final Animation<double> overlayAnimation;

  bool _overlayClosing = false;

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      vsync: this,
      duration: overlayForwardDuration,
      reverseDuration: overlayReverseDuration,
    );
    overlayAnimation = CurvedAnimation(
      parent: _overlayController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _overlayController.forward();
  }

  Future<void> closeOverlay() async {
    if (!mounted || _overlayClosing) return;
    _overlayClosing = true;
    try {
      await _overlayController.reverse();
    } catch (_) {}
    if (!mounted) return;
    onOverlayDismiss();
  }

  @override
  void dispose() {
    _overlayController.dispose();
    super.dispose();
  }
}
