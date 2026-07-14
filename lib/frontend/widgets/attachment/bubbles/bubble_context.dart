import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/config/komet_settings.dart';
import '../../../../core/utils/format.dart';
import '../../../../models/attachment.dart';
import '../../formatted_message_text.dart';
import '../../photo_viewer.dart';

enum MessageType { text, attachment, voice, control }

enum BubbleShape { singleTop, singleBottom, singleMiddle, groupedMiddle }

final Expando<({bool full, String text})> _clockTextCache = Expando();

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
  static const double photoBorderRadius = 12.0;
  static const double bubbleBorderRadius = 20.0;
  static const double captionPaddingHorizontal = 6.0;
  static const double captionPaddingRight = 4.0;
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
  final PhotoViewerActions? photoActions;
  final String? overrideStatus;
  final ValueListenable<int>? otherReadTime;
  final ValueListenable<List<double>>? uploadProgress;
  final void Function(StickerAttachment sticker)? onStickerTap;

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
    this.photoActions,
    this.overrideStatus,
    this.otherReadTime,
    this.uploadProgress,
    this.onStickerTap,
    this.reactionInfo,
  }) : dim = text.withValues(alpha: 0.7);

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
    final ranges = message.formatRanges;
    if (FormattedMessageText.isFormatted(message.text, ranges)) {
      return FormattedMessageText(
        text: message.text!,
        ranges: ranges,
        style: style,
      );
    }
    return Text(message.text ?? '', style: style);
  }

  Widget meta() {
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
    return Icon(v.icon, size: size, color: v.color);
  }
}
