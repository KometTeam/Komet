import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../models/attachment.dart';
import 'bubble_context.dart';

String _forwardedSourceName(ForwardedMessageAttachment forwarded) {
  final resolved =
      forwarded.originalSenderName ??
      ContactCache.get(forwarded.originalSenderId);
  if (resolved != null && resolved.isNotEmpty) return resolved;
  if (forwarded.isChannel) return 'Канал';
  if (forwarded.originalSenderId != 0) {
    return forwarded.originalSenderId.toString();
  }
  return 'Сообщение';
}

String? _forwardedSourceAvatar(ForwardedMessageAttachment forwarded) =>
    forwarded.originalSenderAvatar ??
    ContactCache.getAvatar(forwarded.originalSenderId);

class ForwardedHeader extends StatelessWidget {
  final BubbleContext ctx;
  final ForwardedMessageAttachment forwarded;
  final EdgeInsetsGeometry padding;

  const ForwardedHeader({
    super.key,
    required this.ctx,
    required this.forwarded,
    this.padding = const EdgeInsets.only(left: 8, top: 8, right: 8),
  });

  @override
  Widget build(BuildContext context) {
    final headerColor = ctx.dim;
    final displaySender = _forwardedSourceName(forwarded);
    final senderAvatar = _forwardedSourceAvatar(forwarded);
    final content = Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.forward, size: 14, color: headerColor),
          const SizedBox(width: 4),
          if (senderAvatar != null && senderAvatar.isNotEmpty)
            CircleAvatar(
              radius: 10,
              backgroundImage: CachedNetworkImageProvider(
                senderAvatar,
                maxWidth: 96,
                maxHeight: 96,
              ),
              backgroundColor: ctx.cs.primaryContainer,
            )
          else
            CircleAvatar(
              radius: 10,
              backgroundColor: ctx.cs.primaryContainer,
              child: Text(
                displaySender.isNotEmpty ? displaySender[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 9, color: ctx.cs.onPrimaryContainer),
              ),
            ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              displaySender,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: headerColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    final onTap = ctx.onForwardedSourceTap;
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(forwarded),
      child: content,
    );
  }
}

class ForwardedHeaderFloating extends StatelessWidget {
  final BubbleContext ctx;
  final ForwardedMessageAttachment forwarded;

  const ForwardedHeaderFloating({
    super.key,
    required this.ctx,
    required this.forwarded,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ctx.isMe
          ? ctx.cs.primaryContainer
          : ctx.cs.surfaceContainerHighest,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(18),
      child: ForwardedHeader(
        ctx: ctx,
        forwarded: forwarded,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
