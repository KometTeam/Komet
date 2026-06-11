import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../main.dart';
import '../../core/utils/haptics.dart';
import '../../models/poll.dart';
import 'custom_notification.dart';

class PollView extends StatefulWidget {
  final int chatId;
  final String messageId;
  final int pollId;
  final int myId;
  final String? fallbackTitle;
  final Color textColor;
  final Color dimColor;
  final Color accentColor;

  const PollView({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.pollId,
    required this.myId,
    required this.textColor,
    required this.dimColor,
    required this.accentColor,
    this.fallbackTitle,
  });

  @override
  State<PollView> createState() => _PollViewState();
}

class _PollViewState extends State<PollView> {
  final Set<int> _selected = {};
  bool _voting = false;

  @override
  void initState() {
    super.initState();
    pollsModule.fetch(
      widget.chatId,
      widget.messageId,
      widget.pollId,
      force: true,
    );
  }

  Future<void> _vote(List<int> answersIds) async {
    if (_voting || answersIds.isEmpty) return;
    Haptics.tap();
    setState(() => _voting = true);
    final ok = await pollsModule.vote(
      widget.chatId,
      widget.messageId,
      widget.pollId,
      answersIds,
    );
    if (!mounted) return;
    setState(() {
      _voting = false;
      if (ok) _selected.clear();
    });
    if (!ok) {
      showCustomNotification(context, 'Не удалось проголосовать');
    }
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
    final showResults = poll != null && poll.votedBy(widget.myId);

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
            poll == null ? 'Загрузка опроса…' : _subtitle(poll),
            style: TextStyle(color: widget.dimColor, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (poll != null && showResults)
            ...poll.answers.map((a) => _buildResultRow(a, poll.total)),
          if (poll != null && !showResults) ...[
            ...poll.answers.map((a) => _buildChoiceRow(a, poll.isMultiple)),
            if (poll.isMultiple) _buildVoteButton(),
          ],
        ],
      ),
    );
  }

  String _subtitle(Poll poll) {
    final kind = poll.isMultiple
        ? 'Несколько вариантов ответа'
        : 'Один вариант ответа';
    if (poll.total == 0) return kind;
    return '$kind · ${_votesLabel(poll.total)}';
  }

  Widget _buildChoiceRow(PollAnswer answer, bool multiple) {
    final selected = _selected.contains(answer.answerId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _voting
            ? null
            : () {
                if (multiple) {
                  setState(() {
                    selected
                        ? _selected.remove(answer.answerId)
                        : _selected.add(answer.answerId);
                  });
                } else {
                  _vote([answer.answerId]);
                }
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            children: [
              Icon(
                multiple
                    ? (selected
                          ? Symbols.check_box
                          : Symbols.check_box_outline_blank)
                    : Symbols.radio_button_unchecked,
                size: 20,
                color: selected ? widget.accentColor : widget.dimColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  answer.text,
                  style: TextStyle(color: widget.textColor, fontSize: 14),
                ),
              ),
              if (_voting && !multiple)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: widget.dimColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteButton() {
    final enabled = _selected.isNotEmpty && !_voting;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: enabled ? () => _vote(_selected.toList()..sort()) : null,
          style: TextButton.styleFrom(
            foregroundColor: widget.accentColor,
            backgroundColor: widget.dimColor.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _voting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.accentColor,
                  ),
                )
              : const Text('Проголосовать'),
        ),
      ),
    );
  }

  Widget _buildResultRow(PollAnswer answer, int total) {
    final pct = total > 0 ? answer.voteCount / total : 0.0;
    final pctLabel = '${(answer.rate > 0 ? answer.rate : pct * 100).round()}%';

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
              if (answer.mine) ...[
                Icon(Symbols.check_circle, size: 14, color: widget.accentColor),
                const SizedBox(width: 4),
              ],
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
