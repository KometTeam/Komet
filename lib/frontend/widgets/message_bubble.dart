import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:komet/main.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../backend/modules/messages.dart';
import '../screens/webapp/web_app_bridge.dart';
import '../screens/webapp/web_app_screen.dart';
import '../../core/config/app_bubble_behavior.dart';
import '../../core/config/app_bubble_shape.dart';
import '../../core/crypto/message_decryption_cache.dart';
import 'decrypted_text.dart';
import '../../core/utils/bubble_radius.dart';
import '../../core/utils/emoji_keyword_index.dart';
import '../../core/utils/link_opener.dart';
import '../../core/utils/text_format.dart';
import '../../core/utils/webview_support.dart';
import '../../core/config/app_link_preview.dart';
import 'custom_notification.dart';
import 'formatted_message_text.dart';
import 'text_entity_actions.dart';
import 'sending_clock_icon.dart';
import 'photo_viewer.dart';
import 'selectable_message_text.dart';
import '../../models/attachment.dart';
import '../../models/animoji.dart';
import '../../models/reaction_info.dart';
import 'attachment/bubbles/voice_bubble.dart';
import 'attachment/bubbles/bubble_context.dart';
import 'attachment/bubbles/poll_bubble.dart';
import 'attachment/bubbles/share_bubble.dart';
import 'attachment/bubbles/call_bubble.dart';
import 'attachment/bubbles/control_bubble.dart';
import 'attachment/bubbles/location_bubble.dart';
import 'attachment/bubbles/contact_bubble.dart';
import 'attachment/bubbles/sticker_bubble.dart';
import 'attachment/bubbles/photo_bubble.dart';
import 'attachment/bubbles/video_bubble.dart';
import 'attachment/bubbles/file_bubble.dart';
import 'attachment/bubbles/forwarded_bubble.dart';
import 'lottie_image.dart';

final Expando<MessageType> _contentTypeCache = Expando<MessageType>();

class ReactionAnimationEvent {
  final String messageId;
  final String emoji;
  final int token;

  const ReactionAnimationEvent({
    required this.messageId,
    required this.emoji,
    required this.token,
  });
}

typedef ReactionAnimojiResolver = Animoji? Function(String emoji);

class _TextWithMeta extends MultiChildRenderObjectWidget {
  _TextWithMeta({required Widget text, required Widget meta})
    : super(children: [text, meta]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTextWithMeta();
}

class _TextWithMetaParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTextWithMeta extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TextWithMetaParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TextWithMetaParentData> {
  static const double _gap = 8;
  static const double _baselineNudge = 2;

  RenderBox get _text => firstChild!;
  RenderBox get _meta => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TextWithMetaParentData) {
      child.parentData = _TextWithMetaParentData();
    }
  }

  RenderParagraph? _soleParagraph() {
    RenderParagraph? found;
    var seen = 0;
    void visit(RenderObject node) {
      if (node is RenderParagraph) {
        found = node;
        seen++;
        return;
      }
      node.visitChildren(visit);
    }

    _text.visitChildren(visit);
    if (_text is RenderParagraph) {
      found = _text as RenderParagraph;
      seen = 1;
    }
    return seen == 1 ? found : null;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _text.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _text.getMaxIntrinsicWidth(height) +
      _gap +
      _meta.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _text.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _text.getMaxIntrinsicHeight(width) + _meta.getMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      BaselineOffset(_text.getDistanceToActualBaseline(baseline)).offset;

  @override
  void performLayout() {
    _meta.layout(const BoxConstraints(), parentUsesSize: true);
    final metaSize = _meta.size;

    _text.layout(constraints.loosen(), parentUsesSize: true);
    final textSize = _text.size;

    final paragraph = _soleParagraph();
    final needed = _gap + metaSize.width;

    double width;
    double height;
    var metaOnOwnLine = false;

    if (paragraph != null) {
      final length = paragraph.text.toPlainText().length;
      final caret = paragraph.getOffsetForCaret(
        TextPosition(offset: length),
        Rect.zero,
      );
      final lastLine = caret.dx;
      final singleLine = caret.dy < 0.5;
      if (lastLine + needed <= textSize.width) {
        width = textSize.width;
        height = textSize.height;
      } else if (singleLine) {
        width = lastLine + needed;
        height = textSize.height;
      } else {
        width = textSize.width;
        height = textSize.height + metaSize.height;
        metaOnOwnLine = true;
      }
    } else {
      width = math.max(textSize.width, metaSize.width);
      height = textSize.height + metaSize.height;
      metaOnOwnLine = true;
    }

    size = constraints.constrain(Size(width, height));

    (_text.parentData! as _TextWithMetaParentData).offset = Offset.zero;
    (_meta.parentData! as _TextWithMetaParentData).offset = Offset(
      math.max(0, size.width - metaSize.width),
      metaOnOwnLine
          ? size.height - metaSize.height
          : size.height - metaSize.height - _baselineNudge,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

class _CapIntrinsicWidth extends SingleChildRenderObjectWidget {
  final double cap;

  const _CapIntrinsicWidth({required this.cap, required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCapIntrinsicWidth(cap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderCapIntrinsicWidth renderObject,
  ) {
    renderObject.cap = cap;
  }
}

class _RenderCapIntrinsicWidth extends RenderProxyBox {
  _RenderCapIntrinsicWidth(this._cap);

  double _cap;
  set cap(double value) {
    if (value == _cap) return;
    _cap = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.min(super.computeMinIntrinsicWidth(height), _cap);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.min(super.computeMaxIntrinsicWidth(height), _cap);
}

class _HeaderAboveMatchWidth extends MultiChildRenderObjectWidget {
  _HeaderAboveMatchWidth({required Widget content, required Widget header})
    : super(children: [content, header]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeaderAboveMatchWidth();
}

class _HeaderAboveMatchWidthParentData
    extends ContainerBoxParentData<RenderBox> {}

class _RenderHeaderAboveMatchWidth extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderAboveMatchWidthParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _HeaderAboveMatchWidthParentData
        > {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderAboveMatchWidthParentData) {
      child.parentData = _HeaderAboveMatchWidthParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      firstChild!.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      firstChild!.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      firstChild!.getMinIntrinsicHeight(width) +
      lastChild!.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      firstChild!.getMaxIntrinsicHeight(width) +
      lastChild!.getMaxIntrinsicHeight(width);

  @override
  void performLayout() {
    final RenderBox content = firstChild!;
    final RenderBox header = childAfter(content)!;

    content.layout(constraints.loosen(), parentUsesSize: true);
    final double width = constraints.constrainWidth(content.size.width);

    header.layout(
      BoxConstraints.tightFor(width: width).enforce(constraints.loosen()),
      parentUsesSize: true,
    );

    (header.parentData! as _HeaderAboveMatchWidthParentData).offset =
        Offset.zero;
    (content.parentData! as _HeaderAboveMatchWidthParentData).offset = Offset(
      0,
      header.size.height,
    );

    size = constraints.constrain(
      Size(width, header.size.height + content.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

/// Stacks [bottom] directly beneath [top] and forces [bottom] to take exactly
/// [top]'s rendered width. Used to keep an inline keyboard and a comments footer
/// pinned to their post's natural width instead of stretching to the bubble max
/// — the latter would otherwise inflate a narrow post (single photo, link
/// preview) to the full bubble width.
class _StackMatchTopWidth extends MultiChildRenderObjectWidget {
  _StackMatchTopWidth({
    required Widget top,
    required Widget bottom,
    this.growForBottom = false,
  }) : super(children: [top, bottom]);

  final bool growForBottom;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderStackMatchTopWidth(growForBottom);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderStackMatchTopWidth renderObject,
  ) {
    renderObject.growForBottom = growForBottom;
  }
}

class _StackMatchTopWidthParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderStackMatchTopWidth extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _StackMatchTopWidthParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _StackMatchTopWidthParentData
        > {
  _RenderStackMatchTopWidth(this._growForBottom);

  bool _growForBottom;
  set growForBottom(bool value) {
    if (value == _growForBottom) return;
    _growForBottom = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _StackMatchTopWidthParentData) {
      child.parentData = _StackMatchTopWidthParentData();
    }
  }

  @override
  void performLayout() {
    final RenderBox top = firstChild!;
    final RenderBox bottom = childAfter(top)!;

    top.layout(constraints.loosen(), parentUsesSize: true);
    final Size topSize = top.size;
    (top.parentData! as _StackMatchTopWidthParentData).offset = Offset.zero;

    double width = topSize.width;
    if (_growForBottom) {
      width = math.max(width, bottom.getMaxIntrinsicWidth(double.infinity));
    }
    width = constraints.constrainWidth(width);

    bottom.layout(
      BoxConstraints.tightFor(width: width).enforce(constraints),
      parentUsesSize: true,
    );
    final Size bottomSize = bottom.size;
    (bottom.parentData! as _StackMatchTopWidthParentData).offset = Offset(
      0,
      topSize.height,
    );

    size = constraints.constrain(
      Size(math.max(width, topSize.width), topSize.height + bottomSize.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
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

class _ReactionAnimojiGlyph extends StatefulWidget {
  final String messageId;
  final String emoji;
  final Animoji animoji;
  final ValueListenable<ReactionAnimationEvent?>? animation;

  const _ReactionAnimojiGlyph({
    super.key,
    required this.messageId,
    required this.emoji,
    required this.animoji,
    this.animation,
  });

  @override
  State<_ReactionAnimojiGlyph> createState() => _ReactionAnimojiGlyphState();
}

class _ReactionAnimojiGlyphState extends State<_ReactionAnimojiGlyph> {
  static const double _size = 18;
  static const double _effectSize = _size * 2;

  int? _playingToken;
  bool _bodyPlaying = false;
  bool _effectPlaying = false;

  @override
  void initState() {
    super.initState();
    widget.animation?.addListener(_onAnimation);
  }

  @override
  void didUpdateWidget(_ReactionAnimojiGlyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.animation, widget.animation)) {
      oldWidget.animation?.removeListener(_onAnimation);
      widget.animation?.addListener(_onAnimation);
    }
    if (oldWidget.messageId != widget.messageId ||
        EmojiKeywordIndex.normalize(oldWidget.emoji) !=
            EmojiKeywordIndex.normalize(widget.emoji)) {
      _playingToken = null;
      _bodyPlaying = false;
      _effectPlaying = false;
    }
  }

  @override
  void dispose() {
    widget.animation?.removeListener(_onAnimation);
    super.dispose();
  }

  void _onAnimation() {
    final event = widget.animation?.value;
    if (event == null ||
        event.messageId != widget.messageId ||
        EmojiKeywordIndex.normalize(event.emoji) !=
            EmojiKeywordIndex.normalize(widget.emoji) ||
        event.token == _playingToken) {
      return;
    }
    final bodyUrl = widget.animoji.lottieUrl;
    final effectUrl = widget.animoji.lottiePlayUrl;
    setState(() {
      _playingToken = event.token;
      _bodyPlaying = bodyUrl != null && bodyUrl.isNotEmpty;
      _effectPlaying = effectUrl != null && effectUrl.isNotEmpty;
    });
  }

  void _onBodyCompleted() {
    if (!mounted) return;
    setState(() {
      _bodyPlaying = false;
      if (!_effectPlaying) _playingToken = null;
    });
  }

  void _onEffectCompleted() {
    if (!mounted) return;
    setState(() {
      _effectPlaying = false;
      if (!_bodyPlaying) _playingToken = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final staticUrl = widget.animoji.iconUrl;
    final bodyAnimationUrl = widget.animoji.lottieUrl;
    final effectAnimationUrl = widget.animoji.lottiePlayUrl;
    final Widget body;
    if (_bodyPlaying) {
      body = LottieImage(
        key: ValueKey(('body', _playingToken)),
        url: staticUrl,
        lottieUrl: bodyAnimationUrl,
        size: _size,
        memCacheWidth: 64,
        shimmer: false,
        eager: true,
        repeat: false,
        onCompleted: _onBodyCompleted,
      );
    } else if (staticUrl != null && staticUrl.isNotEmpty) {
      body = LottieImage(
        url: staticUrl,
        size: _size,
        memCacheWidth: 64,
        shimmer: false,
      );
    } else if (bodyAnimationUrl != null && bodyAnimationUrl.isNotEmpty) {
      body = LottieImage(
        lottieUrl: bodyAnimationUrl,
        size: _size,
        memCacheWidth: 64,
        shimmer: false,
        animate: false,
        repeat: false,
      );
    } else {
      body = Text(widget.emoji, style: const TextStyle(fontSize: 13));
    }

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          body,
          if (_effectPlaying)
            Positioned(
              left: -(_effectSize - _size) / 2,
              top: -(_effectSize - _size) / 2,
              width: _effectSize,
              height: _effectSize,
              child: LottieImage(
                key: ValueKey(('effect', _playingToken)),
                lottieUrl: effectAnimationUrl,
                size: _effectSize,
                memCacheWidth: 128,
                shimmer: false,
                eager: true,
                repeat: false,
                onCompleted: _onEffectCompleted,
              ),
            ),
        ],
      ),
    );
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
  final ValueListenable<ReactionAnimationEvent?>? reactionAnimation;
  final ReactionAnimojiResolver? reactionAnimojiResolver;
  final ValueListenable<List<double>>? uploadProgress;
  final void Function(String messageId)? onReplyTap;
  final void Function(int senderId)? onAvatarTap;
  final ForwardedSourceTap? onForwardedSourceTap;
  final void Function(StickerAttachment sticker)? onStickerTap;
  final void Function(String emoji)? onReactionTap;
  final String? peerName;
  final String? peerAvatarUrl;
  final String? senderNameOverride;
  final String? senderAvatarOverride;
  final ValueListenable<({String id, Offset pos})?>? textSelection;
  final ValueListenable<Offset?>? textSelectionDrag;
  final VoidCallback? onExitTextSelection;
  final String? commentsLabel;
  final VoidCallback? onCommentsTap;

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
    this.reactionAnimation,
    this.reactionAnimojiResolver,
    this.uploadProgress,
    this.onReplyTap,
    this.onAvatarTap,
    this.onForwardedSourceTap,
    this.onStickerTap,
    this.onReactionTap,
    this.peerName,
    this.peerAvatarUrl,
    this.senderNameOverride,
    this.senderAvatarOverride,
    this.textSelection,
    this.textSelectionDrag,
    this.onExitTextSelection,
    this.commentsLabel,
    this.onCommentsTap,
  });

  bool _computeHasPhotoWithCaption() {
    final attachments = _contentAttachments;
    if (attachments.isEmpty) return false;
    final hasPhoto = attachments.any((a) => a is PhotoAttachment);
    final hasCaption = _contentText?.isNotEmpty ?? false;
    return hasPhoto && hasCaption;
  }

  bool _computeHasMultiplePhotosNoCaption() {
    final attachments = _contentAttachments;
    if (attachments.isEmpty) return false;
    final photoCount = attachments.whereType<PhotoAttachment>().length;
    final hasCaption = _contentText?.isNotEmpty ?? false;
    return photoCount >= 2 && !hasCaption;
  }

  ForwardedMessageAttachment? get _forwarded => message.forwardedAttachment;

  List<MessageAttachment> get _contentAttachments {
    final forwarded = _forwarded;
    if (forwarded != null) {
      if (forwarded.originalContact != null) {
        return [forwarded.originalContact!];
      }
      return forwarded.originalAttachments
              ?.where((a) => a is! InlineKeyboardAttachment)
              .toList() ??
          const [];
    }
    return message.attachments
            ?.where((a) => a is! InlineKeyboardAttachment)
            .toList() ??
        const [];
  }

  MessageAttachment? get _primaryAttachment {
    final attachments = _contentAttachments;
    return attachments.isEmpty ? null : attachments.first;
  }

  String? get _contentText {
    final forwarded = _forwarded;
    return forwarded == null ? message.text : forwarded.originalText;
  }

  bool get _showsSenderName =>
      !isMe && chatType == "CHAT" && prevMessage?.senderId != message.senderId;

  bool get _stretchesTextRow => message.replyInfo != null || _showsSenderName;

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
    return _primaryAttachment is ShareAttachment;
  }

  bool get _isVideoNote {
    final first = _primaryAttachment;
    return first is VideoAttachment && first.isNote;
  }

  bool get _isSticker => _primaryAttachment is StickerAttachment;

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
    final attachments = _contentAttachments;
    if (attachments.isNotEmpty) {
      final first = attachments.first;
      if (first is ContactAttachment) return MessageType.attachment;
      if (first is UnknownAttachment) return MessageType.text;
      if (first.type == AttachmentType.audio) {
        return _forwarded == null ? MessageType.voice : MessageType.attachment;
      }
      if (first is ShareAttachment) {
        return AppLinkPreview.current.value
            ? MessageType.attachment
            : MessageType.text;
      }
      return MessageType.attachment;
    }

    if (_forwarded != null) return MessageType.text;

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

  static const double _replyWidthShare = 0.75;

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
    final name = senderNameOverride ?? ContactCache.get(message.senderId);
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
    final senderAvatar =
        senderAvatarOverride ?? ContactCache.getAvatar(message.senderId);
    final displaySender =
        senderNameOverride ?? ContactCache.get(message.senderId);
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
      if (message.isSilentBotStart) return const SizedBox.shrink();
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
    final hasReactions = _hasReactions();
    final hasPhotoCap =
        _computeHasPhotoWithCaption() ||
        (contentType == MessageType.attachment &&
            hasReactions &&
            !_isSticker &&
            !_isVideoNote &&
            _jumboAnimojiUrls == null);
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
    final showSenderName = _showsSenderName;

    final keyboard = _inlineKeyboard;
    final isVideoNote = _isVideoNote;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = isVideoNote
        ? math.min(screenWidth - 24, 560.0)
        : math.min(screenWidth * 0.75, 560.0);
    final noBubbleBackground =
        isVideoNote || _isSticker || jumboAnimoji != null;
    final bubbleColor = noBubbleBackground
        ? Colors.transparent
        : (isMe ? cs.primaryContainer : cs.surfaceContainerHighest);

    BubbleContext makeCtx({bool metaInFooter = false}) => BubbleContext(
      context: context,
      cs: cs,
      text: textColor,
      metaInFooter: metaInFooter,
      shape: shape,
      contentType: contentType,
      hasPhotoWithCaption: hasPhotoCap,
      hasMultiplePhotosNoCaption: hasMultiPhotos,
      message: message,
      isMe: isMe,
      myId: myId,
      chatType: chatType,
      chatId: chatId,
      chatName: peerName,
      photoActions: photoActions,
      overrideStatus: overrideStatus,
      otherReadTime: otherReadTime,
      uploadProgress: uploadProgress,
      onStickerTap: onStickerTap,
      onForwardedSourceTap: onForwardedSourceTap,
      reactionInfo: _resolveReactionInfo(),
      selectable: _wrapSelectable,
    );

    final reactionsInside = contentType != MessageType.text;

    final reply = message.replyInfo;

    final bool hasCommentsFooter = onCommentsTap != null;
    final EdgeInsets containerPadding = hasCommentsFooter
        ? EdgeInsets.zero
        : padding;

    final Widget contentWithReactions = reactionsInside
        ? _contentWithReactionsFooter(
            cs,
            makeCtx,
            inset: padding == EdgeInsets.zero
                ? const EdgeInsets.fromLTRB(8, 4, 8, 6)
                : const EdgeInsets.only(top: 4),
          )
        : reactionsListenable != null
        ? ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: reactionsListenable!,
            builder: (context, _, _) => _buildContent(makeCtx()),
          )
        : _buildContent(makeCtx());

    final Widget? senderHeader = showSenderName
        ? _buildSenderHeader(cs, padding == EdgeInsets.zero)
        : null;

    final Widget innerContent =
        contentType == MessageType.text &&
            jumboAnimoji == null &&
            _stretchesTextRow
        ? IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (senderHeader != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: senderHeader,
                  ),
                if (reply != null) ...[
                  _CapIntrinsicWidth(
                    cap: maxBubbleWidth * _replyWidthShare,
                    child: _buildReplyQuote(context, cs, textColor, reply),
                  ),
                  const SizedBox(height: 4),
                ],
                contentWithReactions,
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?senderHeader,
              if (reply == null)
                contentWithReactions
              else
                _HeaderAboveMatchWidth(
                  content: contentWithReactions,
                  header: Padding(
                    padding: EdgeInsets.only(
                      left: padding == EdgeInsets.zero ? 8 : 0,
                      right: padding == EdgeInsets.zero ? 8 : 0,
                      bottom: 4,
                    ),
                    child: _buildReplyQuote(context, cs, textColor, reply),
                  ),
                ),
            ],
          );

    final Widget bubbleBox = ListenableBuilder(
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
        padding: containerPadding,
        child: child,
      ),
      child: hasCommentsFooter
          ? _StackMatchTopWidth(
              growForBottom: true,
              top: Padding(padding: padding, child: innerContent),
              bottom: _buildCommentsFooter(cs),
            )
          : innerContent,
    );

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
              const SizedBox(width: 30),
            Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (keyboard != null)
                  _StackMatchTopWidth(
                    top: bubbleBox,
                    bottom: _buildInlineKeyboard(context, cs, keyboard),
                  )
                else
                  bubbleBox,
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsFooter(ColorScheme cs) {
    final label = commentsLabel ?? 'Комментарии';
    final accent = isMe ? cs.onPrimaryContainer : cs.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCommentsTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(
              height: 0.5,
              thickness: 0.5,
              color: cs.onSurfaceVariant.withValues(alpha: 0.18),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(Symbols.mode_comment, size: 19, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: accent,
                      ),
                    ),
                  ),
                  Icon(
                    Symbols.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ],
              ),
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
    final isClipboard = button.type == 'CLIPBOARD';
    return Material(
      color: cs.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onInlineButtonTap(context, keyboard, button),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(isClipboard ? 26 : 12, 10, 12, 10),
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
            if (isClipboard)
              Positioned(
                top: 6,
                right: 8,
                child: Icon(
                  Symbols.content_copy,
                  size: 15,
                  weight: 500,
                  color: cs.primary.withValues(alpha: 0.85),
                ),
              ),
          ],
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
      case 'CLIPBOARD':
        final payload = button.payload;
        if (payload == null || payload.isEmpty) return;
        await copyTextEntity(context, payload, 'Скопировано');
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
          entryPoint: WebAppEntryPoint.inlineButton,
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

  bool _hasReactions() {
    final info = ReactionInfo.fromMap(_resolveReactionInfo());
    return info != null && info.counters.isNotEmpty;
  }

  Widget _contentWithReactionsFooter(
    ColorScheme cs,
    BubbleContext Function({bool metaInFooter}) makeCtx, {
    required EdgeInsets inset,
  }) {
    final listenable = reactionsListenable;
    if (listenable != null) {
      return ValueListenableBuilder<Map<String, dynamic>?>(
        valueListenable: listenable,
        builder: (context, info, _) =>
            _reactionsFooterLayout(cs, makeCtx, info, inset: inset),
      );
    }
    final info = message.payload?['reactionInfo'];
    return _reactionsFooterLayout(
      cs,
      makeCtx,
      info is Map ? info : null,
      inset: inset,
    );
  }

  Widget _reactionsFooterLayout(
    ColorScheme cs,
    BubbleContext Function({bool metaInFooter}) makeCtx,
    Map? info, {
    required EdgeInsets inset,
  }) {
    final chips = _buildReactionChipsFor(cs, ReactionInfo.fromMap(info));
    if (chips.isEmpty) return _buildContent(makeCtx());

    final carriesMeta =
        _contentType == MessageType.attachment ||
        _contentType == MessageType.voice;
    final ctx = makeCtx(metaInFooter: carriesMeta);

    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContent(ctx),
          Padding(
            padding: inset,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _ReactionsWrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: chips,
                  ),
                ),
                if (carriesMeta) ...[
                  const SizedBox(width: 8),
                  ctx.footerMeta(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
            if (isSendingStatus(status))
              SendingClockIcon(color: statusVisual.color, size: 13)
            else
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

  Widget _buildReactionsBarFor(
    ColorScheme cs,
    Map? info, {
    EdgeInsets inset = const EdgeInsets.only(top: 4),
  }) {
    final chips = _buildReactionChipsFor(cs, ReactionInfo.fromMap(info));
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: inset,
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
            if (_resolveReactionAnimoji(c.reaction) case final animoji?)
              _ReactionAnimojiGlyph(
                key: ValueKey((message.id, c.reaction)),
                messageId: message.id,
                emoji: c.reaction,
                animoji: animoji,
                animation: reactionAnimation,
              )
            else
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

  Animoji? _resolveReactionAnimoji(String emoji) =>
      reactionAnimojiResolver?.call(emoji) ?? animojiModule.findByEmoji(emoji);

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

  Widget _buildControlContent(ColorScheme cs) => ControlBubble(
    key: ValueKey('control_${message.id}'),
    message: message,
    cs: cs,
    onUserTap: onAvatarTap,
  );

  Widget _wrapSelectable(Widget textWidget) {
    final listenable = textSelection;
    if (listenable == null || message.selectableText == null) {
      return textWidget;
    }
    return ValueListenableBuilder<({String id, Offset pos})?>(
      valueListenable: listenable,
      builder: (context, req, child) {
        if (req == null || req.id != message.id) return child!;
        return SelectableMessageText(
          initialGlobalPosition: req.pos,
          dragPosition: textSelectionDrag,
          onExit: onExitTextSelection ?? () {},
          child: child!,
        );
      },
      child: textWidget,
    );
  }

  Widget _buildTextContent(BubbleContext ctx) => DecryptedContent(
    accountId: message.accountId,
    chatId: message.chatId,
    messageId: message.id,
    cipherText: message.text ?? '',
    builder: (decryption) => _buildTextContentBody(ctx, decryption),
  );

  Widget _buildTextContentBody(
    BubbleContext ctx,
    MessageDecryption? decryption,
  ) {
    final attachments = message.attachments;
    final isForwardedContact =
        attachments != null &&
        attachments.isNotEmpty &&
        attachments.first is ForwardedMessageAttachment &&
        (attachments.first as ForwardedMessageAttachment).originalContact !=
            null;

    final forwarded = message.forwardedAttachment;
    final isForwarded = forwarded != null && !isForwardedContact;

    final reactionChips = _buildReactionChipsFor(
      ctx.cs,
      ReactionInfo.fromMap(ctx.reactionInfo),
    );
    final hasReactions = reactionChips.isNotEmpty;

    final activeFontFamily = Theme.of(
      ctx.context,
    ).textTheme.bodyLarge?.fontFamily;
    final textStyle = TextStyle(
      color: ctx.text,
      fontSize: 16,
      height: 1.3,
      fontFamily: activeFontFamily,
      fontVariations: activeFontFamily == 'Inter'
          ? const [FontVariation('wght', 300)]
          : null,
    );
    final ranges = message.formatRanges;
    final decryptedText = decryption?.plaintext;

    final metaRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (decryption?.isDecrypted ?? false) ...[
          Icon(Symbols.lock, size: 11, weight: 700, fill: 1, color: ctx.dim),
          const SizedBox(width: 3),
        ],
        Text(
          message.status == 'EDITED' ? '${ctx.clockText} ред.' : ctx.clockText,
          style: TextStyle(color: ctx.dim, fontSize: 10),
        ),
        if (isMe) ...[const SizedBox(width: 4), ctx.statusIcon()],
        if (message.deleted) ...[const SizedBox(width: 4), ctx.deletedIcon()],
      ],
    );

    final Widget textWidget;
    if (decryption?.state == MessageDecryptionState.wrongKey) {
      textWidget = _wrapSelectable(
        Text(
          'неверный ключ',
          style: textStyle.copyWith(
            color: ctx.cs.error,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    } else if (decryptedText != null) {
      textWidget = _wrapSelectable(Text(decryptedText, style: textStyle));
    } else if (isForwarded) {
      textWidget = _buildForwardedInlineText(ctx, forwarded);
    } else if (FormattedMessageText.isFormatted(message.text, ranges)) {
      textWidget = _wrapSelectable(
        FormattedMessageText(
          text: message.text!,
          ranges: ranges,
          style: textStyle,
        ),
      );
    } else {
      textWidget = _wrapSelectable(Text(message.text ?? '', style: textStyle));
    }

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
                  child: metaRow,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return _TextWithMeta(text: textWidget, meta: metaRow);
  }

  Widget _buildReplyQuote(
    BuildContext context,
    ColorScheme cs,
    Color textColor,
    ReplyInfo reply,
  ) {
    final accent = _senderColor(reply.senderId);
    final name = reply.senderId == myId
        ? 'Вы'
        : (ContactCache.get(reply.senderId) ?? 'Сообщение');
    final rawPreview = reply.previewText();
    final quotedId = reply.messageId;

    if (reply.missing) {
      return Container(
        padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: accent.withValues(alpha: 0.10),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Text(
          'сообщение удалено',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor.withValues(alpha: 0.7),
            fontSize: 13,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

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
          if (rawPreview.isNotEmpty)
            DecryptedContent(
              accountId: message.accountId,
              chatId: message.chatId,
              messageId: quotedId ?? '',
              cipherText: quotedId == null ? '' : rawPreview,
              builder: (decryption) => Text(
                decryption?.state == MessageDecryptionState.wrongKey
                    ? 'неверный ключ'
                    : (decryption?.plaintext ?? rawPreview),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: decryption?.state == MessageDecryptionState.wrongKey
                      ? cs.error
                      : textColor.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontStyle:
                      decryption?.state == MessageDecryptionState.wrongKey
                      ? FontStyle.italic
                      : null,
                ),
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
    final origText = forwarded.originalText;
    final hasOrigText = origText != null && origText.isNotEmpty;
    final forwardedCtx = _forwardedContext(ctx, forwarded);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ForwardedHeader(
          ctx: ctx,
          forwarded: forwarded,
          padding: EdgeInsets.zero,
        ),
        if (hasOrigText) ...[
          const SizedBox(height: 2),
          forwardedCtx.caption(),
        ] else ...[
          const SizedBox(height: 2),
          _wrapSelectable(
            Text(
              message.text ?? '',
              style: TextStyle(color: ctx.text, fontSize: 16, height: 1.3),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAttachmentContent(BubbleContext ctx) {
    final attachments = message.attachments;
    if (attachments == null || attachments.isEmpty) {
      return _buildTextContent(ctx);
    }

    final first = attachments.first;
    if (first is ForwardedMessageAttachment) {
      return _buildForwardedAttachmentContent(ctx, first);
    }

    return _buildNativeAttachmentContent(ctx, attachments);
  }

  BubbleContext _forwardedContext(
    BubbleContext ctx,
    ForwardedMessageAttachment forwarded,
  ) => ctx.withPresentation(
    BubblePresentation(
      text: forwarded.originalText,
      formatRanges: forwarded.originalFormatRanges,
      sourceMessageId: forwarded.originalMessageId,
      sourceChatId: forwarded.originalChatId,
    ),
  );

  Widget _buildForwardedAttachmentContent(
    BubbleContext ctx,
    ForwardedMessageAttachment forwarded,
  ) {
    final forwardedCtx = _forwardedContext(ctx, forwarded);
    final attachments =
        forwarded.originalAttachments
            ?.where((a) => a is! InlineKeyboardAttachment)
            .toList() ??
        const <MessageAttachment>[];
    final content = _buildNativeAttachmentContent(
      forwardedCtx,
      attachments,
      contact: forwarded.originalContact,
      hasContentAbove: true,
    );
    final primary =
        forwarded.originalContact ??
        (attachments.isEmpty ? null : attachments.first);
    final floatingHeader =
        primary is StickerAttachment ||
        (primary is VideoAttachment && primary.isNote);

    if (floatingHeader) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ForwardedHeaderFloating(ctx: ctx, forwarded: forwarded),
          const SizedBox(height: 6),
          content,
        ],
      );
    }

    return _HeaderAboveMatchWidth(
      content: content,
      header: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ForwardedHeader(ctx: ctx, forwarded: forwarded),
      ),
    );
  }

  Widget _buildNativeAttachmentContent(
    BubbleContext ctx,
    List<MessageAttachment> attachments, {
    ContactAttachment? contact,
    bool hasContentAbove = false,
  }) {
    if (contact != null) {
      return ContactBubble(ctx: ctx, contact: contact);
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

    return PhotoBubble(
      ctx: ctx,
      photos: photos,
      hasContentAbove: hasContentAbove,
    );
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
      case AttachmentType.audio:
        return Padding(
          padding: _paddingFor(MessageType.voice, ctx.shape),
          child: _buildVoiceAttachment(ctx, attachment as AudioAttachment),
        );
      default:
        return _buildTextContent(ctx);
    }
  }

  Widget _buildVoiceContent(BubbleContext ctx) {
    AudioAttachment? audio;
    final attaches = message.attachments;
    if (attaches != null && attaches.isNotEmpty) {
      for (final a in attaches) {
        if (a is AudioAttachment) {
          audio = a;
          break;
        }
      }
    }

    return _buildVoiceAttachment(ctx, audio);
  }

  Widget _buildVoiceAttachment(BubbleContext ctx, AudioAttachment? audio) {
    var duration = ((audio?.duration ?? 0) / 1000).round();
    var url = audio?.fileUrl ?? audio?.baseUrl ?? '';

    if (duration == 0 && url.isEmpty) {
      final payload = message.payload;
      final voice = payload?['voice'] as Map<String, dynamic>?;
      duration = ((voice?['duration'] as int? ?? 0) / 1000).round();
      url = voice?['url']?.toString() ?? '';
    }

    final cachedTranscription = TranscriptionCache.get(ctx.sourceMessageId);

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
      waveData: audio?.waveform,
      chatId: message.chatId,
      messageId: message.id,
      sourceChatId: ctx.sourceChatId,
      sourceMessageId: ctx.sourceMessageId,
      senderId: message.senderId,
      audioId: audio?.audioId,
      preloadedText: cachedTranscription?.text,
      uploadProgress: ctx.uploadProgress,
    );
  }
}
