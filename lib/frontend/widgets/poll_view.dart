import 'package:flutter/material.dart';

import '../../main.dart';
import '../../models/poll.dart';

class PollView extends StatefulWidget {
  final int chatId;
  final String messageId;
  final int pollId;
  final String? fallbackTitle;
  final Color textColor;
  final Color dimColor;
  final Color accentColor;

  const PollView({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.pollId,
    required this.textColor,
    required this.dimColor,
    required this.accentColor,
    this.fallbackTitle,
  });

  @override
  State<PollView> createState() => _PollViewState();
}

class _PollViewState extends State<PollView> {
  @override
  void initState() {
    super.initState();
    pollsModule.fetch(widget.chatId, widget.messageId, widget.pollId);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pollsModule,
      builder: (context, _) {
        final poll = pollsModule.get(widget.pollId);
        return _buildCard(poll);
      },
    );
  }

  Widget _buildCard(Poll? poll) {
    final title = poll?.title.isNotEmpty == true
        ? poll!.title
        : (widget.fallbackTitle ?? 'Опрос');

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: widget.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            poll == null
                ? 'Загрузка опроса…'
                : _votesLabel(poll.total),
            style: TextStyle(color: widget.dimColor, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (poll != null)
            ...poll.answers.map((a) => _buildAnswer(a, poll.total)),
        ],
      ),
    );
  }

  Widget _buildAnswer(PollAnswer answer, int total) {
    final pct = total > 0 ? answer.voteCount / total : 0.0;
    final pctLabel = '${(pct * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  answer.text,
                  style: TextStyle(color: widget.textColor, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                pctLabel,
                style: TextStyle(
                  color: widget.dimColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: widget.dimColor.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(widget.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  String _votesLabel(int total) {
    if (total == 0) return 'Нет голосов';
    final mod10 = total % 10;
    final mod100 = total % 100;
    String word;
    if (mod10 == 1 && mod100 != 11) {
      word = 'голос';
    } else if (mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20)) {
      word = 'голоса';
    } else {
      word = 'голосов';
    }
    return '$total $word';
  }
}
