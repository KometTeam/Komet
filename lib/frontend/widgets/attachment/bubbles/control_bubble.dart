import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../models/attachment.dart';
import '../../photo_viewer.dart';

class _ControlSegment {
  final String text;
  final int? userId;
  final bool bold;

  const _ControlSegment(this.text, {this.userId, this.bold = false});
}

class _ControlText {
  final List<_ControlSegment> segments;
  final int? tapUserId;

  const _ControlText(this.segments, this.tapUserId);
}

class ControlBubble extends StatefulWidget {
  final CachedMessage message;
  final ColorScheme cs;
  final void Function(int userId)? onUserTap;

  const ControlBubble({
    super.key,
    required this.message,
    required this.cs,
    this.onUserTap,
  });

  @override
  State<ControlBubble> createState() => _ControlBubbleState();
}

class _ControlBubbleState extends State<ControlBubble> {
  static const double _photoSize = 96;

  final Map<int, TapGestureRecognizer> _recognizers = {};

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _recognizerFor(int userId) => _recognizers.putIfAbsent(
    userId,
    () => TapGestureRecognizer()..onTap = () => widget.onUserTap?.call(userId),
  );

  String _nameOf(int userId) => ContactCache.get(userId) ?? 'Пользователь';

  int? _mentionedUser(ControlAttachment control) {
    final direct = control.userId;
    if (direct != null && direct != 0) return direct;
    final ids = control.userIds;
    if (ids != null && ids.length == 1) return ids.first;
    return null;
  }

  _ControlText _resolveText(ControlAttachment control) {
    final senderId = widget.message.senderId;
    final mine = senderId == widget.message.accountId;
    final sender = mine
        ? const _ControlSegment('Вы', bold: true)
        : _ControlSegment(_nameOf(senderId), userId: senderId, bold: true);
    final senderTap = mine ? null : senderId;
    _ControlSegment action(String byMe, String byOther) =>
        _ControlSegment(mine ? byMe : byOther);
    final title = control.title?.trim();
    final quotedTitle = title == null || title.isEmpty ? null : '«$title»';

    switch (control.event) {
      case 'new':
        return _ControlText([
          sender,
          action(' создали чат', ' создал(а) чат'),
          if (quotedTitle != null) _ControlSegment(' $quotedTitle'),
        ], senderTap);
      case 'add':
        final ids = control.userIds ?? const <int>[];
        final segments = <_ControlSegment>[
          sender,
          action(' добавили ', ' добавил(а) '),
        ];
        for (var i = 0; i < ids.length; i++) {
          if (i > 0) segments.add(const _ControlSegment(', '));
          segments.add(
            _ControlSegment(_nameOf(ids[i]), userId: ids[i], bold: true),
          );
        }
        return _ControlText(segments, ids.length == 1 ? ids.first : null);
      case 'leave':
        return _ControlText([
          sender,
          action(' покинули чат', ' покинул(а) чат'),
        ], senderTap);
      case 'joinByLink':
        return _ControlText([
          sender,
          action(' присоединились к чату', ' присоединился(-ась) к чату'),
        ], senderTap);
      case 'pin':
        return _ControlText([
          sender,
          action(' закрепили сообщение', ' закрепил(а) сообщение'),
        ], senderTap);
      case 'title':
        return _ControlText([
          sender,
          action(' изменили название чата', ' изменил(а) название чата'),
          if (quotedTitle != null) _ControlSegment(' на $quotedTitle'),
        ], senderTap);
      case 'icon':
        return _ControlText([
          sender,
          action(' изменили фото чата', ' изменил(а) фото чата'),
        ], senderTap);
      case ControlAttachment.botStartedEvent:
        final payload = widget.message.botStartPayload;
        return _ControlText([
          const _ControlSegment('Бот запущен'),
          if (payload != null) _ControlSegment(': $payload'),
        ], null);
      default:
        return _ControlText([
          _ControlSegment(control.title ?? ''),
        ], _mentionedUser(control) ?? senderId);
    }
  }

  void _openPhoto(String url) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PhotoViewerScreen.single(url)));
  }

  @override
  Widget build(BuildContext context) {
    final attachments = widget.message.attachments;
    if (attachments == null || attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final control = attachments.first;
    if (control is! ControlAttachment) return const SizedBox.shrink();

    final resolved = _resolveText(control);
    if (resolved.segments.every((s) => s.text.isEmpty)) {
      return const SizedBox.shrink();
    }

    final cs = widget.cs;
    final interactive = widget.onUserTap != null;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            for (final segment in resolved.segments)
              TextSpan(
                text: segment.text,
                style: segment.bold && (interactive || segment.userId == null)
                    ? const TextStyle(fontWeight: FontWeight.w600)
                    : null,
                recognizer: interactive && segment.userId != null
                    ? _recognizerFor(segment.userId!)
                    : null,
              ),
          ],
        ),
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );

    final tapUserId = resolved.tapUserId;
    final line = !interactive || tapUserId == null
        ? bubble
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onUserTap!(tapUserId),
            child: bubble,
          );

    final photo = control.event == 'icon' ? control.imageUrl : null;
    if (photo == null || photo.isEmpty) return line;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        line,
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _openPhoto(control.fullImageUrl ?? photo),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: photo,
              width: _photoSize,
              height: _photoSize,
              memCacheWidth: (_photoSize * 3).round(),
              fit: BoxFit.cover,
              placeholder: (_, _) => ColoredBox(
                color: cs.surfaceContainerHighest,
                child: const SizedBox.square(dimension: _photoSize),
              ),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
