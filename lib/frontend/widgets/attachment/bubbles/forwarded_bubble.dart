import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../models/attachment.dart';
import '../../formatted_message_text.dart';
import 'bubble_context.dart';
import 'contact_bubble.dart';
import 'file_bubble.dart';
import 'photo_bubble.dart';
import 'sticker_bubble.dart';

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

Widget buildForwardedMessageText(
  BubbleContext ctx,
  ForwardedMessageAttachment forwarded, {
  double fontSize = 14,
}) {
  final text = forwarded.originalText ?? '';
  final style = TextStyle(color: ctx.text, fontSize: fontSize, height: 1.3);
  if (FormattedMessageText.isFormatted(text, forwarded.originalFormatRanges)) {
    return FormattedMessageText(
      text: text,
      ranges: forwarded.originalFormatRanges,
      style: style,
    );
  }
  return Text(text, style: style);
}

class ForwardedPhotoBubble extends StatelessWidget {
  final BubbleContext ctx;
  final ForwardedMessageAttachment forwarded;
  final List<PhotoAttachment> photos;

  const ForwardedPhotoBubble({
    super.key,
    required this.ctx,
    required this.forwarded,
    required this.photos,
  });

  @override
  Widget build(BuildContext context) {
    final hasCaption = forwarded.originalText?.isNotEmpty ?? false;

    return SizedBox(
      width: PhotoBubble.layoutWidth(photos),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ForwardedHeader(ctx: ctx, forwarded: forwarded),
          const SizedBox(height: 4),
          PhotoBubble(
            ctx: ctx,
            photos: photos,
            caption: hasCaption
                ? buildForwardedMessageText(ctx, forwarded, fontSize: 16)
                : null,
            hasContentAbove: true,
          ),
        ],
      ),
    );
  }
}

class ForwardedGenericBubble extends StatelessWidget {
  final BubbleContext ctx;
  final ForwardedMessageAttachment forwarded;
  final List<MessageAttachment> attachments;

  const ForwardedGenericBubble({
    super.key,
    required this.ctx,
    required this.forwarded,
    required this.attachments,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ForwardedHeader(ctx: ctx, forwarded: forwarded),
          const SizedBox(height: 4),
          if (forwarded.originalText?.isNotEmpty ?? false) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: buildForwardedMessageText(ctx, forwarded),
            ),
            const SizedBox(height: 6),
          ],
          ...attachments.map((a) {
            if (a is FileAttachment) {
              return FileBubble(ctx: ctx, file: a, fill: true);
            }
            if (a is StickerAttachment) {
              return StickerBubble(ctx: ctx, sticker: a);
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}

class ForwardedStickerBubble extends StatelessWidget {
  final BubbleContext ctx;
  final ForwardedMessageAttachment forwarded;
  final MessageAttachment sticker;

  const ForwardedStickerBubble({
    super.key,
    required this.ctx,
    required this.forwarded,
    required this.sticker,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ForwardedHeader(ctx: ctx, forwarded: forwarded),
        const SizedBox(height: 4),
        if (forwarded.originalText?.isNotEmpty ?? false) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: buildForwardedMessageText(ctx, forwarded),
          ),
          const SizedBox(height: 6),
        ],
        StickerBubble(ctx: ctx, sticker: sticker),
      ],
    );
  }
}

class ForwardedContactBubble extends StatelessWidget {
  final BubbleContext ctx;
  final ForwardedMessageAttachment forwarded;

  const ForwardedContactBubble({
    super.key,
    required this.ctx,
    required this.forwarded,
  });

  @override
  Widget build(BuildContext context) {
    final contact = forwarded.originalContact!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ForwardedHeader(ctx: ctx, forwarded: forwarded),
        const SizedBox(height: 4),
        if (forwarded.originalText?.isNotEmpty ?? false) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: buildForwardedMessageText(ctx, forwarded),
          ),
          const SizedBox(height: 6),
        ],
        buildContactCard(
          ctx,
          firstName: contact.firstName,
          lastName: contact.lastName,
          name: contact.name,
          photoUrl: contact.photoUrl ?? contact.baseUrl,
          phoneNumber: contact.phoneNumber,
        ),
      ],
    );
  }
}
