import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/format.dart';

void main() {
  final now = DateTime(2026, 9, 2, 16, 20);

  int ms(DateTime dt) => dt.millisecondsSinceEpoch;

  test('today is a clock', () {
    expect(
      formatChatListTime(ms(DateTime(2026, 9, 2, 9, 4)), now: now),
      '09:04',
    );
  });

  test('yesterday', () {
    expect(
      formatChatListTime(ms(DateTime(2026, 9, 1, 23, 50)), now: now),
      'вчера',
    );
  });

  test('rest of the week is a weekday', () {
    expect(
      formatChatListTime(ms(DateTime(2026, 8, 31, 12)), now: now),
      'пн',
    );
  });

  test('one to three weeks stay compact', () {
    expect(
      formatChatListTime(ms(DateTime(2026, 8, 20, 12)), now: now),
      '1 нед.',
    );
    expect(
      formatChatListTime(ms(DateTime(2026, 8, 12, 12)), now: now),
      '3 нед.',
    );
  });

  test('older same year is a calendar date', () {
    expect(
      formatChatListTime(ms(DateTime(2026, 3, 12, 12)), now: now),
      '12 мар',
    );
  });

  test('previous year is numeric', () {
    expect(
      formatChatListTime(ms(DateTime(2025, 11, 3, 12)), now: now),
      '03.11.25',
    );
  });

  test('empty timestamp', () {
    expect(formatChatListTime(null, now: now), '');
    expect(formatChatListTime(0, now: now), '');
  });
}
