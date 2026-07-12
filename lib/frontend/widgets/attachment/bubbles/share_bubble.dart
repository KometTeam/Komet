import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/link_opener.dart';
import '../../../../models/attachment.dart';
import '../../formatted_message_text.dart';
import 'bubble_context.dart';

class ShareBubble extends StatelessWidget {
  final BubbleContext ctx;
  final ShareAttachment share;

  const ShareBubble({super.key, required this.ctx, required this.share});

  @override
  Widget build(BuildContext context) {
    final isMe = ctx.isMe;
    final message = ctx.message;
    final hasText = message.text != null && message.text!.isNotEmpty;
    final image = share.image;
    final imageUrl = image?.baseUrl ?? image?.previewData ?? '';
    final cardColor = isMe
        ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.08)
        : ctx.cs.surfaceContainerHigh;
    final host =
        share.host ??
        (share.url != null ? Uri.tryParse(share.url!)?.host : null);

    final card = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: share.url == null
          ? null
          : () {
              Haptics.tap();
              openExternalUrl(ctx.context, share.url!);
            },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                width: 280,
                height: 140,
                fit: BoxFit.cover,
                memCacheWidth: 560,
                fadeInDuration: const Duration(milliseconds: 120),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (host != null && host.isNotEmpty) ...[
                    Text(
                      host,
                      style: TextStyle(
                        color: isMe
                            ? ctx.cs.onPrimaryContainer
                            : ctx.cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                  ],
                  if (share.title != null && share.title!.isNotEmpty)
                    Text(
                      share.title!,
                      style: TextStyle(
                        color: ctx.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (share.description != null &&
                      share.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      share.description!,
                      style: TextStyle(
                        color: ctx.dim,
                        fontSize: 13,
                        height: 1.25,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FormattedMessageText(
                    text: message.text!,
                    ranges: message.formatRanges,
                    style: TextStyle(
                      color: ctx.text,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              card,
              ctx.meta(),
            ],
          ),
        ),
      ),
    );
  }
}
