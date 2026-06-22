import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:komet/main.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../backend/modules/messages.dart';
import '../../core/config/app_bubble_behavior.dart';
import '../../core/config/app_bubble_shape.dart';
import '../../core/config/komet_settings.dart';
import '../../core/utils/bubble_radius.dart';
import '../../core/utils/format.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/file_download.dart';
import '../../core/utils/media_cache.dart';
import '../../core/utils/download_progress.dart';
import '../../core/utils/link_opener.dart';
import '../../core/config/app_link_preview.dart';
import 'custom_notification.dart';
import 'link_text.dart';
import '../../models/attachment.dart';
import 'poll_view.dart';
import 'photo_viewer.dart';
import 'video_player_screen.dart';

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
  final Map? reactionInfo;

  _BubbleCtx({
    required this.context,
    required this.cs,
    required this.text,
    required this.shape,
    required this.contentType,
    required this.hasPhotoWithCaption,
    required this.hasMultiplePhotosNoCaption,
    this.reactionInfo,
  }) : dim = text.withValues(alpha: 0.7);
}

final Expando<MessageType> _contentTypeCache = Expando<MessageType>();
final Expando<({bool full, String text})> _clockTextCache = Expando();

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

  static final Color _reactionChipBg = Colors.black.withValues(alpha: 0.18);
  static const BorderRadius _reactionChipRadius = BorderRadius.all(
    Radius.circular(10),
  );

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
  final ValueListenable<Map<String, dynamic>?>? reactionsListenable;
  final ValueListenable<List<double>>? uploadProgress;
  final void Function(String messageId)? onReplyTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.myId,
    this.prevMessage,
    this.nextMessage,
    required this.chatType,
    this.overrideStatus,
    this.reactionsListenable,
    this.uploadProgress,
    this.onReplyTap,
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
    final prevTimeDiff = hasPrevFromMe
        ? message.time - prevMessage!.time
        : 999999999;

    final hasNextFromMe =
        nextMessage?.senderId == message.senderId && !nextMessage!.isControl;
    final nextTimeDiff = hasNextFromMe
        ? nextMessage!.time - message.time
        : 999999999;

    final groupedWithPrev = hasPrevFromMe && prevTimeDiff < 300000;
    final groupedWithNext = hasNextFromMe && nextTimeDiff < 300000;

    if (!groupedWithPrev && !groupedWithNext) return BubbleShape.singleMiddle;
    if (!groupedWithPrev && groupedWithNext) return BubbleShape.singleTop;
    if (groupedWithPrev && !groupedWithNext) return BubbleShape.singleBottom;
    return BubbleShape.groupedMiddle;
  }

  bool get _hasShareAttachment {
    final a = message.attachments;
    return a != null && a.isNotEmpty && a.first is ShareAttachment;
  }

  MessageType get _contentType {
    if (_hasShareAttachment) return _computeContentType();
    return _contentTypeCache[message] ??= _computeContentType();
  }

  String get _clockText {
    final full = KometSettings.fullTimestamp.value;
    final cached = _clockTextCache[message];
    if (cached != null && cached.full == full) return cached.text;
    final text = formatClock(
      DateTime.fromMillisecondsSinceEpoch(message.time),
      withSeconds: full,
    );
    _clockTextCache[message] = (full: full, text: text);
    return text;
  }

  MessageType _computeContentType() {
    if (message.isControl) return MessageType.control;
    final attachments = message.attachments;
    if (attachments != null && attachments.isNotEmpty) {
      final first = attachments.first;
      if (first is ForwardedMessageAttachment) {
        final fwd = first;
        final hasContact = fwd.originalContact != null;
        final hasPhoto =
            fwd.originalAttachments != null &&
            fwd.originalAttachments!.any((a) => a is PhotoAttachment);
        final hasOther =
            fwd.originalAttachments != null &&
            fwd.originalAttachments!.isNotEmpty;
        if (hasContact || hasPhoto || hasOther) return MessageType.attachment;
        return MessageType.text;
      }
      if (first is ContactAttachment) return MessageType.attachment;
      if (first is UnknownAttachment) return MessageType.text;
      if (first.type == AttachmentType.audio) return MessageType.voice;
      if (first is ShareAttachment) {
        return AppLinkPreview.current.value
            ? MessageType.attachment
            : MessageType.text;
      }
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
    BubbleBehavior bubbleBehavior,
    BubbleShape shape,
    bool hasPhotoWithCaption,
    bool hasMultiplePhotosNoCaption,
  ) {
    final isTop =
        shape == BubbleShape.singleTop || shape == BubbleShape.singleMiddle;
    final isBottom =
        shape == BubbleShape.singleBottom || shape == BubbleShape.singleMiddle;
    return computeBubbleRadius(
      isMe: isMe,
      isTop: isTop,
      isBottom: isBottom,
      style: bubbleStyle,
      behavior: bubbleBehavior,
      hasPhotoWithCaption: hasPhotoWithCaption,
      hasMultiplePhotosNoCaption: hasMultiplePhotosNoCaption,
    );
  }

  Widget _buildLeadingAvatar(ColorScheme cs) {
    final senderAvatar = ContactCache.getAvatar(message.senderId);
    final displaySender = ContactCache.get(message.senderId);
    if (senderAvatar != null && senderAvatar.isNotEmpty) {
      return CircleAvatar(
        radius: 15,
        backgroundImage: CachedNetworkImageProvider(
          senderAvatar,
          maxWidth: 96,
          maxHeight: 96,
        ),
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
    if (_hasShareAttachment) {
      return ValueListenableBuilder<bool>(
        valueListenable: AppLinkPreview.current,
        builder: (context, _, _) => _buildBubble(context),
      );
    }
    return _buildBubble(context);
  }

  Widget _buildBubble(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final contentType = _contentType;

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

    final topMargin = _topMarginFor(contentType, shape);
    final bottomMargin = _bottomMarginFor(contentType, shape);
    final padding = _paddingFor(contentType, shape);

    final showAvatarSlot = !isMe;
    final showAvatar =
        showAvatarSlot &&
        chatType == "CHAT" &&
        nextMessage?.senderId != message.senderId;

    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.75;
    final bubbleColor = isMe ? cs.primaryContainer : cs.surfaceContainerHighest;

    _BubbleCtx makeCtx() => _BubbleCtx(
      context: context,
      cs: cs,
      text: textColor,
      shape: shape,
      contentType: contentType,
      hasPhotoWithCaption: hasPhotoCap,
      hasMultiplePhotosNoCaption: hasMultiPhotos,
      reactionInfo: _resolveReactionInfo(),
    );

    final Widget bubbleContent =
        reactionsListenable != null && contentType == MessageType.text
        ? ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: reactionsListenable!,
            builder: (context, _, _) => _buildContent(makeCtx()),
          )
        : _buildContent(makeCtx());

    final reactionsUnder = _reactionsUnderBubble(contentType);
    final reactionsInside = contentType != MessageType.text && !reactionsUnder;

    final reply = message.replyInfo;
    Widget withReply(Widget content) {
      if (reply == null) return content;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReplyQuote(context, cs, textColor, reply),
          const SizedBox(height: 4),
          content,
        ],
      );
    }

    return Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: topMargin,
          bottom: bottomMargin,
        ),
        child: Align(
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
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
              Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      AppBubbleShape.current,
                      AppBubbleBehavior.current,
                    ]),
                    builder: (context, child) => Container(
                      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: _borderRadiusFor(
                          AppBubbleShape.current.value,
                          AppBubbleBehavior.current.value,
                          shape,
                          hasPhotoCap,
                          hasMultiPhotos,
                        ),
                      ),
                      padding: padding,
                      child: child,
                    ),
                    child: withReply(
                      reactionsInside
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [bubbleContent, _reactionsBar(cs)],
                            )
                          : bubbleContent,
                    ),
                  ),
                  if (reactionsUnder) _reactionsBar(cs),
                ],
              ),
            ],
          ),
        ),
      );
  }

  Map? _resolveReactionInfo() {
    if (reactionsListenable != null) {
      final v = reactionsListenable!.value;
      if (v != null) return v;
    }
    final info = message.payload?['reactionInfo'];
    if (info is Map) return info;
    return null;
  }

  bool _reactionsUnderBubble(MessageType contentType) {
    if (contentType != MessageType.attachment) return false;
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) return false;
    if (attachments.first is ForwardedMessageAttachment) return false;
    if (attachments.any((a) => a is ContactAttachment)) return false;
    if (attachments.whereType<PhotoAttachment>().length >= 2) return false;
    return true;
  }

  Widget _reactionsBar(ColorScheme cs) {
    final listenable = reactionsListenable;
    if (listenable != null) {
      return ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: listenable,
        builder: (context, info, _) => _buildReactionsBarFor(cs, info),
      );
    }
    return _buildReactionsBar(cs);
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

  Widget _buildReactionsBar(ColorScheme cs) {
    final info = message.payload?['reactionInfo'];
    return _buildReactionsBarFor(cs, info is Map ? info : null);
  }

  Widget _buildReactionsBarFor(ColorScheme cs, Map? info) {
    final chips = _buildReactionChipsFor(cs, info);
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(spacing: 4, runSpacing: 4, children: chips),
    );
  }

  List<Widget> _buildReactionChipsFor(ColorScheme cs, Map? info) {
    if (info == null) return const [];
    final counters = info['counters'];
    if (counters is! List || counters.isEmpty) return const [];
    final yourReaction = info['yourReaction']?.toString();

    final chips = <Widget>[];
    for (final c in counters) {
      if (c is! Map) continue;
      final reaction = c['reaction']?.toString();
      final count = c['count'];
      if (reaction == null || reaction.isEmpty) continue;
      final isYours = yourReaction == reaction;
      chips.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isYours
                ? cs.primary.withValues(alpha: 0.22)
                : _reactionChipBg,
            borderRadius: _reactionChipRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(reaction, style: const TextStyle(fontSize: 13)),
              if (count is int && count > 1) ...[
                const SizedBox(width: 3),
                Text(
                  count.toString(),
                  style: TextStyle(
                    color: isYours ? cs.primary : cs.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return chips;
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
    final isForwardedContact =
        attachments != null &&
        attachments.isNotEmpty &&
        attachments.first is ForwardedMessageAttachment &&
        (attachments.first as ForwardedMessageAttachment).originalContact !=
            null;

    final forwarded = _getForwardedAttachment();
    final isForwarded = forwarded != null && !isForwardedContact;

    final displaySender = ContactCache.get(message.senderId);

    final reactionChips = _buildReactionChipsFor(ctx.cs, ctx.reactionInfo);
    final hasReactions = reactionChips.isNotEmpty;

    final textStyle = TextStyle(color: ctx.text, fontSize: 16, height: 1.3);
    final textWidget = isForwarded
        ? _buildForwardedInlineText(ctx, forwarded)
        : (LinkText.hasLinks(message.text)
              ? LinkText(text: message.text!, style: textStyle)
              : Text(message.text ?? '', style: textStyle));

    final metaWidget = Text(
      message.status == 'EDITED' ? '$_clockText ред.' : _clockText,
      style: TextStyle(color: ctx.dim, fontSize: 10),
    );

    final showSender =
        message.senderId != message.accountId &&
        prevMessage?.senderId != message.senderId &&
        chatType == "CHAT";

    if (hasReactions) {
      return IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSender)
              Text(
                displaySender ?? "",
                textAlign: TextAlign.left,
                style: TextStyle(color: ctx.text),
              ),
            textWidget,
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: reactionChips,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: metaWidget,
                ),
                if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(ctx)],
                if (message.deleted) ...[
                  const SizedBox(width: 4),
                  _buildDeletedIcon(ctx),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSender)
          Text(
            displaySender ?? "",
            textAlign: TextAlign.left,
            style: TextStyle(color: ctx.text),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: textWidget),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: metaWidget,
            ),
            if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(ctx)],
            if (message.deleted) ...[
              const SizedBox(width: 4),
              _buildDeletedIcon(ctx),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildReplyQuote(
    BuildContext context,
    ColorScheme cs,
    Color textColor,
    ReplyInfo reply,
  ) {
    final accent = isMe ? cs.onPrimaryContainer : cs.primary;
    final name = reply.senderId == myId
        ? 'Вы'
        : (ContactCache.get(reply.senderId) ?? 'Сообщение');
    final preview = reply.previewText();

    final quote = Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: accent.withValues(alpha: 0.10),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (preview.isNotEmpty)
            Text(
              preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
        ],
      ),
    );

    final mid = reply.messageId;
    final cb = onReplyTap;
    if (mid != null && mid != '0' && cb != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => cb(mid),
        child: quote,
      );
    }
    return quote;
  }

  Widget _buildForwardedInlineText(
    _BubbleCtx ctx,
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

  Widget _buildForwardedHeader(
    _BubbleCtx ctx,
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
      final photos = fwd.originalAttachments
          ?.whereType<PhotoAttachment>()
          .toList();
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

    final polls = attachments.whereType<PollAttachment>().toList();
    if (polls.isNotEmpty) {
      return _buildPollAttachment(ctx, polls.first);
    }

    final shares = attachments.whereType<ShareAttachment>().toList();
    if (shares.isNotEmpty) {
      return _buildShareContent(ctx, shares.first);
    }

    final photos = attachments.whereType<PhotoAttachment>().toList();
    if (photos.isEmpty) {
      return _buildGenericAttachment(ctx, attachments.first);
    }

    return _buildPhotoContent(ctx, photos);
  }

  Widget _buildPollAttachment(_BubbleCtx ctx, PollAttachment poll) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PollView(
              chatId: message.chatId,
              messageId: message.id,
              pollId: poll.pollId,
              myId: myId,
              fallbackTitle: poll.title ?? message.text,
              textColor: ctx.text,
              dimColor: ctx.dim,
              accentColor: isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary,
            ),
            _buildMeta(ctx),
          ],
        ),
      ),
    );
  }

  Widget _buildShareContent(_BubbleCtx ctx, ShareAttachment share) {
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
                  child: LinkText(
                    text: message.text!,
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
              _buildMeta(ctx),
            ],
          ),
        ),
      ),
    );
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
                  Expanded(child: _buildCaption(ctx)),
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
    final hasCaption = message.text != null && message.text!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildForwardedHeader(ctx, forwarded),
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
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildForwardedHeader(ctx, forwarded),
          const SizedBox(height: 4),
          ...attachments.map((a) {
            if (a is FileAttachment) {
              return _buildFileAttachment(ctx, a, fill: true);
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildSinglePhoto(_BubbleCtx ctx, PhotoAttachment photo) {
    final width = photo.width?.toDouble() ?? 200;
    final height = photo.height?.toDouble() ?? 200;

    final constrainedWidth = width.clamp(photoMinSize, photoMaxSize);
    final constrainedHeight = height.clamp(photoMinSize, photoMaxSize);
    final dpr = MediaQuery.of(ctx.context).devicePixelRatio;

    final matchTop = ctx.hasPhotoWithCaption;
    final matchBottom = !ctx.hasPhotoWithCaption;

    final topR = matchTop ? _bigRadius : _photoRadius;
    final bottomL = matchBottom
        ? (isMe ? _bigRadius : _smallRadius)
        : _smallRadius;
    final bottomR = matchBottom
        ? (isMe ? _smallRadius : _bigRadius)
        : _smallRadius;

    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: topR,
        topRight: topR,
        bottomLeft: bottomL,
        bottomRight: bottomR,
      ),
      child: Stack(
        children: [
          _buildPhotoImage(
            ctx,
            photo,
            constrainedWidth,
            constrainedHeight,
            memWidth: (constrainedWidth * dpr).round(),
            memHeight: (constrainedHeight * dpr).round(),
          ),
          if (uploadProgress != null) _buildUploadOverlay(uploadProgress!, 0),
          if (uploadProgress == null)
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

  Widget _buildPhotoImage(
    _BubbleCtx ctx,
    PhotoAttachment photo,
    double width,
    double height, {
    required int memWidth,
    required int memHeight,
  }) {
    final localPath = photo.localPath;
    if (localPath != null) {
      return Image.file(
        File(localPath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: memWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            _buildPhotoPlaceholder(ctx.cs, width, height),
      );
    }
    final imageUrl = photo.baseUrl ?? '';
    if (imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        memCacheWidth: memWidth,
        memCacheHeight: memHeight,
        fadeInDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        errorWidget: (_, _, _) => _buildPhotoPlaceholder(ctx.cs, width, height),
      );
    }
    return _buildPhotoPlaceholder(ctx.cs, width, height);
  }

  Widget _buildUploadOverlay(
    ValueListenable<List<double>> progress,
    int index,
  ) {
    return Positioned.fill(
      child: ValueListenableBuilder<List<double>>(
        valueListenable: progress,
        builder: (context, values, _) {
          final value = index < values.length ? values[index] : 1.0;
          final indeterminate = value <= 0 || value >= 1.0;
          return Container(
            color: Colors.black.withValues(alpha: 0.4),
            alignment: Alignment.center,
            child: SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: indeterminate ? null : value,
                color: Colors.white,
              ),
            ),
          );
        },
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
          Expanded(child: _buildPhotoTile(ctx, p1, 0)),
          const SizedBox(width: 2),
          Expanded(child: _buildPhotoTile(ctx, p2, 1)),
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
            return _buildPhotoTileWithOverlay(ctx, photos[i], '+$remaining', i);
          }
          return _buildPhotoTile(ctx, photos[i], i);
        }),
      ),
    );
  }

  Widget _buildPhotoTile(_BubbleCtx ctx, PhotoAttachment photo, int index) {
    final cachePx =
        (photoMaxSize / 2 * MediaQuery.of(ctx.context).devicePixelRatio)
            .round();
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          _buildPhotoImage(
            ctx,
            photo,
            double.infinity,
            double.infinity,
            memWidth: cachePx,
            memHeight: cachePx,
          ),
          if (uploadProgress != null)
            _buildUploadOverlay(uploadProgress!, index),
          if (uploadProgress == null)
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
    int index,
  ) {
    final cachePx =
        (photoMaxSize / 2 * MediaQuery.of(ctx.context).devicePixelRatio)
            .round();
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          _buildPhotoImage(
            ctx,
            photo,
            double.infinity,
            double.infinity,
            memWidth: cachePx,
            memHeight: cachePx,
          ),
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
          if (uploadProgress != null)
            _buildUploadOverlay(uploadProgress!, index),
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
    final style = TextStyle(color: ctx.text, fontSize: 16, height: 1.3);
    if (LinkText.hasLinks(message.text)) {
      return LinkText(text: message.text!, style: style);
    }
    return Text(message.text ?? '', style: style);
  }

  Widget _buildGenericAttachment(_BubbleCtx ctx, MessageAttachment attachment) {
    switch (attachment.type) {
      case AttachmentType.video:
        return _buildVideoAttachment(ctx, attachment);
      case AttachmentType.file:
        return _buildFileAttachment(ctx, attachment);
      case AttachmentType.sticker:
        return _buildStickerAttachment(ctx, attachment);
      case AttachmentType.location:
        return _buildLocationAttachment(ctx, attachment as LocationAttachment);
      case AttachmentType.call:
        return _buildCallAttachment(ctx, attachment as CallAttachment);
      default:
        return _buildTextContent(ctx);
    }
  }

  Widget _buildCallAttachment(_BubbleCtx ctx, CallAttachment call) {
    final missed = call.isMissedOrFailed;
    final accent = isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary;
    final iconColor = missed ? ctx.cs.error : accent;

    final IconData icon;
    final String label;
    if (call.isGroup) {
      icon = call.isVideo ? Symbols.videocam : Symbols.groups;
      label = call.isVideo ? 'Групповой видеозвонок' : 'Групповой звонок';
    } else if (call.isVideo) {
      icon = Symbols.videocam;
      label = missed
          ? (isMe ? 'Отменённый видеозвонок' : 'Пропущенный видеозвонок')
          : (isMe ? 'Исходящий видеозвонок' : 'Входящий видеозвонок');
    } else {
      icon = Symbols.call;
      label = missed
          ? (isMe ? 'Отменённый звонок' : 'Пропущенный звонок')
          : (isMe ? 'Исходящий звонок' : 'Входящий звонок');
    }

    final directionIcon = isMe ? Symbols.call_made : Symbols.call_received;

    final subtitle = missed
        ? _clockText
        : '$_clockText · ${formatSecondsMmSs((call.durationMs / 1000).round())}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: missed
                  ? ctx.cs.error.withValues(alpha: 0.12)
                  : (isMe
                        ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.12)
                        : ctx.cs.primaryContainer),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ctx.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      directionIcon,
                      size: 13,
                      color: missed ? ctx.cs.error : ctx.dim,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: ctx.dim,
                        fontSize: 12,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildLocationAttachment(_BubbleCtx ctx, LocationAttachment location) {
    final lat = location.latitude;
    final lon = location.longitude;
    final coords = lat != null && lon != null
        ? '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}'
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: lat == null || lon == null
                  ? null
                  : () {
                      Haptics.tap();
                      openLocationOnMap(
                        ctx.context,
                        lat,
                        lon,
                        zoom: location.zoom,
                      );
                    },
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe
                      ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.08)
                      : ctx.cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isMe
                            ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.12)
                            : ctx.cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Symbols.location_on,
                        color: isMe
                            ? ctx.cs.onPrimaryContainer
                            : ctx.cs.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            location.title ?? 'Геопозиция',
                            style: TextStyle(
                              color: ctx.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            location.address ?? coords ?? 'Открыть на карте',
                            style: TextStyle(color: ctx.dim, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildMeta(ctx),
          ],
        ),
      ),
    );
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
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Symbols.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _playVideo(ctx.context, video),
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

  Future<void> _playVideo(BuildContext context, MessageAttachment video) async {
    final videoId = (video as dynamic).videoId as int?;
    final token = (video as dynamic).videoToken as String?;
    if (videoId == null) {
      showCustomNotification(context, 'Не удалось открыть видео');
      return;
    }
    Haptics.tap();

    final cacheName = 'video_$videoId.mp4';
    final cached = await MediaCache.existing(cacheName) != null;
    if (!context.mounted) return;

    String? url;
    if (!cached) {
      if (token == null) {
        showCustomNotification(context, 'Не удалось открыть видео');
        return;
      }
      url = await messagesModule.getVideoUrl(
        messageId: message.id,
        chatId: message.chatId,
        token: token,
        videoId: videoId,
      );
      if (!context.mounted) return;
      if (url == null) {
        showCustomNotification(context, 'Не удалось получить видео');
        return;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VideoPlayerScreen(cacheName: cacheName, url: url),
      ),
    );
  }

  Widget _buildFileAttachment(
    _BubbleCtx ctx,
    MessageAttachment file, {
    bool fill = false,
  }) {
    final name = (file as dynamic).name as String? ?? 'File';
    final size = (file as dynamic).size as int? ?? 0;
    final sizeStr = formatBytes(size);
    final fileId = (file as dynamic).fileId as int?;
    final cacheName = '${fileId}_$name';

    final preview = file is FileAttachment ? file.preview : null;
    final previewUrl = preview?.baseUrl ?? preview?.previewData ?? '';

    final inner = Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (previewUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: previewUrl,
                width: 240,
                height: 160,
                fit: BoxFit.cover,
                memCacheWidth: 480,
                fadeInDuration: const Duration(milliseconds: 120),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
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
                    ValueListenableBuilder<double?>(
                      valueListenable: MediaDownloadProgress.notifier(
                        cacheName,
                      ),
                      builder: (context, progress, _) => Text(
                        progress != null
                            ? '${(progress * 100).round()}% · $sizeStr'
                            : sizeStr,
                        style: TextStyle(
                          color: ctx.dim,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<double?>(
                valueListenable: MediaDownloadProgress.notifier(cacheName),
                builder: (context, progress, _) {
                  final downloading = progress != null;
                  return GestureDetector(
                    onTap: downloading
                        ? null
                        : () => _downloadFile(ctx.context, file, name),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isMe
                            ? ctx.cs.onPrimaryContainer.withValues(alpha: 0.12)
                            : ctx.cs.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: downloading
                          ? Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: progress > 0 ? progress : null,
                                color: isMe
                                    ? ctx.cs.onPrimaryContainer
                                    : ctx.cs.primary,
                              ),
                            )
                          : Icon(
                              Symbols.download,
                              color: isMe
                                  ? ctx.cs.onPrimaryContainer
                                  : ctx.cs.primary,
                              size: 18,
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
          _buildMeta(ctx),
        ],
      ),
    );
    return fill ? inner : IntrinsicWidth(child: inner);
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
                    color: isMe ? ctx.cs.onPrimaryContainer : ctx.cs.primary,
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
                    style: TextStyle(color: ctx.dim, fontSize: 12, height: 1.2),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildForwardedHeader(ctx, forwarded),
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
    final url = photo.baseUrl ?? '';
    if (url.isEmpty) return;
    Navigator.of(ctx).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(baseUrl: url),
      ),
    );
  }

  Future<void> _downloadFile(
    BuildContext context,
    MessageAttachment file,
    String name,
  ) async {
    final fileId = (file as dynamic).fileId as int?;
    if (fileId == null) {
      showCustomNotification(context, 'Не удалось определить файл');
      return;
    }
    Haptics.tap();

    final cacheName = '${fileId}_$name';

    MediaDownloadProgress.set(cacheName, 0);
    final result = await openCachedFile(
      cacheName,
      () => messagesModule.getFileUrl(
        messageId: message.id,
        chatId: message.chatId,
        fileId: fileId,
      ),
      onProgress: (p) => MediaDownloadProgress.set(cacheName, p),
    );
    MediaDownloadProgress.set(cacheName, null);
    if (!context.mounted) return;
    if (!result.ok) {
      showCustomNotification(
        context,
        'Ошибка загрузки: ${result.error ?? 'не удалось открыть'}',
      );
    }
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
      deleted: message.deleted,
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
          Text(_clockText, style: TextStyle(color: ctx.dim, fontSize: 11)),
          if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(ctx)],
          if (message.deleted) ...[
            const SizedBox(width: 4),
            _buildDeletedIcon(ctx),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _clockText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (message.deleted) ...[
            const SizedBox(width: 3),
            const Icon(Symbols.delete, size: 11, color: Colors.white),
          ],
        ],
      ),
    );
  }

  Widget _buildDeletedIcon(_BubbleCtx ctx) {
    return Icon(Symbols.delete, size: 13, color: ctx.dim);
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
}

class _VoiceMessageBubble extends StatefulWidget {
  final int duration;
  final String url;
  final Color textColor;
  final bool isMe;
  final bool deleted;
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
    this.deleted = false,
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
  final ValueNotifier<double> _progress = ValueNotifier(0.0);
  bool _transcriptionVisible = false;
  String? _transcriptionText;
  bool _transcriptionLoading = false;

  @override
  void initState() {
    super.initState();
    _transcriptionText = widget.preloadedText;
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
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
                        _progress.value =
                            (details.localPosition.dx / constraints.maxWidth)
                                .clamp(0.0, 1.0);
                      },
                      onHorizontalDragUpdate: (details) {
                        _progress.value =
                            (details.localPosition.dx / constraints.maxWidth)
                                .clamp(0.0, 1.0);
                      },
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: waveInactiveColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: ValueListenableBuilder<double>(
                          valueListenable: _progress,
                          builder: (context, progress, _) =>
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: waveActiveColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
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
              SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    formatSecondsMmSs(widget.duration),
                    style: TextStyle(
                      color: widget.textColor.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                  formatClock(
                    DateTime.fromMillisecondsSinceEpoch(widget.time),
                    withSeconds: KometSettings.fullTimestamp.value,
                  ),
                  style: TextStyle(
                    color: widget.textColor.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 2),
                  _buildStatusIcon(),
                ],
                if (widget.deleted) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Symbols.delete,
                    size: 13,
                    color: widget.textColor.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ],
          ),
          if (_transcriptionVisible) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  formatClock(
                    DateTime.fromMillisecondsSinceEpoch(widget.time),
                    withSeconds: KometSettings.fullTimestamp.value,
                  ),
                  style: TextStyle(
                    color: widget.textColor.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 2),
                  _buildStatusIcon(),
                ],
                if (widget.deleted) ...[
                  const SizedBox(width: 2),
                  Icon(
                    Symbols.delete,
                    size: 13,
                    color: widget.textColor.withValues(alpha: 0.6),
                  ),
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

      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _transcriptionLoading = false;
        _transcriptionText = 'ошибка транскрибации';
        _transcriptionVisible = true;
      });
    }
  }
}
