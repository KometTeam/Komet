import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../models/attachment.dart';
import 'bubble_context.dart';
import 'contact_bubble.dart';
import 'file_bubble.dart';
import 'photo_bubble.dart';
import 'sticker_bubble.dart';

Widget _forwardedHeader(
  BubbleContext ctx,
  ForwardedMessageAttachment forwarded,
) {
  final headerColor = ctx.dim;
  final displaySender =
      forwarded.originalSenderName ??
      ContactCache.get(forwarded.originalSenderId) ??
      forwarded.originalSenderId.toString();
  final senderAvatar =
      forwarded.originalSenderAvatar ??
      ContactCache.getAvatar(forwarded.originalSenderId);
  return Padding(
    padding: const EdgeInsets.only(left: 8, top: 8, right: 8),
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
    final message = ctx.message;
    final hasCaption = message.text != null && message.text!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _forwardedHeader(ctx, forwarded),
        const SizedBox(height: 4),
        if (hasCaption) ...[
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              message.text ?? '',
              style: TextStyle(color: ctx.text, fontSize: 16, height: 1.3),
            ),
          ),
          const SizedBox(height: 6),
        ],
        PhotoBubble(ctx: ctx, photos: photos),
      ],
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
          _forwardedHeader(ctx, forwarded),
          const SizedBox(height: 4),
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
        _forwardedHeader(ctx, forwarded),
        const SizedBox(height: 4),
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
        _forwardedHeader(ctx, forwarded),
        const SizedBox(height: 4),
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
