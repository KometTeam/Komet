import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../models/attachment.dart';
import '../../lottie_image.dart';
import 'bubble_context.dart';

class StickerBubble extends StatelessWidget {
  final BubbleContext ctx;
  final MessageAttachment sticker;

  const StickerBubble({super.key, required this.ctx, required this.sticker});

  @override
  Widget build(BuildContext context) {
    final url = sticker.baseUrl ?? '';
    final preview = sticker.previewData ?? '';
    final staticUrl = url.isNotEmpty ? url : preview;
    final lottieUrl = sticker is StickerAttachment
        ? (sticker as StickerAttachment).lottieUrl
        : null;

    Widget content = Stack(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: LottieImage(
            url: staticUrl,
            lottieUrl: lottieUrl,
            size: 150,
            memCacheWidth: 300,
          ),
        ),
        Positioned(
          bottom: BubbleContext.compactTimePadding,
          right: BubbleContext.compactTimePadding,
          child: _buildStickerMeta(),
        ),
      ],
    );

    final onTap = ctx.onStickerTap;
    if (onTap != null && sticker is StickerAttachment) {
      final s = sticker as StickerAttachment;
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(s),
        child: content,
      );
    }
    return content;
  }

  Widget _buildStickerMeta() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ctx.clockText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (ctx.isMe) ...[
            const SizedBox(width: 3),
            _buildStickerStatusIcon(),
          ],
          if (ctx.message.deleted) ...[
            const SizedBox(width: 3),
            const Icon(Symbols.delete, size: 12, color: Colors.white),
          ],
        ],
      ),
    );
  }

  Widget _buildStickerStatusIcon() {
    final status = ctx.overrideStatus ?? ctx.message.status;
    final v = messageStatusVisual(status, dimColor: Colors.white);
    return Icon(v.icon, size: 13, color: v.color);
  }
}
