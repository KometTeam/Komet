import 'package:flutter/material.dart';

import '../../../../widgets/small_spinner.dart';

// #***! плашка с датой между группами сообщений
class DateSeparatorLabel extends StatelessWidget {
  final DateTime date;
  final bool floating;

  const DateSeparatorLabel({
    super.key,
    required this.date,
    this.floating = false,
  });

  static String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);

    if (d == today) return 'Сегодня';
    if (d == yesterday) return 'Вчера';

    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    if (date.year == now.year) {
      return '${date.day} ${months[date.month - 1]}';
    }
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: floating ? 2 : 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateLabel(date),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              fontStyle: floating ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

// #***! разделитель "непрочитанные сообщения" в ленте
class UnreadSeparatorBar extends StatelessWidget {
  const UnreadSeparatorBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Непрочитанные сообщения',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// #***! затухание к нижнему краю ленты (под композером)
class MessageListEdgeFade extends StatelessWidget {
  final double height;

  const MessageListEdgeFade({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [cs.surface, cs.surface.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

// #***! виньетка у верхнего/нижнего края ленты под прозрачным chrome
class MessageListEdgeVignette extends StatelessWidget {
  final bool top;
  final double height;

  const MessageListEdgeVignette({
    super.key,
    required this.top,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: top ? Alignment.topCenter : Alignment.bottomCenter,
            end: top ? Alignment.bottomCenter : Alignment.topCenter,
            colors: [cs.surface, cs.surface.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}

// #***! спиннер подгрузки истории сверху ленты
class MessageListLoadMoreIndicator extends StatelessWidget {
  const MessageListLoadMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: SmallSpinner(size: 22, color: cs.onSurfaceVariant)),
    );
  }
}
