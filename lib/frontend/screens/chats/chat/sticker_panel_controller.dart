import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../core/config/komet_settings.dart';

class StickerPanelController {
  StickerPanelController({
    required TickerProvider vsync,
    required this.onSendTyping,
  }) {
    anim = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 200),
    );
    anim.addStatusListener(_onAnimStatus);
    showPanel.addListener(_onToggle);
  }

  final VoidCallback onSendTyping;

  late final AnimationController anim;
  final ValueNotifier<bool> showPanel = ValueNotifier(false);
  final ValueNotifier<bool> panelHold = ValueNotifier(true);
  double panelHeight = 300;
  Timer? _typingTimer;

  void hide() => showPanel.value = false;

  void _onAnimStatus(AnimationStatus status) {
    final held = status != AnimationStatus.completed;
    if (panelHold.value != held) panelHold.value = held;
  }

  void _onToggle() {
    if (showPanel.value) {
      anim.forward();
      _sendTyping();
      _typingTimer?.cancel();
      _typingTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _sendTyping(),
      );
    } else {
      anim.reverse();
      _typingTimer?.cancel();
      _typingTimer = null;
    }
  }

  void _sendTyping() {
    if (KometSettings.ghostMode.value) return;
    onSendTyping();
  }

  void dispose() {
    _typingTimer?.cancel();
    showPanel.removeListener(_onToggle);
    anim.removeStatusListener(_onAnimStatus);
    anim.dispose();
    showPanel.dispose();
    panelHold.dispose();
  }
}
