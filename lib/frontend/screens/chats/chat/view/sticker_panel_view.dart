import 'package:flutter/material.dart';

import 'package:komet/frontend/screens/chats/chat/sticker_panel_controller.dart';
import 'package:komet/frontend/widgets/lottie_image.dart';
import 'package:komet/frontend/widgets/sticker_panel.dart';
import 'package:komet/models/animoji.dart';
import 'package:komet/models/sticker.dart';

class StickerPanelView extends StatelessWidget {
  const StickerPanelView({
    super.key,
    required this.stickers,
    required this.onStickerTap,
    this.onEmojiTap,
  });

  final StickerPanelController stickers;
  final void Function(StickerItem sticker) onStickerTap;
  final void Function(Animoji animoji)? onEmojiTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: stickers.anim,
      child: LottieHoldScope(
        isHeld: stickers.panelHold,
        child: StickerPanel(
          height: stickers.panelHeight,
          onStickerTap: onStickerTap,
          onEmojiTap: onEmojiTap,
        ),
      ),
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(
          stickers.anim.value.clamp(0.0, 1.0),
        );
        if (t == 0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: t,
            child: child,
          ),
        );
      },
    );
  }
}
