import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/text_format.dart';
import '../../../../models/attachment.dart';
import '../../formatted_message_text.dart';
import '../../sending_clock_icon.dart';
import '../../photo_viewer.dart';

enum MessageType { text, attachment, voice, control }

enum BubbleShape { singleTop, singleBottom, singleMiddle, groupedMiddle }

typedef ForwardedSourceTap =
    void Function(ForwardedMessageAttachment forwarded);

final Expando<({bool full, String text})> _clockTextCache = Expando();

class BubblePresentation {
  final String? text;
  final List<FormatRange> formatRanges;
  final String? sourceMessageId;
  final int? sourceChatId;

  const BubblePresentation({
    this.text,
    this.formatRanges = const [],
    this.sourceMessageId,
    this.sourceChatId,
  });
}

({IconData icon, Color color}) messageStatusVisual(
  String? status, {
  required Color dimColor,
  Color readColor = kReadReceiptBlue,
  Color errorColor = Colors.redAccent,
}) {
  switch (status) {
    case 'sending':
    case 'pending':
      return (icon: Symbols.schedule, color: dimColor);
    case null:
    case 'sent':
      return (icon: Symbols.check, color: dimColor);
    case 'delivered':
      return (icon: Symbols.done_all, color: dimColor);
    case 'read':
      return (icon: Symbols.done_all, color: readColor);
    case 'error':
      return (icon: Symbols.error, color: errorColor);
    default:
      return (icon: Symbols.check, color: dimColor);
  }
}

class BubbleContext {
  static const double photoMaxSize = 280.0;
  static const double photoMinSize = 100.0;
  static const double captionedMediaMinWidth = 200.0;
  static const double photoBorderRadius = 12.0;
  static const double bubbleBorderRadius = 20.0;
  static const double captionPaddingHorizontal = 10.0;
  static const double captionPaddingRight = 6.0;
  static const double captionPaddingTop = 6.0;
  static const double compactTimePadding = 8.0;

  final BuildContext context;
  final ColorScheme cs;
  final Color text;
  final Color dim;
  final BubbleShape shape;
  final MessageType contentType;
  final bool hasPhotoWithCaption;
  final bool hasMultiplePhotosNoCaption;
  final Map? reactionInfo;

  final CachedMessage message;
  final bool isMe;
  final int myId;
  final String chatType;
  final int? chatId;
  final String? chatName;
  final PhotoViewerActions? photoActions;
  final String? overrideStatus;
  final ValueListenable<int>? otherReadTime;
  final ValueListenable<List<double>>? uploadProgress;
  final void Function(StickerAttachment sticker)? onStickerTap;
  final ForwardedSourceTap? onForwardedSourceTap;
  final BubblePresentation? presentation;
  final bool metaInFooter;
  final Widget Function(Widget)? selectable;

  BubbleContext({
    required this.context,
    required this.cs,
    required this.text,
    required this.shape,
    required this.contentType,
    required this.hasPhotoWithCaption,
    required this.hasMultiplePhotosNoCaption,
    required this.message,
    required this.isMe,
    required this.myId,
    required this.chatType,
    this.chatId,
    this.chatName,
    this.photoActions,
    this.overrideStatus,
    this.otherReadTime,
    this.uploadProgress,
    this.onStickerTap,
    this.onForwardedSourceTap,
    this.reactionInfo,
    this.presentation,
    this.metaInFooter = false,
    this.selectable,
  }) : dim = text.withValues(alpha: 0.7);

  String? get contentText =>
      presentation == null ? message.text : presentation!.text;

  List<FormatRange> get contentFormatRanges =>
      presentation == null ? message.formatRanges : presentation!.formatRanges;

  String get sourceMessageId => presentation?.sourceMessageId ?? message.id;

  int get sourceChatId => presentation?.sourceChatId ?? message.chatId;

  BubbleContext withPresentation(BubblePresentation value) => BubbleContext(
    context: context,
    cs: cs,
    text: text,
    shape: shape,
    contentType: contentType,
    hasPhotoWithCaption: hasPhotoWithCaption,
    hasMultiplePhotosNoCaption: hasMultiplePhotosNoCaption,
    message: message,
    isMe: isMe,
    myId: myId,
    chatType: chatType,
    chatId: chatId,
    chatName: chatName,
    photoActions: photoActions,
    overrideStatus: overrideStatus,
    otherReadTime: otherReadTime,
    uploadProgress: uploadProgress,
    onStickerTap: onStickerTap,
    onForwardedSourceTap: onForwardedSourceTap,
    reactionInfo: reactionInfo,
    presentation: value,
    metaInFooter: metaInFooter,
    selectable: selectable,
  );

  String get clockText {
    final full = KometSettings.fullTimestamp.value;
    final cached = _clockTextCache[message];
    if (cached != null && cached.full == full) return cached.text;
    final t = formatClock(
      DateTime.fromMillisecondsSinceEpoch(message.time),
      withSeconds: full,
    );
    _clockTextCache[message] = (full: full, text: t);
    return t;
  }

  Color get systemTint => cs.onPrimaryContainer.withValues(alpha: 0.12);

  Widget caption() {
    final style = TextStyle(color: text, fontSize: 16, height: 1.3);
    final captionText = contentText;
    final ranges = contentFormatRanges;
    final Widget body;
    if (FormattedMessageText.isFormatted(captionText, ranges)) {
      body = FormattedMessageText(
        text: captionText!,
        ranges: ranges,
        style: style,
      );
    } else {
      body = Text(captionText ?? '', style: style);
    }
    final wrap = selectable;
    return wrap == null ? body : wrap(body);
  }

  Widget meta() => metaInFooter ? const SizedBox.shrink() : _metaRow();

  Widget footerMeta() => _metaRow();

  Widget _metaRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(clockText, style: TextStyle(color: dim, fontSize: 11)),
          if (isMe) ...[const SizedBox(width: 4), statusIcon()],
          if (message.deleted) ...[const SizedBox(width: 4), deletedIcon()],
        ],
      ),
    );
  }

  Widget compactTime() {
    if (metaInFooter) return const SizedBox.shrink();

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
            clockText,
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
          if (isMe) ...[
            const SizedBox(width: 3),
            statusIcon(color: Colors.white, size: 12),
          ],
        ],
      ),
    );
  }

  Widget deletedIcon() => Icon(Symbols.delete, size: 13, color: dim);

  Widget statusIcon({Color? color, double size = 14}) {
    final base = overrideStatus ?? message.status;
    final rt = otherReadTime;
    if (rt == null) return _statusIconFor(base, color: color, size: size);
    return ValueListenableBuilder<int>(
      valueListenable: rt,
      builder: (context, readTime, _) => _statusIconFor(
        _readUpgradedStatus(base, readTime),
        color: color,
        size: size,
      ),
    );
  }

  String? _readUpgradedStatus(String? base, int readTime) {
    if ((base == null || base == 'sent') &&
        readTime > 0 &&
        readTime >= message.time) {
      return 'read';
    }
    return base;
  }

  Widget _statusIconFor(String? status, {Color? color, double size = 14}) {
    final v = messageStatusVisual(status, dimColor: color ?? dim);
    if (isSendingStatus(status)) {
      return SendingClockIcon(color: v.color, size: size);
    }
    return Icon(v.icon, size: size, color: v.color);
  }
}
