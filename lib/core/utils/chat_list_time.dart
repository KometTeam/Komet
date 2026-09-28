import 'package:intl/intl.dart';

import 'format.dart';

// #***! подпись времени в списке чатов: сегодня время, вчера, день недели,
// #***! число и месяц в этом году, короткая дата для прошлых лет
enum ChatListTimeKind { time, yesterday, weekday, dayMonth, date }

class ChatListTimeLabels {
  final String locale;
  final String yesterday;
  final String datePattern;

  const ChatListTimeLabels({
    required this.locale,
    required this.yesterday,
    required this.datePattern,
  });
}

int _calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

ChatListTimeKind chatListTimeKind(DateTime time, DateTime now) {
  final days = _calendarDaysBetween(time, now);
  if (days <= 0) return ChatListTimeKind.time;
  if (days == 1) return ChatListTimeKind.yesterday;
  if (days < 7) return ChatListTimeKind.weekday;
  if (time.year == now.year) return ChatListTimeKind.dayMonth;
  return ChatListTimeKind.date;
}

String formatChatListTime(
  DateTime time, {
  required DateTime now,
  required ChatListTimeLabels labels,
}) => switch (chatListTimeKind(time, now)) {
  ChatListTimeKind.time => formatClock(time),
  ChatListTimeKind.yesterday => labels.yesterday,
  ChatListTimeKind.weekday => _capitalized(
    DateFormat.E(labels.locale).format(time),
  ),
  ChatListTimeKind.dayMonth => DateFormat.MMMd(labels.locale).format(time),
  ChatListTimeKind.date => DateFormat(
    labels.datePattern,
    labels.locale,
  ).format(time),
};

// #***! «пн» из intl в списке чатов пишем как «Пн»
String _capitalized(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Duration untilNextMidnight(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1).difference(now);
