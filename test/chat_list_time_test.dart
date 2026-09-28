import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:komet/core/utils/chat_list_time.dart';

const _ru = ChatListTimeLabels(
  locale: 'ru',
  yesterday: 'Вчера',
  datePattern: 'dd.MM.yy',
);
const _en = ChatListTimeLabels(
  locale: 'en',
  yesterday: 'Yesterday',
  datePattern: 'M/d/yy',
);

String _ruAt(DateTime time, DateTime now) =>
    formatChatListTime(time, now: now, labels: _ru);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
  });

  final now = DateTime(2026, 9, 24, 10, 30);

  group('label kinds', () {
    test('today shows the time, including the first minute of the day', () {
      expect(_ruAt(DateTime(2026, 9, 24, 0, 0), now), '00:00');
      expect(_ruAt(DateTime(2026, 9, 24, 9, 5), now), '09:05');
    });

    test('a time in the future from a skewed clock shows the time', () {
      expect(_ruAt(DateTime(2026, 9, 24, 23, 50), now), '23:50');
      expect(
        chatListTimeKind(DateTime(2026, 9, 25, 1), now),
        ChatListTimeKind.time,
      );
    });

    test('yesterday follows the calendar, not 24 hours', () {
      final justAfterMidnight = DateTime(2026, 9, 24, 0, 5);
      expect(_ruAt(DateTime(2026, 9, 23, 23, 55), justAfterMidnight), 'Вчера');
      expect(_ruAt(DateTime(2026, 9, 23, 0, 1), now), 'Вчера');
    });

    test('two to six days ago shows the short weekday', () {
      expect(_ruAt(DateTime(2026, 9, 22, 12), now), 'Вт');
      expect(_ruAt(DateTime(2026, 9, 18, 12), now), 'Пт');
      expect(_ruAt(DateTime(2026, 9, 21, 12), now), 'Пн');
      expect(
        formatChatListTime(DateTime(2026, 9, 21, 12), now: now, labels: _en),
        'Mon',
      );
    });

    test('a week or more this year shows day and month', () {
      expect(
        chatListTimeKind(DateTime(2026, 9, 17, 12), now),
        ChatListTimeKind.dayMonth,
      );
      expect(_ruAt(DateTime(2026, 3, 12, 12), now), '12 мар.');
      expect(_ruAt(DateTime(2026, 9, 5, 12), now), '5 сент.');
      expect(_ruAt(DateTime(2026, 9, 17, 12), now), '17 сент.');
      expect(
        formatChatListTime(DateTime(2026, 3, 12, 12), now: now, labels: _en),
        'Mar 12',
      );
    });

    test('earlier years show a short date', () {
      expect(_ruAt(DateTime(2025, 3, 12, 12), now), '12.03.25');
      expect(
        formatChatListTime(DateTime(2025, 3, 12, 12), now: now, labels: _en),
        '3/12/25',
      );
    });
  });

  group('boundaries', () {
    test('yesterday and weekdays stay relative across New Year', () {
      final newYear = DateTime(2027, 1, 2, 9);
      expect(_ruAt(DateTime(2027, 1, 1, 22), newYear), 'Вчера');
      expect(
        chatListTimeKind(DateTime(2026, 12, 30, 12), newYear),
        ChatListTimeKind.weekday,
      );
      expect(_ruAt(DateTime(2026, 12, 20, 12), newYear), '20.12.26');
    });

    test('yesterday across a month boundary', () {
      expect(
        _ruAt(DateTime(2026, 2, 28, 23), DateTime(2026, 3, 1, 8)),
        'Вчера',
      );
    });

    test('time until midnight counts from now', () {
      expect(
        untilNextMidnight(DateTime(2026, 9, 24, 23, 59, 30)),
        const Duration(seconds: 30),
      );
      expect(
        untilNextMidnight(DateTime(2026, 12, 31, 12)),
        const Duration(hours: 12),
      );
    });
  });
}
