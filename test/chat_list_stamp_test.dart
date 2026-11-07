import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/l10n/app_localizations.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 11, 7, 15, 30);

  String stamp(AppLocalizations l10n, DateTime dt) =>
      formatChatListStamp(l10n, dt, now: now);

  test('today shows the clock', () {
    expect(stamp(ru, DateTime(2026, 11, 7, 0, 5)), '00:05');
    expect(stamp(ru, DateTime(2026, 11, 7, 14, 10)), '14:10');
  });

  test('a message from a skewed clock in the future still shows the clock', () {
    expect(stamp(ru, DateTime(2026, 11, 8, 0, 1)), '00:01');
  });

  test('the last six days show the weekday', () {
    expect(stamp(ru, DateTime(2026, 11, 6, 23, 59)), 'пт');
    expect(stamp(en, DateTime(2026, 11, 2, 9)), 'Mon');
    expect(stamp(ru, DateTime(2026, 11, 1, 12)), 'вс');
  });

  test('a week or more ago in this year shows day and month', () {
    expect(stamp(ru, DateTime(2026, 10, 31, 12)), '31 окт');
    expect(stamp(en, DateTime(2026, 1, 5, 12)), '5 Jan');
  });

  test('earlier years show the full date', () {
    expect(stamp(ru, DateTime(2025, 8, 5, 12)), '05.08.2025');
    expect(stamp(en, DateTime(2025, 12, 31, 23, 59)), '31.12.2025');
  });
}
