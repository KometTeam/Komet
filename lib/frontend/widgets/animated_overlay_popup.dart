import 'package:flutter/material.dart';

import '../../core/config/app_glass_cover.dart';

// #***! по умолчанию любой попап-оверлей перекрывает стеклянный док;
// hint_bubble и прочие «нефуллскрин» переопределяют coversGlass = false
mixin AnimatedOverlayPopup<T extends StatefulWidget>
    on State<T>, TickerProvider {
  bool get coversGlass => true;

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
    if (coversGlass) AppGlassCover.open();
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
    if (coversGlass) AppGlassCover.close();
    _overlayController.dispose();
    super.dispose();
  }
}
