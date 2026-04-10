import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../backend/modules/messages.dart';
import '../../models/attachment.dart';

enum MessageType { text, attachment, voice }

enum BubbleShape { singleTop, singleBottom, singleMiddle, groupedMiddle }

class MessageBubble extends StatelessWidget {
  static const double photoMaxSize = 280.0;
  static const double photoMinSize = 100.0;
  static const double photoBorderRadius = 12.0;
  static const double bubbleBorderRadius = 20.0;
  static const double captionPaddingHorizontal = 6.0;
  static const double captionPaddingRight = 4.0;
  static const double compactTimePadding = 8.0;

  bool get _hasPhotoWithCaption {
    if (message.attachments == null || message.attachments!.isEmpty)
      return false;
    final hasPhoto = message.attachments!.any((a) => a is PhotoAttachment);
    final hasCaption = message.text != null && message.text!.isNotEmpty;
    return hasPhoto && hasCaption;
  }

  bool get _hasMultiplePhotosNoCaption {
    if (message.attachments == null || message.attachments!.isEmpty)
      return false;
    final photoCount = message.attachments!.whereType<PhotoAttachment>().length;
    final hasCaption = message.text != null && message.text!.isNotEmpty;
    return photoCount >= 2 && !hasCaption;
  }

  final CachedMessage message;
  final bool isMe;
  final int myId;
  final CachedMessage? prevMessage;
  final CachedMessage? nextMessage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.myId,
    this.prevMessage,
    this.nextMessage,
  });

  bool get isGroupedWithNext {
    if (nextMessage == null) return false;
    if (nextMessage!.senderId != message.senderId) return false;
    final timeDiff = nextMessage!.time - message.time;
    return timeDiff < 300000;
  }

  BubbleShape get shape {
    final hasPrevFromMe = prevMessage?.senderId == message.senderId;
    final prevTimeDiff = hasPrevFromMe
        ? message.time - prevMessage!.time
        : 999999999;

    final hasNextFromMe = nextMessage?.senderId == message.senderId;
    final nextTimeDiff = hasNextFromMe
        ? nextMessage!.time - message.time
        : 999999999;

    final bool groupedWithPrev = hasPrevFromMe && prevTimeDiff < 300000;
    final bool groupedWithNext = hasNextFromMe && nextTimeDiff < 300000;

    if (!groupedWithPrev && !groupedWithNext) return BubbleShape.singleMiddle;
    if (!groupedWithPrev && groupedWithNext) return BubbleShape.singleTop;
    if (groupedWithPrev && !groupedWithNext) return BubbleShape.singleBottom;

    return BubbleShape.groupedMiddle;
  }

  MessageType get contentType {
    if (message.attachments != null && message.attachments!.isNotEmpty) {
      final first = message.attachments!.first;
      if (first is ForwardedMessageAttachment) {
        final fwd = first;
        final hasPhoto =
            fwd.originalAttachments != null &&
            fwd.originalAttachments!.any((a) => a is PhotoAttachment);
        return hasPhoto ? MessageType.attachment : MessageType.text;
      }
      if (first is UnknownAttachment) return MessageType.text;
      if (first.type == AttachmentType.audio) return MessageType.voice;
      return MessageType.attachment;
    }

    final payload = message.payload;
    if (payload == null) return MessageType.text;

    final voice = payload['voice'];
    if (voice != null) return MessageType.voice;

    return MessageType.text;
  }

  // скругление уже смешариков т.е сообщений, те которые isme ? .. Это наши, после : это чужие
  BorderRadius get _borderRadius {
    final topRadius = Radius.circular(bubbleBorderRadius);
    final bottomRadius = Radius.circular(bubbleBorderRadius);
    final smallRadius = const Radius.circular(4);

    if (_hasPhotoWithCaption &&
        (shape == BubbleShape.singleTop ||
            shape == BubbleShape.singleMiddle ||
            shape == BubbleShape.singleBottom)) {
      return BorderRadius.only(
        topLeft: topRadius,
        topRight: isMe ? topRadius : topRadius,
        bottomLeft: smallRadius,
        bottomRight: smallRadius,
      );
    }

    if (_hasMultiplePhotosNoCaption &&
        (shape == BubbleShape.singleBottom ||
            shape == BubbleShape.singleMiddle)) {
      return BorderRadius.only(
        topLeft: smallRadius,
        topRight: smallRadius,
        bottomLeft: isMe ? smallRadius : smallRadius,
        bottomRight: isMe ? smallRadius : bottomRadius,
      );
    }

    switch (shape) {
      case BubbleShape.singleTop:
        return BorderRadius.only(
          topLeft: isMe ? topRadius : smallRadius,
          topRight: isMe ? smallRadius : topRadius,
          bottomLeft: smallRadius,
          bottomRight: smallRadius,
        );
      case BubbleShape.singleBottom:
        return BorderRadius.only(
          topLeft: smallRadius,
          topRight: smallRadius,
          bottomLeft: isMe ? topRadius : smallRadius,
          bottomRight: isMe ? smallRadius : topRadius,
        );
      case BubbleShape.singleMiddle:
        return BorderRadius.only(
          topLeft: topRadius,
          topRight: topRadius,
          bottomLeft: isMe ? topRadius : smallRadius,
          bottomRight: isMe ? smallRadius : topRadius,
        );
      case BubbleShape.groupedMiddle:
        return BorderRadius.only(
          topLeft: isMe ? topRadius : smallRadius,
          topRight: isMe ? smallRadius : smallRadius,
          bottomLeft: isMe ? topRadius : smallRadius,
          bottomRight: isMe ? smallRadius : smallRadius,
        );
    }
  }

  // ВРОДЕ отступы между сообщениями, если они выглядят адекватно не трогайте пж я ради них кишку на шею намотал
  // ОТСТУПЫ МЕЖДУ СООБЩЕНИЯМИ (top/bottom margin)
  // Зависит от shape (группировка) И contentType (тип контента)
  double get topMargin {
    switch (contentType) {
      case MessageType.text:
        switch (shape) {
          case BubbleShape.singleTop:
            return 6;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
      case MessageType.attachment:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 6;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
      case MessageType.voice:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
    }
    return 4;
  }

  double get bottomMargin {
    switch (contentType) {
      case MessageType.text:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
      case MessageType.attachment:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
      case MessageType.voice:
        switch (shape) {
          case BubbleShape.singleTop:
            return 1;
          case BubbleShape.singleBottom:
            return 1;
          case BubbleShape.singleMiddle:
            return 4;
          case BubbleShape.groupedMiddle:
            return 1;
        }
    }
    return 4;
  }

  // Внутренний отступ, размеры типа я хз
  EdgeInsets get padding {
    switch (contentType) {
      case MessageType.text:
        switch (shape) {
          case BubbleShape.groupedMiddle:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
          case BubbleShape.singleTop:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
          case BubbleShape.singleBottom:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
          case BubbleShape.singleMiddle:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
        }
      case MessageType.attachment:
        return const EdgeInsets.all(0);
      case MessageType.voice:
        switch (shape) {
          case BubbleShape.groupedMiddle:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 6);
          case BubbleShape.singleTop:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
          case BubbleShape.singleBottom:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
          case BubbleShape.singleMiddle:
            return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
        }
    }
    return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 12,
        right: isMe ? 12 : 60,
        top: topMargin,
        bottom: bottomMargin,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? (isDark ? const Color(0xFF2C5F8D) : const Color(0xFF007AFF))
                : (isDark
                      ? cs.surfaceContainerHighest
                      : const Color(0xFFE9E9EB)),
            borderRadius: _borderRadius,
          ),
          padding: padding,
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (contentType) {
      case MessageType.attachment:
        return _buildAttachmentContent(context);
      case MessageType.voice:
        return _buildVoiceContent(context);
      case MessageType.text:
      default:
        return _buildTextContent(context);
    }
  }

  Widget _buildTextContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final textColor = isMe
        ? Colors.white
        : (isDark ? cs.onSurface : const Color(0xFF1C1C1E));

    final forwarded = _getForwardedAttachment();
    final isForwarded = forwarded != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: isForwarded
              ? _buildForwardedInlineText(context, forwarded, textColor)
              : Text(
                  message.text ?? '',
                  style: TextStyle(color: textColor, fontSize: 16, height: 1.3),
                ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            _formatTime(message.time),
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 10,
            ),
          ),
        ),
        if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(context)],
      ],
    );
  }

  Widget _buildForwardedInlineText(
    BuildContext context,
    ForwardedMessageAttachment forwarded,
    Color textColor,
  ) {
    final cs = Theme.of(context).colorScheme;
    final headerColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : cs.onSurfaceVariant;

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
                backgroundImage: NetworkImage(senderAvatar),
                backgroundColor: cs.primaryContainer,
              )
            else
              CircleAvatar(
                radius: 10,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  displaySender.isNotEmpty
                      ? displaySender[0].toUpperCase()
                      : '?',
                  style: TextStyle(fontSize: 9, color: cs.onPrimaryContainer),
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
            style: TextStyle(color: textColor, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          const SizedBox(height: 2),
          Text(
            message.text ?? '',
            style: TextStyle(color: textColor, fontSize: 16, height: 1.3),
          ),
        ],
      ],
    );
  }

  ForwardedMessageAttachment? _getForwardedAttachment() {
    if (message.attachments == null || message.attachments!.isEmpty)
      return null;
    for (final a in message.attachments!) {
      if (a is ForwardedMessageAttachment) return a;
    }
    return null;
  }

  Widget _buildForwardedHeader(
    BuildContext context,
    ForwardedMessageAttachment forwarded,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final textColor = isMe
        ? Colors.white
        : (isDark ? cs.onSurface : const Color(0xFF1C1C1E));
    final headerColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : (isDark ? cs.onSurfaceVariant : const Color(0xFF8E8E93));

    final senderName = forwarded.originalSenderName;
    final displaySender = senderName ?? forwarded.originalSenderId.toString();
    final origText = forwarded.originalText;
    final hasOrigText = origText != null && origText.isNotEmpty;

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
        if (hasOrigText) ...[
          const SizedBox(height: 2),
          Text(
            origText,
            style: TextStyle(color: textColor, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentContent(BuildContext context) {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) {
      return _buildTextContent(context);
    }

    final first = attachments.first;
    if (first is ForwardedMessageAttachment) {
      final fwd = first;
      final photos = fwd.originalAttachments
          ?.whereType<PhotoAttachment>()
          .toList();
      if (photos != null && photos.isNotEmpty) {
        return _buildForwardedPhotoContent(context, fwd, photos);
      }
      return _buildTextContent(context);
    }

    final photos = attachments.whereType<PhotoAttachment>().toList();
    if (photos.isEmpty) {
      return _buildGenericAttachment(context, attachments.first);
    }

    return _buildPhotoContent(context, photos);
  }

  Widget _buildPhotoContent(BuildContext ctx, List<PhotoAttachment> photos) {
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
            child: _buildCompactTime(ctx),
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
    BuildContext context,
    ForwardedMessageAttachment forwarded,
    List<PhotoAttachment> photos,
  ) {
    final cs = Theme.of(context).colorScheme;
    final headerColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : cs.onSurfaceVariant;
    final senderName = forwarded.originalSenderName;
    final displaySender = senderName ?? forwarded.originalSenderId.toString();
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
                  backgroundImage: NetworkImage(senderAvatar),
                  backgroundColor: cs.primaryContainer,
                )
              else
                CircleAvatar(
                  radius: 10,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    displaySender.isNotEmpty
                        ? displaySender[0].toUpperCase()
                        : '?',
                    style: TextStyle(fontSize: 9, color: cs.onPrimaryContainer),
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
              style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1C1C1E),
                fontSize: 16,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        _buildPhotoContent(context, photos),
      ],
    );
  }

  Widget _buildSinglePhoto(BuildContext ctx, PhotoAttachment photo) {
    final imageUrl = photo.baseUrl ?? '';
    final width = photo.width?.toDouble() ?? 200;
    final height = photo.height?.toDouble() ?? 200;

    final constrainedWidth = width.clamp(photoMinSize, photoMaxSize);
    final constrainedHeight = height.clamp(photoMinSize, photoMaxSize);

    final bool matchTop = _hasPhotoWithCaption;
    final bool matchBottom = !_hasPhotoWithCaption;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(
          matchTop ? bubbleBorderRadius : photoBorderRadius,
        ),
        topRight: Radius.circular(
          matchTop ? bubbleBorderRadius : photoBorderRadius,
        ),
        bottomLeft: Radius.circular(
          matchBottom ? (isMe ? bubbleBorderRadius : 4) : 4,
        ),
        bottomRight: Radius.circular(
          matchBottom ? (isMe ? 4 : bubbleBorderRadius) : 4,
        ),
      ),
      child: Stack(
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              width: constrainedWidth,
              height: constrainedHeight,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(
                ctx,
                constrainedWidth,
                constrainedHeight,
              ),
            )
          else
            _buildPhotoPlaceholder(ctx, constrainedWidth, constrainedHeight),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: () => _openPhotoViewer(ctx, photo)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTwoPhotos(
    BuildContext ctx,
    PhotoAttachment p1,
    PhotoAttachment p2,
  ) {
    final matchTop =
        _hasMultiplePhotosNoCaption && shape == BubbleShape.singleTop;
    final matchBottom =
        _hasMultiplePhotosNoCaption && shape == BubbleShape.singleBottom;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(
          matchTop ? bubbleBorderRadius : photoBorderRadius,
        ),
        topRight: Radius.circular(
          matchTop ? bubbleBorderRadius : photoBorderRadius,
        ),
        bottomLeft: Radius.circular(matchBottom ? 4 : photoBorderRadius),
        bottomRight: Radius.circular(
          matchBottom ? (isMe ? 4 : bubbleBorderRadius) : photoBorderRadius,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPhotoTile(ctx, p1),
          const SizedBox(width: 2),
          _buildPhotoTile(ctx, p2),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(BuildContext ctx, List<PhotoAttachment> photos) {
    final displayCount = photos.length > 4 ? 4 : photos.length;
    final remaining = photos.length - 4;

    final matchTop =
        _hasMultiplePhotosNoCaption && shape == BubbleShape.singleTop;
    final matchBottom =
        _hasMultiplePhotosNoCaption && shape == BubbleShape.singleBottom;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(
          matchTop ? bubbleBorderRadius : photoBorderRadius,
        ),
        topRight: Radius.circular(
          matchTop ? bubbleBorderRadius : photoBorderRadius,
        ),
        bottomLeft: Radius.circular(matchBottom ? 4 : photoBorderRadius),
        bottomRight: Radius.circular(
          matchBottom ? (isMe ? 4 : bubbleBorderRadius) : photoBorderRadius,
        ),
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

  Widget _buildPhotoTile(BuildContext ctx, PhotoAttachment photo) {
    final imageUrl = photo.baseUrl ?? '';
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) =>
                    _buildPhotoPlaceholder(ctx, 100, 100),
              )
            else
              _buildPhotoPlaceholder(ctx, 100, 100),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: () => _openPhotoViewer(ctx, photo)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTileWithOverlay(
    BuildContext ctx,
    PhotoAttachment photo,
    String overlay,
  ) {
    final imageUrl = photo.baseUrl ?? '';
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) =>
                    _buildPhotoPlaceholder(ctx, 100, 100),
              )
            else
              _buildPhotoPlaceholder(ctx, 100, 100),
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
      ),
    );
  }

  Widget _buildPhotoPlaceholder(
    BuildContext ctx,
    double w,
    double h, {
    VoidCallback? onRetry,
  }) {
    final cs = Theme.of(ctx).colorScheme;
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

  Widget _buildCaption(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final textColor = isMe
        ? Colors.white
        : (isDark ? cs.onSurface : const Color(0xFF1C1C1E));

    return Text(
      message.text ?? '',
      style: TextStyle(color: textColor, fontSize: 16, height: 1.3),
    );
  }

  Widget _buildGenericAttachment(
    BuildContext ctx,
    MessageAttachment attachment,
  ) {
    final cs = Theme.of(ctx).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final textColor = isMe
        ? Colors.white
        : (isDark ? cs.onSurface : const Color(0xFF1C1C1E));

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

  Widget _buildVideoAttachment(BuildContext ctx, MessageAttachment video) {
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
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Symbols.videocam,
                  size: 48,
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: () {}),
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

  Widget _buildFileAttachment(BuildContext ctx, MessageAttachment file) {
    final cs = Theme.of(ctx).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final name = (file as dynamic).name as String? ?? 'File';
    final size = (file as dynamic).size as int? ?? 0;
    final sizeStr = _formatFileSize(size);
    final textColor = isMe
        ? Colors.white
        : (isDark ? cs.onSurface : const Color(0xFF1C1C1E));
    final subtitleColor = isMe
        ? Colors.white.withValues(alpha: 0.65)
        : (isDark ? cs.onSurfaceVariant : const Color(0xFF8E8E93));

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
                  ? Colors.white.withValues(alpha: 0.2)
                  : cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Symbols.description,
              color: isMe ? Colors.white : cs.primary,
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
                    color: textColor,
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
                    color: subtitleColor,
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
                    ? Colors.white.withValues(alpha: 0.15)
                    : (isDark
                          ? cs.surfaceContainerHighest
                          : const Color(0xFFE5E5EA)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Symbols.download,
                color: isMe ? Colors.white : cs.primary,
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

  Widget _buildStickerAttachment(BuildContext ctx, MessageAttachment sticker) {
    final preview = (sticker as dynamic).previewData as String? ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(photoBorderRadius),
      child: Stack(
        children: [
          if (preview.isNotEmpty)
            Image.network(
              preview,
              width: 150,
              height: 150,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  _buildPhotoPlaceholder(ctx, 150, 150),
            )
          else
            _buildPhotoPlaceholder(ctx, 150, 150),
        ],
      ),
    );
  }

  void _openPhotoViewer(BuildContext ctx, PhotoAttachment photo) {
    // TODO: Open photo viewer
  }

  Widget _buildVoiceContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final textColor = isMe
        ? Colors.white
        : (isDark ? cs.onSurface : const Color(0xFF1C1C1E));
    final payload = message.payload;
    final voice = payload?['voice'] as Map<String, dynamic>?;
    final duration = voice?['duration'] as int? ?? 0;
    final url = voice?['url']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _VoiceMessageBubble(
          duration: duration,
          url: url,
          textColor: textColor,
          isMe: isMe,
        ),
        const SizedBox(height: 6),
        _buildMeta(context),
      ],
    );
  }

  Widget _buildMeta(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final timeColor = isMe ? Colors.white70 : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            _formatTime(message.time),
            style: TextStyle(color: timeColor, fontSize: 11),
          ),
          if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(context)],
        ],
      ),
    );
  }

  Widget _buildCompactTime(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final isDark = cs.brightness == Brightness.dark;
    final bgColor = isMe
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.5);
    final textColor = Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _formatTime(message.time),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    final status = message.status;
    IconData icon;
    Color color;

    if (status == null || status == 'sending' || status == 'pending') {
      icon = Symbols.check;
      color = Colors.white70;
    } else {
      switch (status) {
        case 'sent':
          icon = Symbols.check;
          color = Colors.white70;
        case 'delivered':
          icon = Symbols.done_all;
          color = Colors.white70;
        case 'read':
          icon = Symbols.done_all;
          color = const Color(0xFF34C759);
        case 'error':
          icon = Symbols.error;
          color = Colors.redAccent;
        default:
          icon = Symbols.check;
          color = Colors.white70;
      }
    }

    return Icon(icon, size: 14, color: color);
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  final int duration;
  final String url;
  final Color textColor;
  final bool isMe;

  const _VoiceMessageBubble({
    required this.duration,
    required this.url,
    required this.textColor,
    required this.isMe,
  });

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  bool _isPlaying = false;
  double _progress = 0.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMe
                    ? Colors.white.withValues(alpha: 0.2)
                    : cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Symbols.pause : Symbols.play_arrow,
                color: widget.isMe ? Colors.white : cs.primary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: widget.isMe
                            ? Colors.white.withValues(alpha: 0.2)
                            : (isDark
                                  ? cs.surfaceContainerHighest
                                  : const Color(0xFFD1D1D6)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _progress.clamp(0.0, 1.0),
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: widget.isMe
                              ? Colors.white.withValues(alpha: 0.5)
                              : cs.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 24,
                      child: Center(
                        child: Text(
                          _formatDuration(widget.duration),
                          style: TextStyle(
                            color: widget.textColor.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  String _formatDuration(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}
