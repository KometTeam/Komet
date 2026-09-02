const List<String> kRuWeekdaysShort = [
  'пн',
  'вт',
  'ср',
  'чт',
  'пт',
  'сб',
  'вс',
];

/// Timestamp in the chat list trailing column.
///
/// Calendar-based, not raw duration: today stays a clock, yesterday and the
/// rest of the week are a day name, then a short date. Relative "N weeks ago"
/// is too wide and too vague for this slot.
String formatChatListTime(int? timestampMillis, {DateTime? now}) {
  if (timestampMillis == null || timestampMillis == 0) return '';
  final t = DateTime.fromMillisecondsSinceEpoch(timestampMillis).toLocal();
  final n = (now ?? DateTime.now()).toLocal();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final days = today.difference(day).inDays;

  if (days <= 0) return formatClock(t);
  if (days == 1) return 'вчера';
  if (days < 7) return kRuWeekdaysShort[t.weekday - 1];
  if (days < 28) {
    final weeks = days ~/ 7;
    return '$weeks нед.';
  }
  if (t.year == n.year) return '${t.day} ${kRuMonthsShort[t.month - 1]}';
  return '${pad2(t.day)}.${pad2(t.month)}.${pad2(t.year % 100)}';
}
