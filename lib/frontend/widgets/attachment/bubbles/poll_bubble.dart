import 'package:flutter/material.dart';

import '../../../../models/attachment.dart';
import '../../poll_view.dart';
import 'bubble_context.dart';

class PollBubble extends StatelessWidget {
  final BubbleContext ctx;
  final PollAttachment poll;

  const PollBubble({super.key, required this.ctx, required this.poll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            PollView(
              chatId: ctx.message.chatId,
              messageId: ctx.message.id,
              pollId: poll.pollId,
              myId: ctx.myId,
              fallbackTitle: poll.title ?? ctx.message.text,
              textColor: ctx.text,
              dimColor: ctx.dim,
              accentColor: ctx.isMe
                  ? ctx.cs.onPrimaryContainer
                  : ctx.cs.primary,
            ),
            ctx.meta(),
          ],
        ),
      ),
    );
  }
}
