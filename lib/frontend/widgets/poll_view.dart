import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../main.dart';
import '../../core/utils/format.dart';
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

class _PollViewState extends State<PollView>
    with SingleTickerProviderStateMixin {
  final Set<int> _selected = {};
  bool _voting = false;
  bool _justVoted = false;
  bool _resultsShown = false;

  late final AnimationController _reveal;
  late final CurvedAnimation _morph;
  late final CurvedAnimation _fill;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    );
    _morph = CurvedAnimation(
      parent: _reveal,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );
    _fill = CurvedAnimation(
      parent: _reveal,
      curve: const Interval(0.42, 1.0, curve: Curves.easeOutCubic),
    );
    pollsModule.fetch(
      widget.chatId,
      widget.messageId,
      widget.pollId,
      force: false,
    );
  }

  @override
  void dispose() {
    _morph.dispose();
    _fill.dispose();
    _reveal.dispose();
    super.dispose();
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
      if (ok) {
        _justVoted = true;
        _selected.clear();
      }
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

    if (showResults && !_resultsShown) {
      _resultsShown = true;
      if (_justVoted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _reveal.forward(from: 0.0);
        });
      } else {
        _reveal.value = 1.0;
      }
    }

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
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) {
                  final m = _morph.value;
                  final f = _fill.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final a in poll.answers)
                        _buildResultRow(a, poll.total, poll.isMultiple, m, f),
                    ],
                  );
                },
              ),
            ),
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
    return '$kind · ${poll.total} '
        '${pluralRu(poll.total, 'голос', 'голоса', 'голосов')}';
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

  Widget _buildResultRow(
    PollAnswer answer,
    int total,
    bool multiple,
    double m,
    double f,
  ) {
    final pct = total > 0 ? answer.voteCount / total : 0.0;
    final value = answer.rate > 0 ? (answer.rate / 100.0).clamp(0.0, 1.0) : pct;
    final pctLabel = '${(answer.rate > 0 ? answer.rate : pct * 100).round()}%';

    final leadWidth = 30.0 * (1 - m);
    final dotOpacity = (1 - m * 1.8).clamp(0.0, 1.0);
    final fillFactor = (value * f).clamp(0.0, 1.0);

    final dotIcon = multiple
        ? (answer.mine ? Symbols.check_box : Symbols.check_box_outline_blank)
        : (answer.mine
              ? Symbols.radio_button_checked
              : Symbols.radio_button_unchecked);
    final dotColor = answer.mine ? widget.accentColor : widget.dimColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRect(
                child: SizedBox(
                  width: leadWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Opacity(
                      opacity: dotOpacity,
                      child: Icon(dotIcon, size: 20, color: dotColor),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  answer.text,
                  style: TextStyle(color: widget.textColor, fontSize: 14),
                ),
              ),
              ClipRect(
                child: Align(
                  alignment: Alignment.centerRight,
                  widthFactor: m,
                  child: Opacity(
                    opacity: m,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (answer.mine) ...[
                          Icon(
                            Symbols.check_circle,
                            size: 14,
                            color: widget.accentColor,
                          ),
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
                  ),
                ),
              ),
            ],
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.topLeft,
              heightFactor: m,
              widthFactor: m,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fillFactor,
                    minHeight: 6,
                    backgroundColor: widget.dimColor.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.accentColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
