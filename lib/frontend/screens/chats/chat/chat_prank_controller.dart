import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../core/config/app_pranks.dart';
import '../../../../core/utils/haptics.dart';
import '../../../widgets/theme_reveal.dart';

class ChatPrankController {
  ChatPrankController({
    required this.vsync,
    required this.contextOf,
    required this.isMounted,
    required this.onChanged,
  });

  final TickerProvider vsync;
  final BuildContext Function() contextOf;
  final bool Function() isMounted;
  final VoidCallback onChanged;

  final GlobalKey bubbleKey = GlobalKey();
  final GlobalKey captureKey = GlobalKey();

  bool _active = false;
  String? _bubbleId;
  OverlayEntry? _revealEntry;
  AnimationController? _revealController;
  ui.Image? _revealImage;

  bool get active => _active;
  String? get bubbleId => _bubbleId;

  void checkTrigger(CachedMessage msg) {
    if (!AppPranks.current.value || _active || _bubbleId != null) return;
    if ((msg.text ?? '').trim().toUpperCase() != 'THE WORLD') return;
    _bubbleId = msg.id;
    onChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted()) _runReveal();
    });
  }

  ThemeData pinkTheme(ThemeData base) {
    final cs = base.colorScheme;
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFFFF0F5),
      colorScheme: cs.copyWith(
        surface: const Color(0xFFFFF0F5),
        surfaceContainerHigh: const Color(0xFFFFE3EC),
        surfaceContainerHighest: const Color(0xFFFFD9E6),
        primary: const Color(0xFFE8579A),
        primaryContainer: const Color(0xFFFFD6E5),
        onPrimaryContainer: const Color(0xFF7A1F4B),
      ),
    );
  }

  void _runReveal() {
    if (_active) return;
    final context = contextOf();
    final overlay = Navigator.of(context).overlay;
    final captureCtx = captureKey.currentContext;
    final renderObject = captureCtx?.findRenderObject();
    if (overlay == null || renderObject is! RenderRepaintBoundary) {
      _active = true;
      onChanged();
      return;
    }

    Offset center;
    final bubbleBox =
        bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (bubbleBox != null && bubbleBox.attached) {
      center = bubbleBox.localToGlobal(bubbleBox.size.center(Offset.zero));
    } else {
      final size = MediaQuery.sizeOf(context);
      center = Offset(size.width / 2, size.height / 2);
    }

    final ui.Image snapshot;
    try {
      final dpr = math.min(MediaQuery.of(context).devicePixelRatio, 2.0);
      snapshot = renderObject.toImageSync(pixelRatio: dpr);
    } catch (_) {
      _active = true;
      onChanged();
      return;
    }

    dispose();

    final controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 650),
    );
    final entry = ThemeRevealOverlay.build(
      snapshot: snapshot,
      center: center,
      animation: controller,
    );

    _revealController = controller;
    _revealEntry = entry;
    _revealImage = snapshot;

    overlay.insert(entry);
    _active = true;
    onChanged();
    Haptics.success();

    WidgetsBinding.instance.endOfFrame.then((_) {
      if (_revealController != controller) return;
      controller.forward().then((_) {
        if (_revealController != controller) return;
        dispose();
      }, onError: (_) {});
    });
  }

  void dispose() {
    _revealEntry?.remove();
    _revealEntry = null;
    _revealController?.dispose();
    _revealController = null;
    final img = _revealImage;
    _revealImage = null;
    if (img != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => img.dispose());
    }
  }
}
