import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:komet/main.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../backend/modules/messages.dart';
import '../screens/webapp/web_app_screen.dart';
import '../../core/config/app_bubble_behavior.dart';
import '../../core/config/app_bubble_shape.dart';
import '../../core/utils/bubble_radius.dart';
import '../../core/utils/link_opener.dart';
import '../../core/utils/text_format.dart';
import '../../core/utils/webview_support.dart';
import '../../core/config/app_link_preview.dart';
import 'custom_notification.dart';
import 'formatted_message_text.dart';
import 'photo_viewer.dart';
import 'selectable_message_text.dart';
import '../../models/attachment.dart';
import '../../models/reaction_info.dart';
import 'attachment/bubbles/voice_bubble.dart';
import 'attachment/bubbles/bubble_context.dart';
import 'attachment/bubbles/poll_bubble.dart';
import 'attachment/bubbles/share_bubble.dart';
import 'attachment/bubbles/call_bubble.dart';
import 'attachment/bubbles/location_bubble.dart';
import 'attachment/bubbles/contact_bubble.dart';
import 'attachment/bubbles/sticker_bubble.dart';
import 'attachment/bubbles/photo_bubble.dart';
import 'attachment/bubbles/video_bubble.dart';
import 'attachment/bubbles/file_bubble.dart';
import 'attachment/bubbles/forwarded_bubble.dart';
import 'lottie_image.dart';

final Expando<MessageType> _contentTypeCache = Expando<MessageType>();

class _ZeroIntrinsicWidth extends SingleChildRenderObjectWidget {
  const _ZeroIntrinsicWidth({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderZeroIntrinsicWidth();
}

class _RenderZeroIntrinsicWidth extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;
}

/// A [Wrap] that reports its single-line width as the max intrinsic width, so an
/// enclosing [IntrinsicWidth] grows the bubble to fit the chips on one line
/// instead of collapsing to the widest single chip (which makes them stack).
/// It still wraps to multiple lines when the available width is smaller.
class _ReactionsWrap extends Wrap {
  const _ReactionsWrap({
    super.spacing,
    super.runSpacing,
    required super.children,
  });

  @override
  RenderWrap createRenderObject(BuildContext context) {
    return _RenderReactionsWrap(
      direction: direction,
      alignment: alignment,
      spacing: spacing,
      runAlignment: runAlignment,
      runSpacing: runSpacing,
      crossAxisAlignment: crossAxisAlignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
    );
  }
}

class _RenderReactionsWrap extends RenderWrap {
  _RenderReactionsWrap({
    super.direction,
    super.alignment,
    super.spacing,
    super.runAlignment,
    super.runSpacing,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
    super.clipBehavior,
  });

  @override
  double computeMaxIntrinsicWidth(double height) {
    var total = 0.0;
    var count = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      total += child.getMaxIntrinsicWidth(double.infinity);
      count++;
      child = childAfter(child);
    }
    if (count > 1) total += spacing * (count - 1);
    return total;
  }
}

class MessageBubble extends StatelessWidget {
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
  final int? chatId;
  final PhotoViewerActions? photoActions;
  final String? overrideStatus;
  final ValueListenable<int>? otherReadTime;
  final ValueListenable<Map<String, dynamic>?>? reactionsListenable;
  final ValueListenable<List<double>>? uploadProgress;
  final void Function(String messageId)? onReplyTap;
  final void Function(int senderId)? onAvatarTap;
  final void Function(StickerAttachment sticker)? onStickerTap;
  final void Function(String emoji)? onReactionTap;
  final String? peerName;
  final String? peerAvatarUrl;
  final ValueListenable<({String id, Offset pos})?>? textSelection;
  final VoidCallback? onExitTextSelection;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.myId,
    this.prevMessage,
    this.nextMessage,
    required this.chatType,
    this.chatId,
    this.photoActions,
    this.overrideStatus,
    this.otherReadTime,
    this.reactionsListenable,
    this.uploadProgress,
    this.onReplyTap,
    this.onAvatarTap,
    this.onStickerTap,
    this.onReactionTap,
    this.peerName,
    this.peerAvatarUrl,
    this.textSelection,
    this.onExitTextSelection,
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

  bool get _isVideoNote {
    final a = message.attachments;
    if (a == null || a.isEmpty) return false;
    final first = a.first;
    return first is VideoAttachment && first.isNote;
  }

  bool get _isSticker {
    final a = message.attachments;
    if (a == null || a.isEmpty) return false;
    return a.first is StickerAttachment;
  }

  static const int _jumboAnimojiLimit = 4;

  List<String>? get _jumboAnimojiUrls {
    if (message.attachments?.isNotEmpty ?? false) return null;
    return animojiOnlyLottieUrls(
      message.text,
      message.formatRanges,
      limit: _jumboAnimojiLimit,
    );
  }

  MessageType get _contentType {
    if (_hasShareAttachment) return _computeContentType();
    return _contentTypeCache[message] ??= _computeContentType();
  }

  InlineKeyboardAttachment? get _inlineKeyboard {
    final attachments = message.attachments;
    if (attachments == null) return null;
    for (final a in attachments) {
      if (a is InlineKeyboardAttachment && !a.isEmpty) return a;
    }
    return null;
  }

  MessageType _computeContentType() {
    if (message.isControl) return MessageType.control;
    final attachments = message.attachments
        ?.where((a) => a is! InlineKeyboardAttachment)
        .toList();
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

  static const List<Color> _senderPalette = [
    Color(0xFFE57373),
    Color(0xFF64B5F6),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFBA68C8),
    Color(0xFF4DD0E1),
    Color(0xFFF06292),
    Color(0xFFA1887F),
  ];

  Color _senderColor(int id) =>
      _senderPalette[id.abs() % _senderPalette.length];

  Widget _buildSenderHeader(ColorScheme cs, bool needsInset) {
    final name = ContactCache.get(message.senderId);
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    final header = Padding(
      padding: needsInset
          ? const EdgeInsets.fromLTRB(12, 6, 12, 2)
          : const EdgeInsets.only(bottom: 2),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _senderColor(message.senderId),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final cb = onAvatarTap;
    if (cb == null) return header;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => cb(message.senderId),
      child: header,
    );
  }

  Widget _buildLeadingAvatar(ColorScheme cs) {
    final senderAvatar = ContactCache.getAvatar(message.senderId);
    final displaySender = ContactCache.get(message.senderId);
    final Widget avatar;
    if (senderAvatar != null && senderAvatar.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 15,
        backgroundImage: CachedNetworkImageProvider(
          senderAvatar,
          maxWidth: 96,
          maxHeight: 96,
        ),
        backgroundColor: cs.primaryContainer,
      );
    } else {
      avatar = CircleAvatar(
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

    final cb = onAvatarTap;
    if (cb == null) return avatar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => cb(message.senderId),
      child: avatar,
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
    final jumboAnimoji = _jumboAnimojiUrls;
    final padding = jumboAnimoji != null
        ? EdgeInsets.zero
        : _paddingFor(contentType, shape);

    final showAvatarSlot = !isMe;
    final showAvatar =
        showAvatarSlot &&
        chatType == "CHAT" &&
        nextMessage?.senderId != message.senderId;
    final showSenderName =
        showAvatarSlot &&
        chatType == "CHAT" &&
        prevMessage?.senderId != message.senderId;

    final maxBubbleWidth = math.min(MediaQuery.sizeOf(context).width * 0.75, 560.0);
    final keyboard = _inlineKeyboard;
    final isVideoNote = _isVideoNote;
    final noBubbleBackground = isVideoNote || _isSticker || jumboAnimoji != null;
    final bubbleColor = noBubbleBackground
        ? Colors.transparent
        : (isMe ? cs.primaryContainer : cs.surfaceContainerHighest);

    BubbleContext makeCtx() => BubbleContext(
      context: context,
      cs: cs,
      text: textColor,
      shape: shape,
      contentType: contentType,
      hasPhotoWithCaption: hasPhotoCap,
      hasMultiplePhotosNoCaption: hasMultiPhotos,
      message: message,
      isMe: isMe,
      myId: myId,
      chatType: chatType,
      chatId: chatId,
      photoActions: photoActions,
      overrideStatus: overrideStatus,
      otherReadTime: otherReadTime,
      uploadProgress: uploadProgress,
      onStickerTap: onStickerTap,
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
      final quote = _buildReplyQuote(context, cs, textColor, reply);
      if (contentType != MessageType.text || jumboAnimoji != null) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [quote, const SizedBox(height: 4), content],
        );
      }
      return IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ZeroIntrinsicWidth(child: quote),
            const SizedBox(height: 4),
            content,
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
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
            else if (showAvatarSlot && chatType == "CHAT")
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
                      borderRadius: noBubbleBackground
                          ? null
                          : _borderRadiusFor(
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showSenderName)
                        _buildSenderHeader(cs, padding == EdgeInsets.zero),
                      withReply(
                        reactionsInside
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [bubbleContent, _reactionsBar(cs)],
                              )
                            : bubbleContent,
                      ),
                    ],
                  ),
                ),
                if (keyboard != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    child: _buildInlineKeyboard(context, cs, keyboard),
                  ),
                if (reactionsUnder) _reactionsBar(cs),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineKeyboard(
    BuildContext context,
    ColorScheme cs,
    InlineKeyboardAttachment keyboard,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in keyboard.rows)
            if (row.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    for (var i = 0; i < row.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: _buildInlineKeyboardButton(
                          context,
                          cs,
                          keyboard,
                          row[i],
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

  Widget _buildInlineKeyboardButton(
    BuildContext context,
    ColorScheme cs,
    InlineKeyboardAttachment keyboard,
    InlineKeyboardButton button,
  ) {
    final trailingIcon = switch (button.type) {
      'LINK' => Symbols.open_in_new,
      'OPEN_APP' => Symbols.chevron_right,
      _ => null,
    };
    return Material(
      color: cs.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onInlineButtonTap(context, keyboard, button),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  button.text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 4),
                Icon(trailingIcon, size: 16, color: cs.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onInlineButtonTap(
    BuildContext context,
    InlineKeyboardAttachment keyboard,
    InlineKeyboardButton button,
  ) async {
    switch (button.type) {
      case 'LINK':
        final url = button.url;
        if (url != null && url.isNotEmpty) {
          await openExternalUrl(context, url);
        }
        return;
      case 'OPEN_APP':
        await _openMiniApp(context, button);
        return;
      default:
        final callbackId = keyboard.callbackId;
        if (callbackId == null || callbackId.isEmpty) {
          showCustomNotification(context, 'Кнопка не поддерживается');
          return;
        }
        final answer = await messagesModule.sendButtonCallback(
          chatId: message.chatId,
          messageId: message.id,
          callbackId: callbackId,
          payload: button.payload,
        );
        if (!context.mounted) return;
        final url = answer?['url']?.toString();
        if (url != null && url.isNotEmpty) {
          await openExternalUrl(context, url);
          return;
        }
        final text = answer?['text']?.toString();
        if (text != null && text.isNotEmpty) {
          showCustomNotification(context, text);
        }
    }
  }

  Future<void> _openMiniApp(
    BuildContext context,
    InlineKeyboardButton button,
  ) async {
    if (!webViewSupported) {
      showCustomNotification(context, 'На вашей платформе это недоступно');
      return;
    }

    final deeplink = button.webApp != null
        ? Uri.tryParse(button.webApp!)
        : null;
    final startParam =
        button.payload ??
        deeplink?.queryParameters['startapp'] ??
        deeplink?.queryParameters['startApp'];
    final chatId =
        int.tryParse(deeplink?.queryParameters['chat_id'] ?? '') ??
        message.chatId;
    final botId = button.contactId;

    if (botId == null) {
      showCustomNotification(context, 'Не удалось открыть приложение');
      return;
    }

    if (kDebugMode) {
      debugPrint(
        '[inline-kb] OPEN_APP botId=$botId chatId=$chatId startParam=$startParam',
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebAppScreen(
          title: button.text,
          loader: () => webAppModule.fetchLaunch(
            botId,
            startParam: startParam,
            chatId: chatId,
          ),
        ),
      ),
    );
  }

  Map? _resolveReactionInfo() {
    final listenable = reactionsListenable;
    if (listenable != null) {
      final v = listenable.value;
      return v is Map ? v : null;
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

  Widget _buildContent(BubbleContext ctx) {
    final jumbo = _jumboAnimojiUrls;
    if (jumbo != null) return _buildJumboAnimojiContent(ctx, jumbo);
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

  Widget _buildJumboAnimojiContent(BubbleContext ctx, List<String> urls) {
    final n = urls.length;
    final size = switch (n) {
      1 => 96.0,
      2 => 76.0,
      3 => 64.0,
      _ => 56.0,
    };
    final cache = (size * 2).round();

    final animations = Stack(
      children: [
        Wrap(
          spacing: 2,
          runSpacing: 2,
          alignment: ctx.isMe ? WrapAlignment.end : WrapAlignment.start,
          children: [
            for (final url in urls)
              SizedBox(
                width: size,
                height: size,
                child: LottieImage(
                  lottieUrl: url,
                  size: size,
                  memCacheWidth: cache,
                  eager: true,
                ),
              ),
          ],
        ),
        Positioned(
          bottom: BubbleContext.compactTimePadding,
          right: BubbleContext.compactTimePadding,
          child: _buildJumboAnimojiMeta(ctx),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: ctx.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [animations, _buildReactionsBarFor(ctx.cs, ctx.reactionInfo)],
    );
  }

  Widget _buildJumboAnimojiMeta(BubbleContext ctx) {
    final status = ctx.overrideStatus ?? ctx.message.status;
    final statusVisual = messageStatusVisual(status, dimColor: Colors.white);
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
            Icon(statusVisual.icon, size: 13, color: statusVisual.color),
          ],
          if (ctx.message.deleted) ...[
            const SizedBox(width: 3),
            const Icon(Symbols.delete, size: 12, color: Colors.white),
          ],
        ],
      ),
    );
  }

  Widget _buildReactionsBar(ColorScheme cs) {
    final info = message.payload?['reactionInfo'];
    return _buildReactionsBarFor(cs, info is Map ? info : null);
  }

  Widget _buildReactionsBarFor(ColorScheme cs, Map? info) {
    final chips = _buildReactionChipsFor(cs, ReactionInfo.fromMap(info));
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(spacing: 4, runSpacing: 4, children: chips),
    );
  }

  List<Widget> _buildReactionChipsFor(ColorScheme cs, ReactionInfo? info) {
    if (info == null) return const [];
    final yourReaction = info.yourReaction;
    final isDialog = chatType == 'DIALOG';

    final chips = <Widget>[];
    for (final c in info.counters) {
      final isYours = yourReaction == c.reaction;

      Widget? avatar;
      if (isDialog) {
        final peerReacted = (c.count - (isYours ? 1 : 0)) >= 1;
        avatar = peerReacted
            ? _reactionAvatar(cs, peerAvatarUrl, peerName)
            : _reactionAvatar(
                cs,
                ContactCache.getAvatar(myId),
                ContactCache.get(myId),
              );
      }

      Widget chip = Container(
        padding: EdgeInsets.fromLTRB(7, 2, avatar != null ? 3 : 7, 2),
        decoration: BoxDecoration(
          color: isYours ? cs.primary.withValues(alpha: 0.22) : _reactionChipBg,
          borderRadius: _reactionChipRadius,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.reaction, style: const TextStyle(fontSize: 13)),
            if (c.count > 1) ...[
              const SizedBox(width: 3),
              Text(
                c.count.toString(),
                style: TextStyle(
                  color: isYours ? cs.primary : cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (avatar != null) ...[const SizedBox(width: 5), avatar],
          ],
        ),
      );

      final onTap = onReactionTap;
      if (onTap != null) {
        chip = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTap(c.reaction),
          child: chip,
        );
      }

      chips.add(chip);
    }
    return chips;
  }

  Widget _reactionAvatar(ColorScheme cs, String? url, String? name) {
    const double diameter = 17;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: diameter / 2,
        backgroundColor: cs.primaryContainer,
        backgroundImage: CachedNetworkImageProvider(
          url,
          maxWidth: 64,
          maxHeight: 64,
        ),
      );
    }
    final letter = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: diameter / 2,
      backgroundColor: cs.primaryContainer,
      child: Text(
        letter,
        style: TextStyle(fontSize: 9, color: cs.onPrimaryContainer),
      ),
    );
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
      case 'pin':
        text =
            '${ContactCache.get(message.senderId) ?? 'Пользователь'} закрепил(а) сообщение';
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

  Widget _wrapSelectable(Widget textWidget) {
    final listenable = textSelection;
    if (listenable == null || (message.text?.isEmpty ?? true)) {
      return textWidget;
    }
    return ValueListenableBuilder<({String id, Offset pos})?>(
      valueListenable: listenable,
      builder: (context, req, child) {
        if (req == null || req.id != message.id) return child!;
        return SelectableMessageText(
          initialGlobalPosition: req.pos,
          onExit: onExitTextSelection ?? () {},
          child: child!,
        );
      },
      child: textWidget,
    );
  }

  Widget _buildTextContent(BubbleContext ctx) {
    final attachments = message.attachments;
    final isForwardedContact =
        attachments != null &&
        attachments.isNotEmpty &&
        attachments.first is ForwardedMessageAttachment &&
        (attachments.first as ForwardedMessageAttachment).originalContact !=
            null;

    final forwarded = _getForwardedAttachment();
    final isForwarded = forwarded != null && !isForwardedContact;

    final reactionChips = _buildReactionChipsFor(
      ctx.cs,
      ReactionInfo.fromMap(ctx.reactionInfo),
    );
    final hasReactions = reactionChips.isNotEmpty;

    final textStyle = TextStyle(color: ctx.text, fontSize: 16, height: 1.3);
    final ranges = message.formatRanges;
    final baseTextWidget = isForwarded
        ? _buildForwardedInlineText(ctx, forwarded)
        : (FormattedMessageText.isFormatted(message.text, ranges)
              ? FormattedMessageText(
                  text: message.text!,
                  ranges: ranges,
                  style: textStyle,
                )
              : Text(message.text ?? '', style: textStyle));
    final textWidget = _wrapSelectable(baseTextWidget);

    final metaWidget = Text(
      message.status == 'EDITED' ? '${ctx.clockText} ред.' : ctx.clockText,
      style: TextStyle(color: ctx.dim, fontSize: 10),
    );

    if (hasReactions) {
      return IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            textWidget,
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _ReactionsWrap(
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
                if (isMe) ...[const SizedBox(width: 4), ctx.statusIcon()],
                if (message.deleted) ...[
                  const SizedBox(width: 4),
                  ctx.deletedIcon(),
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
            if (isMe) ...[const SizedBox(width: 4), ctx.statusIcon()],
            if (message.deleted) ...[
              const SizedBox(width: 4),
              ctx.deletedIcon(),
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
          Text(origText, style: TextStyle(color: ctx.text, fontSize: 14)),
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

  Widget _buildAttachmentContent(BubbleContext ctx) {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) {
      return _buildTextContent(ctx);
    }

    final first = attachments.first;
    if (first is ForwardedMessageAttachment) {
      final fwd = first;
      if (fwd.originalContact != null) {
        return ForwardedContactBubble(ctx: ctx, forwarded: fwd);
      }
      final photos = fwd.originalAttachments
          ?.whereType<PhotoAttachment>()
          .toList();
      if (photos != null && photos.isNotEmpty) {
        return ForwardedPhotoBubble(ctx: ctx, forwarded: fwd, photos: photos);
      }
      final stickers = fwd.originalAttachments
          ?.whereType<StickerAttachment>()
          .toList();
      if (stickers != null && stickers.isNotEmpty) {
        return ForwardedStickerBubble(
          ctx: ctx,
          forwarded: fwd,
          sticker: stickers.first,
        );
      }
      final files = fwd.originalAttachments;
      if (files != null && files.isNotEmpty) {
        return ForwardedGenericBubble(
          ctx: ctx,
          forwarded: fwd,
          attachments: files,
        );
      }
      return _buildTextContent(ctx);
    }

    final contacts = attachments.whereType<ContactAttachment>().toList();
    if (contacts.isNotEmpty) {
      return ContactBubble(ctx: ctx, contact: contacts.first);
    }

    final polls = attachments.whereType<PollAttachment>().toList();
    if (polls.isNotEmpty) {
      return PollBubble(ctx: ctx, poll: polls.first);
    }

    final shares = attachments.whereType<ShareAttachment>().toList();
    if (shares.isNotEmpty) {
      return ShareBubble(ctx: ctx, share: shares.first);
    }

    final photos = attachments.whereType<PhotoAttachment>().toList();
    if (photos.isEmpty) {
      return _buildGenericAttachment(ctx, attachments.first);
    }

    return PhotoBubble(ctx: ctx, photos: photos);
  }

  Widget _buildGenericAttachment(
    BubbleContext ctx,
    MessageAttachment attachment,
  ) {
    switch (attachment.type) {
      case AttachmentType.video:
        return VideoBubble(ctx: ctx, video: attachment as VideoAttachment);
      case AttachmentType.file:
        return FileBubble(ctx: ctx, file: attachment as FileAttachment);
      case AttachmentType.sticker:
        return StickerBubble(ctx: ctx, sticker: attachment);
      case AttachmentType.location:
        return LocationBubble(
          ctx: ctx,
          location: attachment as LocationAttachment,
        );
      case AttachmentType.call:
        return CallBubble(ctx: ctx, call: attachment as CallAttachment);
      default:
        return _buildTextContent(ctx);
    }
  }

  Widget _buildVoiceContent(BubbleContext ctx) {
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

    return VoiceMessageBubble(
      duration: duration,
      url: url,
      textColor: ctx.text,
      isMe: isMe,
      deleted: message.deleted,
      status: overrideStatus ?? message.status,
      otherReadTime: otherReadTime,
      time: message.time,
      cs: ctx.cs,
      waveData: waveData,
      chatId: message.chatId,
      messageId: message.id,
      audioId: audioId,
      preloadedText: cachedTranscription?.text,
    );
  }
}
