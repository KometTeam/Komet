import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:komet/main.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../backend/modules/messages.dart';
import '../../core/config/app_bubble_shape.dart';
import '../../core/utils/haptics.dart';
import '../../models/attachment.dart';

enum MessageType { text, attachment, voice, control }

enum BubbleShape { singleTop, singleBottom, singleMiddle, groupedMiddle }

class _BubbleCtx {
  final BuildContext context;
  final ColorScheme cs;
  final Color text;
  final Color dim;
  final BubbleShape shape;
  final MessageType contentType;
  final bool hasPhotoWithCaption;
  final bool hasMultiplePhotosNoCaption;

  _BubbleCtx({
    required this.context,
    required this.cs,
    required this.text,
    required this.shape,
    required this.contentType,
    required this.hasPhotoWithCaption,
    required this.hasMultiplePhotosNoCaption,
  }) : dim = text.withValues(alpha: 0.7);
}

class MessageBubble extends StatelessWidget {
  static const double photoMaxSize = 280.0;
  static const double photoMinSize = 100.0;
  static const double photoBorderRadius = 12.0;
  static const double bubbleBorderRadius = 20.0;
  static const double captionPaddingHorizontal = 6.0;
  static const double captionPaddingRight = 4.0;
  static const double compactTimePadding = 8.0;

  static const Radius _bigRadius = Radius.circular(bubbleBorderRadius);
  static const Radius _smallRadius = Radius.circular(4);
  static const Radius _photoRadius = Radius.circular(photoBorderRadius);

  static Color bubbleTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : Colors.black;

  final CachedMessage message;
  final bool isMe;
  final int myId;
  final CachedMessage? prevMessage;
  final CachedMessage? nextMessage;
  final String chatType;
  final String? overrideStatus;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.myId,
    this.prevMessage,
    this.nextMessage,
    required this.chatType,
    this.overrideStatus,
  });

  bool _computeHasPhotoWithCaption() {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) return false;
    final hasPhoto = attachments.any((a) => a is PhotoAttachment);
    final hasCaption = message.text != null && message.text!.isNotEmpty;
    return hasPhoto && hasCaption;
  }

  bool _computeHasMultiplePhotosNoCaption() {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) return false;
    final photoCount = attachments.whereType<PhotoAttachment>().length;
    final hasCaption = message.text != null && message.text!.isNotEmpty;
    return photoCount >= 2 && !hasCaption;
  }

  BubbleShape _computeShape() {
    if (message.isControl) return BubbleShape.singleMiddle;

    final hasPrevFromMe =
        prevMessage?.senderId == message.senderId && !prevMessage!.isControl;
    final prevTimeDiff =
        hasPrevFromMe ? message.time - prevMessage!.time : 999999999;

    final hasNextFromMe =
        nextMessage?.senderId == message.senderId && !nextMessage!.isControl;
    final nextTimeDiff =
        hasNextFromMe ? nextMessage!.time - message.time : 999999999;

    final groupedWithPrev = hasPrevFromMe && prevTimeDiff < 300000;
    final groupedWithNext = hasNextFromMe && nextTimeDiff < 300000;

    if (!groupedWithPrev && !groupedWithNext) return BubbleShape.singleMiddle;
    if (!groupedWithPrev && groupedWithNext) return BubbleShape.singleTop;
    if (groupedWithPrev && !groupedWithNext) return BubbleShape.singleBottom;
    return BubbleShape.groupedMiddle;
  }

  MessageType _computeContentType() {
    if (message.isControl) return MessageType.control;
    final attachments = message.attachments;
    if (attachments != null && attachments.isNotEmpty) {
      final first = attachments.first;
      if (first is ForwardedMessageAttachment) {
        final fwd = first;
        final hasContact = fwd.originalContact != null;
        final hasPhoto = fwd.originalAttachments != null &&
            fwd.originalAttachments!.any((a) => a is PhotoAttachment);
        final hasOther = fwd.originalAttachments != null &&
            fwd.originalAttachments!.isNotEmpty;
        if (hasContact || hasPhoto || hasOther) return MessageType.attachment;
        return MessageType.text;
      }
      if (first is ContactAttachment) return MessageType.attachment;
      if (first is UnknownAttachment) return MessageType.text;
      if (first.type == AttachmentType.audio) return MessageType.voice;
      return MessageType.attachment;
    }

    final payload = message.payload;
    if (payload == null) return MessageType.text;
    if (payload['voice'] != null) return MessageType.voice;
    return MessageType.text;
  }

  EdgeInsets _paddingFor(MessageType contentType, BubbleShape shape) {
    switch (contentType) {
      case MessageType.text:
        if (shape == BubbleShape.groupedMiddle) {
          return const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
        }
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
      case MessageType.attachment:
        return EdgeInsets.zero;
      case MessageType.voice:
        if (shape == BubbleShape.singleTop ||
            shape == BubbleShape.singleBottom) {
          return const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
        }
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 4);
      case MessageType.control:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 4);
    }
  }

  double _topMarginFor(MessageType contentType, BubbleShape shape) {
    switch (contentType) {
      case MessageType.text:
        switch (shape) {
          case BubbleShape.singleTop:
            return 6;
          case BubbleShape.singleBottom:
          case BubbleShape.groupedMiddle:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
        }
      case MessageType.attachment:
        switch (shape) {
          case BubbleShape.singleBottom:
            return 6;
          case BubbleShape.singleTop:
          case BubbleShape.groupedMiddle:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
        }
      case MessageType.voice:
        return shape == BubbleShape.singleMiddle ? 4 : 1;
      case MessageType.control:
        return 4;
    }
  }

  double _bottomMarginFor(MessageType contentType, BubbleShape shape) {
    switch (contentType) {
      case MessageType.text:
      case MessageType.attachment:
      case MessageType.voice:
        return shape == BubbleShape.singleMiddle ? 4 : 1;
      case MessageType.control:
        return 4;
    }
  }

  BorderRadius _borderRadiusFor(
    BubbleStyle bubbleStyle,
    BubbleShape shape,
    bool hasPhotoWithCaption,
    bool hasMultiplePhotosNoCaption,
  ) {
    final outsideRadius =
        bubbleStyle == BubbleStyle.mobile ? _bigRadius : _smallRadius;

    if (hasPhotoWithCaption &&
        (shape == BubbleShape.singleTop ||
            shape == BubbleShape.singleMiddle ||
            shape == BubbleShape.singleBottom)) {
      return BorderRadius.only(
        topLeft: _bigRadius,
        topRight: _bigRadius,
        bottomLeft: isMe ? _bigRadius : _smallRadius,
        bottomRight: _smallRadius,
      );
    }

    if (hasMultiplePhotosNoCaption &&
        (shape == BubbleShape.singleBottom ||
            shape == BubbleShape.singleMiddle)) {
      return BorderRadius.only(
        topLeft: isMe ? _bigRadius : _smallRadius,
        topRight: _smallRadius,
        bottomLeft: isMe ? _bigRadius : _smallRadius,
        bottomRight: isMe ? _smallRadius : _bigRadius,
      );
    }

    Radius cornerTL = isMe ? outsideRadius : _bigRadius;
    Radius cornerTR = isMe ? _bigRadius : outsideRadius;
    Radius cornerBL = isMe ? outsideRadius : _bigRadius;
    Radius cornerBR = isMe ? _bigRadius : outsideRadius;

    switch (shape) {
      case BubbleShape.singleTop:
        if (isMe) {
          cornerBR = _smallRadius;
        } else {
          cornerBL = _smallRadius;
        }
      case BubbleShape.singleBottom:
        if (isMe) {
          cornerTR = _smallRadius;
        } else {
          cornerTL = _smallRadius;
        }
      case BubbleShape.singleMiddle:
        break;
      case BubbleShape.groupedMiddle:
        if (isMe) {
          cornerTR = _smallRadius;
          cornerBR = _smallRadius;
        } else {
          cornerTL = _smallRadius;
          cornerBL = _smallRadius;
        }
    }

    return BorderRadius.only(
      topLeft: cornerTL,
      topRight: cornerTR,
      bottomLeft: cornerBL,
      bottomRight: cornerBR,
    );
  }

  Widget _buildLeadingAvatar(ColorScheme cs) {
    final senderAvatar = ContactCache.getAvatar(message.senderId);
    final displaySender = ContactCache.get(message.senderId);
    if (senderAvatar != null && senderAvatar.isNotEmpty) {
      return CircleAvatar(
        radius: 15,
        backgroundImage: CachedNetworkImageProvider(senderAvatar, maxWidth: 96, maxHeight: 96),
        backgroundColor: cs.primaryContainer,
      );
    }
    return CircleAvatar(
      radius: 15,
      backgroundColor: cs.primaryContainer,
      child: Text(
        displaySender != null && displaySender.isNotEmpty
            ? displaySender[0].toUpperCase()
            : '?',
        style: TextStyle(fontSize: 9, color: cs.onPrimaryContainer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final contentType = _computeContentType();

    if (message.isControl) {
      const controlShape = BubbleShape.singleMiddle;
      return Padding(
        padding: EdgeInsets.only(
          top: _topMarginFor(contentType, controlShape),
          bottom: _bottomMarginFor(contentType, controlShape),
        ),
        child: Center(child: _buildControlContent(cs)),
      );
    }

    final shape = _computeShape();
    final hasPhotoCap = _computeHasPhotoWithCaption();
    final hasMultiPhotos = _computeHasMultiplePhotosNoCaption();
    final textColor = bubbleTextColor(context);

    final ctx = _BubbleCtx(
      context: context,
      cs: cs,
      text: textColor,
      shape: shape,
      contentType: contentType,
      hasPhotoWithCaption: hasPhotoCap,
      hasMultiplePhotosNoCaption: hasMultiPhotos,
    );

    final topMargin = _topMarginFor(contentType, shape);
    final bottomMargin = _bottomMarginFor(contentType, shape);
    final padding = _paddingFor(contentType, shape);

    final showAvatarSlot = !isMe;
    final showAvatar = showAvatarSlot &&
        chatType == "CHAT" &&
        nextMessage?.senderId != message.senderId &&
        prevMessage?.senderId == message.senderId;

    return GestureDetector(
      onTap: Haptics.tap,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: topMargin,
          bottom: bottomMargin,
        ),
        child: Align(
          child: Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (showAvatar)
                _buildLeadingAvatar(cs)
              else if (showAvatarSlot && chatType != "CHAT")
                const SizedBox(width: 0)
              else if (showAvatarSlot)
                const CircleAvatar(
                  radius: 15,
                  backgroundColor: Color(0x00000000),
                ),
              ValueListenableBuilder<BubbleStyle>(
                valueListenable: AppBubbleShape.current,
                builder: (context, bubbleStyle, child) {
                  return Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: _borderRadiusFor(
                        bubbleStyle,
                        shape,
                        hasPhotoCap,
                        hasMultiPhotos,
                      ),
                    ),
                    padding: padding,
                    child: child,
                  );
                },
                child: _buildContent(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(_BubbleCtx ctx) {
    switch (ctx.contentType) {
      case MessageType.control:
        return _buildControlContent(ctx.cs);
      case MessageType.attachment:
        return _buildAttachmentContent(ctx);
      case MessageType.voice:
        return _buildVoiceContent(ctx);
      case MessageType.text:
        return _buildTextContent(ctx);
    }
  }

  Widget _buildControlContent(ColorScheme cs) {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final control = attachments.first;
    if (control is! ControlAttachment) return const SizedBox.shrink();

    String? text;
    switch (control.event) {
      case 'system':
        text = control.title;
        break;
      case 'new':
        text =
            '${ContactCache.get(message.senderId) ?? 'Пользователь'} создал(а) чат';
        break;
      case 'add':
        final names = (control.userIds ?? [])
            .map((id) => ContactCache.get(id) ?? 'Пользователь')
            .join(', ');
        text =
            '${ContactCache.get(message.senderId) ?? 'Пользователь'} добавил(а) $names';
        break;
      case 'leave':
        text =
            '${ContactCache.get(message.senderId) ?? 'Пользователь'} покинул(а) чат';
        break;
      case 'joinByLink':
        text =
            '${ContactCache.get(message.senderId) ?? 'Пользователь'} присоединился(-ась) к чату';
        break;
      default:
        text = control.title;
    }

    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTextContent(_BubbleCtx ctx) {
    final attachments = message.attachments;
    final isForwardedContact = attachments != null &&
        attachments.isNotEmpty &&
        attachments.first is ForwardedMessageAttachment &&
        (attachments.first as ForwardedMessageAttachment).originalContact !=
            null;

    final forwarded = _getForwardedAttachment();
    final isForwarded = forwarded != null && !isForwardedContact;

    final displaySender = ContactCache.get(message.senderId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.senderId != message.accountId &&
            prevMessage?.senderId != message.senderId &&
            chatType == "CHAT")
          Text(
            displaySender ?? "",
            textAlign: TextAlign.left,
            style: TextStyle(color: ctx.text),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: isForwarded
                  ? _buildForwardedInlineText(ctx, forwarded)
                  : Text(
                      message.text ?? '',
                      style: TextStyle(
                        color: ctx.text,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                message.status == 'EDITED'
                    ? '${_formatTime(message.time)} ред.'
                    : _formatTime(message.time),
                style: TextStyle(color: ctx.dim, fontSize: 10),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 4),
              _buildStatusIcon(ctx),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildForwardedInlineText(
    _BubbleCtx ctx,
    ForwardedMessageAttachment forwarded,
  ) {
    final headerColor = ctx.dim;
    final senderName = forwarded.originalSenderName;
    final displaySender = senderName ?? forwarded.originalSenderId.toString();
    final senderAvatar = forwarded.originalSenderAvatar;
    final origText = forwarded.originalText;
    final hasOrigText = origText != null && origText.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.forward, size: 14, color: headerColor),
            const SizedBox(width: 4),
            if (senderAvatar != null && senderAvatar.isNotEmpty)
              CircleAvatar(
                radius: 10,
                backgroundImage: CachedNetworkImageProvider(senderAvatar, maxWidth: 96, maxHeight: 96),
                backgroundColor: ctx.cs.primaryContainer,
              )
            else
              CircleAvatar(
                radius: 10,
                backgroundColor: ctx.cs.primaryContainer,
                child: Text(
                  displaySender.isNotEmpty
                      ? displaySender[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 9,
                    color: ctx.cs.onPrimaryContainer,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Text(
              displaySender,
              style: TextStyle(
                color: headerColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (hasOrigText) ...[
          const SizedBox(height: 2),
          Text(
            origText,
            style: TextStyle(color: ctx.text, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          const SizedBox(height: 2),
          Text(
            message.text ?? '',
            style: TextStyle(color: ctx.text, fontSize: 16, height: 1.3),
          ),
        ],
      ],
    );
  }

  ForwardedMessageAttachment? _getForwardedAttachment() {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) return null;
    for (final a in attachments) {
      if (a is ForwardedMessageAttachment) return a;
    }
    return null;
  }

  Widget _buildAttachmentContent(_BubbleCtx ctx) {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) {
      return _buildTextContent(ctx);
    }

    final first = attachments.first;
    if (first is ForwardedMessageAttachment) {
      final fwd = first;
      if (fwd.originalContact != null) {
        return _buildForwardedContactContent(ctx, fwd);
      }
      final photos =
          fwd.originalAttachments?.whereType<PhotoAttachment>().toList();
      if (photos != null && photos.isNotEmpty) {
        return _buildForwardedPhotoContent(ctx, fwd, photos);
      }
      final files = fwd.originalAttachments;
      if (files != null && files.isNotEmpty) {
        return _buildForwardedGenericContent(ctx, fwd, files);
      }
      return _buildTextContent(ctx);
    }

    final contacts = attachments.whereType<ContactAttachment>().toList();
    if (contacts.isNotEmpty) {
      return _buildContactAttachment(ctx, contacts.first);
    }

    final photos = attachments.whereType<PhotoAttachment>().toList();
    if (photos.isEmpty) {
      return _buildGenericAttachment(ctx, attachments.first);
    }

    return _buildPhotoContent(ctx, photos);
  }

  Widget _buildPhotoContent(_BubbleCtx ctx, List<PhotoAttachment> photos) {
    final hasCaption = message.text != null && message.text!.isNotEmpty;
    final count = photos.length;

    Widget photosWidget;
    if (count == 1) {
      photosWidget = _buildSinglePhoto(ctx, photos[0]);
    } else if (count == 2) {
      photosWidget = _buildTwoPhotos(ctx, photos[0], photos[1]);
    } else {
      photosWidget = _buildPhotoGrid(ctx, photos);
    }

    if (!hasCaption) {
      return Stack(
        children: [
          photosWidget,
          Positioned(
            bottom: compactTimePadding,
            right: compactTimePadding,
            child: _buildCompactTime(),
          ),
        ],
      );
    }

    if (count == 1) {
      final photo = photos[0];
      final pw = photo.width?.toDouble() ?? 200;
      final photoWidth = pw.clamp(photoMinSize, photoMaxSize);

      return SizedBox(
        width: photoWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            photosWidget,
            Padding(
              padding: const EdgeInsets.only(
                left: captionPaddingHorizontal,
                right: captionPaddingRight,
                bottom: 6,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(child: _buildCaption(ctx)),
                  _buildMeta(ctx),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        photosWidget,
        Padding(
          padding: const EdgeInsets.only(
            left: captionPaddingHorizontal,
            right: captionPaddingRight,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _buildCaption(ctx)),
              _buildMeta(ctx),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForwardedPhotoContent(
    _BubbleCtx ctx,
    ForwardedMessageAttachment forwarded,
    List<PhotoAttachment> photos,
  ) {
    final headerColor = ctx.dim;
    final displaySender =
        forwarded.originalSenderName ?? forwarded.originalSenderId.toString();
    final senderAvatar = forwarded.originalSenderAvatar;
    final hasCaption = message.text != null && message.text!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.forward, size: 14, color: headerColor),
              const SizedBox(width: 4),
              if (senderAvatar != null && senderAvatar.isNotEmpty)
                CircleAvatar(
                  radius: 10,
                  backgroundImage: CachedNetworkImageProvider(senderAvatar, maxWidth: 96, maxHeight: 96),
                  backgroundColor: ctx.cs.primaryContainer,
                )
              else
                CircleAvatar(
                  radius: 10,
                  backgroundColor: ctx.cs.primaryContainer,
                  child: Text(
                    displaySender.isNotEmpty
                        ? displaySender[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 9,
                      color: ctx.cs.onPrimaryContainer,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                displaySender,
                style: TextStyle(
                  color: headerColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
        _buildPhotoContent(ctx, photos),
      ],
    );
  }

  Widget _buildForwardedGenericContent(
    _BubbleCtx ctx,
    ForwardedMessageAttachment forwarded,
    List<MessageAttachment> attachments,
  ) {
    final headerColor = ctx.dim;
    final displaySender =
        forwarded.originalSenderName ?? forwarded.originalSenderId.toString();
    final senderAvatar = forwarded.originalSenderAvatar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.forward, size: 14, color: headerColor),
              const SizedBox(width: 4),
              if (senderAvatar != null && senderAvatar.isNotEmpty)
                CircleAvatar(
                  radius: 10,
                  backgroundImage: CachedNetworkImageProvider(senderAvatar, maxWidth: 96, maxHeight: 96),
                  backgroundColor: ctx.cs.primaryContainer,
                )
              else
                CircleAvatar(
                  radius: 10,
                  backgroundColor: ctx.cs.primaryContainer,
                  child: Text(
                    displaySender.isNotEmpty
                        ? displaySender[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 9,
                      color: ctx.cs.onPrimaryContainer,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                displaySender,
                style: TextStyle(
                  color: headerColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        ...attachments.map((a) {
          if (a is FileAttachment) {
            return _buildFileAttachment(ctx, a);
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  Widget _buildSinglePhoto(_BubbleCtx ctx, PhotoAttachment photo) {
    final imageUrl = photo.baseUrl ?? '';
    final width = photo.width?.toDouble() ?? 200;
    final height = photo.height?.toDouble() ?? 200;

    final constrainedWidth = width.clamp(photoMinSize, photoMaxSize);
    final constrainedHeight = height.clamp(photoMinSize, photoMaxSize);

    final matchTop = ctx.hasPhotoWithCaption;
    final matchBottom = !ctx.hasPhotoWithCaption;

    final topR = matchTop ? _bigRadius : _photoRadius;
    final bottomL =
        matchBottom ? (isMe ? _bigRadius : _smallRadius) : _smallRadius;
    final bottomR =
        matchBottom ? (isMe ? _smallRadius : _bigRadius) : _smallRadius;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: topR,
        topRight: topR,
        bottomLeft: bottomL,
        bottomRight: bottomR,
      ),
      child: Stack(
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              width: constrainedWidth,
              height: constrainedHeight,
              fit: BoxFit.cover,
              memCacheWidth: (constrainedWidth * 2).round(),
              memCacheHeight: (constrainedHeight * 2).round(),
              fadeInDuration: const Duration(milliseconds: 120),
              errorWidget: (_, _, _) => _buildPhotoPlaceholder(
                ctx.cs,
                constrainedWidth,
                constrainedHeight,
              ),
            )
          else
            _buildPhotoPlaceholder(ctx.cs, constrainedWidth, constrainedHeight),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openPhotoViewer(ctx.context, photo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoPhotos(
    _BubbleCtx ctx,
    PhotoAttachment p1,
    PhotoAttachment p2,
  ) {
    final matchTop =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleTop;
    final matchBottom =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleBottom;

    final topR = matchTop ? _bigRadius : _photoRadius;
    final bottomL = matchBottom ? _smallRadius : _photoRadius;
    final bottomR = matchBottom
        ? (isMe ? _smallRadius : _bigRadius)
        : _photoRadius;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: topR,
        topRight: topR,
        bottomLeft: bottomL,
        bottomRight: bottomR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: _buildPhotoTile(ctx, p1)),
          const SizedBox(width: 2),
          Expanded(child: _buildPhotoTile(ctx, p2)),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(_BubbleCtx ctx, List<PhotoAttachment> photos) {
    final displayCount = photos.length > 4 ? 4 : photos.length;
    final remaining = photos.length - 4;

    final matchTop =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleTop;
    final matchBottom =
        ctx.hasMultiplePhotosNoCaption && ctx.shape == BubbleShape.singleBottom;

    final topR = matchTop ? _bigRadius : _photoRadius;
    final bottomL = matchBottom ? _smallRadius : _photoRadius;
    final bottomR = matchBottom
        ? (isMe ? _smallRadius : _bigRadius)
        : _photoRadius;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: topR,
        topRight: topR,
        bottomLeft: bottomL,
        bottomRight: bottomR,
      ),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(displayCount, (i) {
          if (i == 3 && remaining > 0) {
            return _buildPhotoTileWithOverlay(ctx, photos[i], '+$remaining');
          }
          return _buildPhotoTile(ctx, photos[i]);
        }),
      ),
    );
  }

  Widget _buildPhotoTile(_BubbleCtx ctx, PhotoAttachment photo) {
    final imageUrl = photo.baseUrl ?? '';
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: 280,
              memCacheHeight: 280,
              fadeInDuration: const Duration(milliseconds: 120),
              errorWidget: (_, _, _) =>
                  _buildPhotoPlaceholder(ctx.cs, 100, 100),
            )
          else
            _buildPhotoPlaceholder(ctx.cs, 100, 100),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _openPhotoViewer(ctx.context, photo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTileWithOverlay(
    _BubbleCtx ctx,
    PhotoAttachment photo,
    String overlay,
  ) {
    final imageUrl = photo.baseUrl ?? '';
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: 280,
              memCacheHeight: 280,
              fadeInDuration: const Duration(milliseconds: 120),
              errorWidget: (_, _, _) =>
                  _buildPhotoPlaceholder(ctx.cs, 100, 100),
            )
          else
            _buildPhotoPlaceholder(ctx.cs, 100, 100),
          Positioned.fill(
            child: Container(
              color: Colors.black45,
              child: Center(
                child: Text(
                  overlay,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPlaceholder(
    ColorScheme cs,
    double w,
    double h, {
    VoidCallback? onRetry,
  }) {
    return Container(
      width: w,
      height: h,
      color: cs.surfaceContainerHighest,
      child: onRetry != null
          ? Center(
              child: IconButton(
                icon: Icon(Symbols.refresh, color: cs.onSurfaceVariant),
                onPressed: onRetry,
                tooltip: 'Retry',
              ),
            )
          : Center(
              child: Icon(Symbols.image, size: 48, color: cs.onSurfaceVariant),
            ),
    );
  }

  Widget _buildCaption(_BubbleCtx ctx) {
    return Text(
      message.text ?? '',
      style: TextStyle(color: ctx.text, fontSize: 16, height: 1.3),
    );
  }

  Widget _buildGenericAttachment(_BubbleCtx ctx, MessageAttachment attachment) {
    switch (attachment.type) {
      case AttachmentType.video:
        return _buildVideoAttachment(ctx, attachment);
      case AttachmentType.file:
        return _buildFileAttachment(ctx, attachment);
      case AttachmentType.sticker:
        return _buildStickerAttachment(ctx, attachment);
      default:
        return _buildTextContent(ctx);
    }
  }

  Widget _buildVideoAttachment(_BubbleCtx ctx, MessageAttachment video) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(photoBorderRadius),
          child: Stack(
            children: [
              Container(
                width: 200,
                height: 150,
                color: ctx.cs.surfaceContainerHighest,
                child: Icon(
                  Symbols.videocam,
                  size: 48,
                  color: ctx.cs.onSurfaceVariant,
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _buildMeta(ctx),
      ],
    );
  }

  Widget _buildFileAttachment(_BubbleCtx ctx, MessageAttachment file) {
    final name = (file as dynamic).name as String? ?? 'File';
    final size = (file as dynamic).size as int? ?? 0;
    final sizeStr = _formatFileSize(size);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isMe
                  ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.12)
                  : ctx.cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Symbols.description,
              color: isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: ctx.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  sizeStr,
                  style: TextStyle(
                    color: ctx.dim,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isMe
                    ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.12)
                    : ctx.cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.download,
                color: isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} МБ';
  }

  Widget _buildStickerAttachment(_BubbleCtx ctx, MessageAttachment sticker) {
    final url = sticker.baseUrl ?? '';
    final preview = sticker.previewData ?? '';
    final imageUrl = url.isNotEmpty ? url : preview;

    return ClipRRect(
      borderRadius: BorderRadius.circular(photoBorderRadius),
      child: Stack(
        children: [
          if (imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              memCacheWidth: 300,
              memCacheHeight: 300,
              fadeInDuration: const Duration(milliseconds: 120),
              errorWidget: (_, _, _) =>
                  _buildPhotoPlaceholder(ctx.cs, 150, 150),
            )
          else
            _buildPhotoPlaceholder(ctx.cs, 150, 150),
        ],
      ),
    );
  }

  Widget _buildContactAttachment(_BubbleCtx ctx, MessageAttachment contact) {
    final contactData = contact as ContactAttachment;

    final firstName = contactData.firstName ?? '';
    final lastName = contactData.lastName ?? '';
    final hasFirstName = firstName.isNotEmpty;
    final hasLastName = lastName.isNotEmpty;

    final name = (hasFirstName || hasLastName)
        ? '${hasFirstName ? firstName : ''}${hasLastName ? ' $lastName' : ''}'
              .trim()
        : (contactData.name ?? 'Contact');
    final photoUrl = contactData.photoUrl ?? contactData.baseUrl;

    final bgColor = isMe
        ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.12)
        : ctx.cs.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: photoUrl != null && photoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 144,
                      memCacheHeight: 144,
                      fadeInDuration: const Duration(milliseconds: 120),
                      errorWidget: (_, _, _) => Icon(
                        Symbols.person,
                        color: isMe
                            ? ctx.cs.onPrimaryContainer
                            : ctx.cs.primary,
                        size: 24,
                      ),
                    ),
                  )
                : Icon(
                    Symbols.person,
                    color:
                        isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Contact',
                  style: TextStyle(
                    color: ctx.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (contactData.phoneNumber != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    contactData.phoneNumber!,
                    style: TextStyle(
                      color: ctx.dim,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForwardedContactContent(
    _BubbleCtx ctx,
    ForwardedMessageAttachment forwarded,
  ) {
    final contact = forwarded.originalContact!;

    final firstName = contact.firstName ?? '';
    final lastName = contact.lastName ?? '';
    final hasFirstName = firstName.isNotEmpty;
    final hasLastName = lastName.isNotEmpty;

    final name = (hasFirstName || hasLastName)
        ? '${hasFirstName ? firstName : ''}${hasLastName ? ' $lastName' : ''}'
              .trim()
        : (contact.name ?? 'Contact');
    final photoUrl = contact.photoUrl ?? contact.baseUrl;

    final bgColor = isMe
        ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.12)
        : ctx.cs.surfaceContainerHighest;
    final headerColor = ctx.dim;

    final displaySender =
        forwarded.originalSenderName ?? forwarded.originalSenderId.toString();
    final senderAvatar = forwarded.originalSenderAvatar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Symbols.forward, size: 14, color: headerColor),
              const SizedBox(width: 4),
              if (senderAvatar != null && senderAvatar.isNotEmpty)
                CircleAvatar(
                  radius: 10,
                  backgroundImage: CachedNetworkImageProvider(senderAvatar, maxWidth: 96, maxHeight: 96),
                  backgroundColor: ctx.cs.primaryContainer,
                )
              else
                CircleAvatar(
                  radius: 10,
                  backgroundColor: ctx.cs.primaryContainer,
                  child: Text(
                    displaySender.isNotEmpty
                        ? displaySender[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 9,
                      color: ctx.cs.onPrimaryContainer,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                displaySender,
                style: TextStyle(
                  color: headerColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CachedNetworkImage(
                          imageUrl: photoUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 120),
                          errorWidget: (_, _, _) => Icon(
                            Symbols.person,
                            color: isMe
                                ? ctx.cs.onPrimaryContainer
                                : ctx.cs.primary,
                            size: 24,
                          ),
                        ),
                      )
                    : Icon(
                        Symbols.person,
                        color: isMe
                            ? ctx.cs.onPrimaryContainer
                            : ctx.cs.primary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'Contact',
                      style: TextStyle(
                        color: ctx.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.phoneNumber != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.phoneNumber!,
                        style: TextStyle(
                          color: ctx.dim,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openPhotoViewer(BuildContext ctx, PhotoAttachment photo) {
    // TODO: Open photo viewer
  }

  Widget _buildVoiceContent(_BubbleCtx ctx) {
    int duration = 0;
    String url = '';
    String? waveData;
    int? audioId;

    final attaches = message.attachments;
    if (attaches != null && attaches.isNotEmpty) {
      for (final a in attaches) {
        if (a is AudioAttachment) {
          duration = ((a.duration ?? 0) / 1000).round();
          url = a.fileUrl ?? a.baseUrl ?? '';
          waveData = a.waveform;
          audioId = a.audioId;
          break;
        }
      }
    }

    if (duration == 0 && url.isEmpty) {
      final payload = message.payload;
      final voice = payload?['voice'] as Map<String, dynamic>?;
      duration = ((voice?['duration'] as int? ?? 0) / 1000).round();
      url = voice?['url']?.toString() ?? '';
    }

    final cachedTranscription = TranscriptionCache.get(message.id);

    return _VoiceMessageBubble(
      duration: duration,
      url: url,
      textColor: ctx.text,
      isMe: isMe,
      status: overrideStatus ?? message.status,
      time: message.time,
      cs: ctx.cs,
      waveData: waveData,
      chatId: message.chatId,
      messageId: message.id,
      audioId: audioId,
      preloadedText: cachedTranscription?.text,
    );
  }

  Widget _buildMeta(_BubbleCtx ctx) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _formatTime(message.time),
            style: TextStyle(color: ctx.dim, fontSize: 11),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            _buildStatusIcon(ctx),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactTime() {
    final bgColor = isMe
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatTime(message.time),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusIcon(_BubbleCtx ctx) {
    final status = overrideStatus ?? message.status;
    IconData icon;
    Color color;

    switch (status) {
      case 'sending':
      case 'pending':
        icon = Symbols.schedule;
        color = ctx.dim;
      case null:
      case 'sent':
        icon = Symbols.check;
        color = ctx.dim;
      case 'delivered':
        icon = Symbols.done_all;
        color = ctx.dim;
      case 'read':
        icon = Symbols.done_all;
        color = const Color(0xFF4FC3F7);
      case 'error':
        icon = Symbols.error;
        color = Colors.redAccent;
      default:
        icon = Symbols.check;
        color = ctx.dim;
    }

    return Icon(icon, size: 14, color: color);
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  final int duration;
  final String url;
  final Color textColor;
  final bool isMe;
  final String? status;
  final int time;
  final ColorScheme cs;
  final String? waveData;
  final int chatId;
  final String messageId;
  final int? audioId;
  final String? preloadedText;

  const _VoiceMessageBubble({
    required this.duration,
    required this.url,
    required this.textColor,
    required this.isMe,
    this.status,
    required this.time,
    required this.cs,
    this.waveData,
    required this.chatId,
    required this.messageId,
    this.audioId,
    this.preloadedText,
  });

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  bool _isPlaying = false;
  double _progress = 0.0;
  bool _transcriptionVisible = false;
  String? _transcriptionText;
  bool _transcriptionLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedText != null) {
      _transcriptionText = widget.preloadedText;
      _transcriptionVisible = true;
    }
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildStatusIcon() {
    final status = widget.status;
    IconData icon;
    Color color;

    if (status == null || status == 'sent') {
      icon = Symbols.check;
      color = Colors.white54;
    } else {
      switch (status) {
        case 'sending':
        case 'pending':
          icon = Symbols.schedule;
          color = widget.cs.onPrimaryContainer.withValues(alpha: 0.55);
        case 'sent':
          icon = Symbols.check;
          color = widget.cs.onPrimaryContainer.withValues(alpha: 0.55);
        case 'delivered':
          icon = Symbols.done_all;
          color = widget.cs.onPrimaryContainer.withValues(alpha: 0.55);
        case 'read':
          icon = Symbols.done_all;
          color = const Color(0xFF4FC3F7);
        case 'error':
          icon = Symbols.error;
          color = Colors.redAccent;
        default:
          icon = Symbols.check;
          color = widget.cs.onPrimaryContainer.withValues(alpha: 0.55);
      }
    }

    return Icon(icon, size: 14, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final waveInactiveColor = widget.isMe
        ? widget.cs.onPrimaryContainer.withValues(alpha: 0.35)
        : widget.cs.surfaceContainerHighest;
    final waveActiveColor = widget.isMe
        ? widget.cs.onPrimaryContainer.withValues(alpha: 0.7)
        : widget.cs.primary;

    return SizedBox(
      width: 240,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.isMe
                        ? widget.cs.onPrimaryContainer.withValues(alpha: 0.12)
                        : widget.cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Symbols.pause : Symbols.play_arrow,
                    color: widget.isMe
                        ? widget.cs.onPrimaryContainer
                        : widget.cs.primary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapDown: (details) {
                        setState(() {
                          _progress = (details.localPosition.dx /
                                  constraints.maxWidth)
                              .clamp(0.0, 1.0);
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _progress = (details.localPosition.dx /
                                  constraints.maxWidth)
                              .clamp(0.0, 1.0);
                        });
                      },
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: waveInactiveColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: waveActiveColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _requestTranscription,
                child: SizedBox(
                  width: 20,
                  height: 32,
                  child: Center(
                    child: _transcriptionLoading
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: widget.textColor.withValues(alpha: 0.6),
                            ),
                          )
                        : Text(
                            'Т',
                            style: TextStyle(
                              color: widget.textColor.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDuration(widget.duration),
                style: TextStyle(
                  color: widget.textColor.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topLeft,
                  child: _transcriptionVisible
                      ? Text(
                          _transcriptionText ?? '',
                          style: TextStyle(
                            color: widget.textColor.withValues(alpha: 0.8),
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              if (!_transcriptionVisible) ...[
                Text(
                  _formatTime(widget.time),
                  style: TextStyle(
                    color: widget.textColor.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 2),
                  _buildStatusIcon(),
                ],
              ],
            ],
          ),
          if (_transcriptionVisible) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatTime(widget.time),
                  style: TextStyle(
                    color: widget.textColor.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 2),
                  _buildStatusIcon(),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  Future<void> _requestTranscription() async {
    if (widget.audioId == null) return;

    if (_transcriptionVisible && _transcriptionText != null) {
      setState(() {
        _transcriptionVisible = false;
      });
      return;
    }

    if (TranscriptionCache.has(widget.messageId)) {
      final cached = TranscriptionCache.get(widget.messageId)!;
      setState(() {
        _transcriptionText = cached.text ?? 'не удалось распознать текст';
        _transcriptionVisible = true;
      });
      return;
    }

    setState(() {
      _transcriptionLoading = true;
    });

    try {
      final result = await messagesModule.requestTranscription(
        widget.chatId,
        int.tryParse(widget.messageId) ?? 0,
        widget.audioId!,
      );

      TranscriptionCache.put(widget.messageId, result);

      setState(() {
        _transcriptionLoading = false;
        if (result.status == 1) {
          _transcriptionText = (result.text == null || result.text!.isEmpty)
              ? 'не удалось распознать текст'
              : result.text;
          _transcriptionVisible = true;
        } else if (result.status == 0) {
          _transcriptionText = 'транскрибация...';
          _transcriptionVisible = true;
        }
      });
    } catch (e) {
      setState(() {
        _transcriptionLoading = false;
        _transcriptionText = 'ошибка транскрибации';
        _transcriptionVisible = true;
      });
    }
  }
}
