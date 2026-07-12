import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:komet/core/storage/chat_activity_store.dart';
import 'package:komet/frontend/widgets/animated_text_swap.dart';

class AnimatedChatTile extends StatefulWidget {
  final Widget child;
  final String id;
  final int revision;
  final bool isNew;

  const AnimatedChatTile({
    required super.key,
    required this.child,
    required this.id,
    required this.revision,
    required this.isNew,
  });

  @override
  State<AnimatedChatTile> createState() => _AnimatedChatTileState();
}

class _AnimatedChatTileState extends State<AnimatedChatTile>
    with SingleTickerProviderStateMixin {
  static const Duration _moveDuration = Duration(milliseconds: 300);
  static const Duration _enterDuration = Duration(milliseconds: 260);

  AnimationController? _controller;
  double? _lastContentY;
  late int _lastRevision;
  double _moveDy = 0;
  bool _entering = false;

  @override
  void initState() {
    super.initState();
    _lastRevision = widget.revision;
    if (widget.isNew) {
      _entering = true;
      final c = _controller = AnimationController(
        vsync: this,
        duration: _enterDuration,
      );
      c.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _entering = false);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _lastContentY = _measureContentY();
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedChatTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revision == _lastRevision) return;
    _lastRevision = widget.revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _runMove();
    });
  }

  double? _measureContentY() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    try {
      return RenderAbstractViewport.of(box).getOffsetToReveal(box, 0.0).offset;
    } catch (_) {
      return null;
    }
  }

  void _runMove() {
    final newY = _measureContentY();
    final oldY = _lastContentY;
    if (newY != null) _lastContentY = newY;
    if (_entering || oldY == null || newY == null) return;
    final dy = oldY - newY;
    if (dy.abs() < 1.0 || dy.abs() > 2000) return;
    final c = _controller ??= AnimationController(vsync: this);
    c.duration = _moveDuration;
    setState(() => _moveDy = dy);
    c.forward(from: 0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return SizedBox(child: widget.child);
    return SizedBox(
      child: AnimatedBuilder(
        animation: c,
        builder: (context, child) {
          if (_entering) {
            final t = Curves.easeOut.transform(c.value);
            return Opacity(
              opacity: t,
              child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
            );
          }
          if (_moveDy != 0) {
            final t = 1 - Curves.easeOutCubic.transform(c.value);
            return Transform.translate(
              offset: Offset(0, _moveDy * t),
              child: child,
            );
          }
          return child!;
        },
        child: widget.child,
      ),
    );
  }
}

class ActivitySubtitle extends StatefulWidget {
  const ActivitySubtitle({
    super.key,
    required this.chatId,
    required this.child,
  });

  final int chatId;
  final Widget child;

  @override
  State<ActivitySubtitle> createState() => _ActivitySubtitleState();
}

class _ActivitySubtitleState extends State<ActivitySubtitle> {
  ChatActivity _lastActivity = ChatActivity.typing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<ChatActivity?>(
      valueListenable: ChatActivityStore.instance.listenable(widget.chatId),
      child: widget.child,
      builder: (context, activity, base) {
        if (activity != null) _lastActivity = activity;
        return AnimatedTextSwap(
          showAlternate: activity != null,
          alternate: Text(
            _lastActivity.label.toLowerCase(),
            style: TextStyle(
              color: cs.primary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          child: base!,
        );
      },
    );
  }
}
