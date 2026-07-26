import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../backend/modules/messages.dart';
import '../../../../models/attachment.dart';

class _ControlSegment {
  final String text;
  final int? userId;

  const _ControlSegment(this.text, [this.userId]);
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
    final sender = _ControlSegment(_nameOf(senderId), senderId);

    switch (control.event) {
      case 'new':
        return _ControlText([
          sender,
          const _ControlSegment(' создал(а) чат'),
        ], senderId);
      case 'add':
        final ids = control.userIds ?? const <int>[];
        final segments = <_ControlSegment>[
          sender,
          const _ControlSegment(' добавил(а) '),
        ];
        for (var i = 0; i < ids.length; i++) {
          if (i > 0) segments.add(const _ControlSegment(', '));
          segments.add(_ControlSegment(_nameOf(ids[i]), ids[i]));
        }
        return _ControlText(segments, ids.length == 1 ? ids.first : null);
      case 'leave':
        return _ControlText([
          sender,
          const _ControlSegment(' покинул(а) чат'),
        ], senderId);
      case 'joinByLink':
        return _ControlText([
          sender,
          const _ControlSegment(' присоединился(-ась) к чату'),
        ], senderId);
      case 'pin':
        return _ControlText([
          sender,
          const _ControlSegment(' закрепил(а) сообщение'),
        ], senderId);
      default:
        return _ControlText([
          _ControlSegment(control.title ?? ''),
        ], _mentionedUser(control) ?? senderId);
    }
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
                style: interactive && segment.userId != null
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
    if (!interactive || tapUserId == null) return bubble;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onUserTap!(tapUserId),
      child: bubble,
    );
  }
}
