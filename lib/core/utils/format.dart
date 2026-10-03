library;

import '../../l10n/app_localizations.dart';

// #***! русские месяцы, intl ради трёх букв тянуть не хочется
const List<String> _ruMonthsShort = [
  'янв',
  'фев',
  'мар',
  'апр',
  'мая',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];

const List<String> _enMonthsShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _ruWeekdaysShort = [
  'пн',
  'вт',
  'ср',
  'чт',
  'пт',
  'сб',
  'вс',
];

const List<String> _enWeekdaysShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

bool _isRussian(AppLocalizations l10n) => l10n.localeName == 'ru';

String _formatMonthShort(AppLocalizations l10n, int month) =>
    (_isRussian(l10n) ? _ruMonthsShort : _enMonthsShort)[month - 1];

String formatWeekdayShort(AppLocalizations l10n, int weekday) =>
    (_isRussian(l10n) ? _ruWeekdaysShort : _enWeekdaysShort)[weekday - 1];

// #***! ведущий ноль
String pad2(int n) => n.toString().padLeft(2, '0');

// #***! таймер голосового с десятыми
String formatVoiceElapsed(int ms) {
  final totalSec = ms ~/ 1000;
  final m = totalSec ~/ 60;
  final s = pad2(totalSec % 60);
  final ds = (ms % 1000) ~/ 100;
  return '$m:$s,$ds';
}

final RegExp _phoneNonDigits = RegExp(r'[^0-9]');

// #***! размер по человечески
String formatBytes(AppLocalizations l10n, int bytes) {
  if (bytes < 1024) return l10n.formatBytesB('$bytes');
  if (bytes < 1024 * 1024) {
    return l10n.formatBytesKb((bytes / 1024).toStringAsFixed(1));
  }
  if (bytes < 1024 * 1024 * 1024) {
    return l10n.formatBytesMb((bytes / (1024 * 1024)).toStringAsFixed(1));
  }
  return l10n.formatBytesGb((bytes / (1024 * 1024 * 1024)).toStringAsFixed(1));
}

// #***! дальше время и даты в разных видах
String formatDurationMmSs(Duration d, {bool padMinutes = false}) {
  final m = d.inMinutes;
  return '${padMinutes ? pad2(m) : m}:${pad2(d.inSeconds % 60)}';
}

String formatSecondsMmSs(int seconds, {bool padMinutes = false}) =>
    formatDurationMmSs(Duration(seconds: seconds), padMinutes: padMinutes);

String formatDurationClock(Duration d) {
  final s = d.inSeconds;
  final sec = pad2(s % 60);
  final m = s ~/ 60;
  if (m >= 60) return '${m ~/ 60}:${pad2(m % 60)}:$sec';
  return '$m:$sec';
}

String formatApproxDuration(AppLocalizations l10n, int ms) {
  final tenths = (ms / 100).round();
  if (tenths < 600) {
    return l10n.formatApproxSeconds('${tenths ~/ 10}', '${tenths % 10}');
  }
  final hundredths = (ms / 600).round();
  return l10n.formatApproxMinutes(
    '${hundredths ~/ 100}',
    pad2(hundredths % 100),
  );
}

String formatFileStamp(DateTime t) =>
    '${t.year}${pad2(t.month)}${pad2(t.day)}_'
    '${pad2(t.hour)}${pad2(t.minute)}${pad2(t.second)}';

String formatClock(DateTime dt, {bool withSeconds = false}) => withSeconds
    ? '${pad2(dt.hour)}:${pad2(dt.minute)}:${pad2(dt.second)}'
    : '${pad2(dt.hour)}:${pad2(dt.minute)}';

String formatDayMonth(AppLocalizations l10n, DateTime dt) =>
    '${dt.day} ${_formatMonthShort(l10n, dt.month)}';

String formatDateWords(AppLocalizations l10n, DateTime dt) =>
    '${formatDayMonth(l10n, dt)} ${dt.year}';

String formatDateNumeric(DateTime dt) =>
    '${pad2(dt.day)}.${pad2(dt.month)}.${dt.year}';

String formatDateTimeNumeric(DateTime dt) =>
    '${formatDateNumeric(dt)} ${formatClock(dt)}';

String formatDateTimeWords(AppLocalizations l10n, DateTime dt) =>
    '${formatDateWords(l10n, dt)}, ${formatClock(dt)}';

// #***! был недавно и подобное для шапки чата
String formatLastSeen(AppLocalizations l10n, int secondsSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000);
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 2) return l10n.lastSeenJustNow;
  if (diff.inMinutes < 60) return l10n.lastSeenMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.lastSeenHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.lastSeenDaysAgo(diff.inDays);
  return l10n.settingsTabLastSeen(formatDateWords(l10n, dt));
}

// #***! телефон разбираем красиво только для российских
String? formatPhone(dynamic raw) {
  String? digits;
  if (raw is int && raw > 0) {
    digits = raw.toString();
  } else if (raw is String && raw.isNotEmpty && raw != '***') {
    digits = raw.replaceAll(_phoneNonDigits, '');
    if (digits.isEmpty) return null;
  }
  if (digits == null) return null;
  if (digits.length == 11 && digits.startsWith('7')) {
    return '+${digits[0]} (${digits.substring(1, 4)}) '
        '${digits.substring(4, 7)}-${digits.substring(7, 9)}-${digits.substring(9)}';
  }
  return '+$digits';
}

String? formatGender(AppLocalizations l10n, dynamic raw) {
  if (raw is! int) return null;
  if (raw == 1) return l10n.genderMale;
  if (raw == 2) return l10n.genderFemale;
  return null;
}
