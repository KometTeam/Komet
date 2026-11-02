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
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final navigationBar = MediaQuery.viewPaddingOf(context).bottom;
    stickers.maxHeight = size.height - padding.top - 160;

    return AnimatedBuilder(
      animation: stickers.layout,
      child: LottieHoldScope(
        isHeld: stickers.panelHold,
        child: StickerPanel(
          searching: stickers.searching,
          onStickerTap: onStickerTap,
          onEmojiTap: onEmojiTap,
          onResize: stickers.resizeBy,
        ),
      ),
      builder: (context, child) {
        final visible = stickers.visibleHeight;
        if (visible <= 0) return const SizedBox.shrink();
        final height = stickers.currentHeight;
        final keyboard = stickers.searching.value
            ? (stickers.keyboardInset.value - navigationBar).clamp(0.0, height)
            : 0.0;
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: visible / height,
            child: SizedBox(
              height: height,
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboard),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
