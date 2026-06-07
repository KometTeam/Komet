/// Shared formatting helpers (dates, durations, sizes, phone, gender).
library;

const List<String> kRuMonthsShort = [
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

String _two(int n) => n.toString().padLeft(2, '0');

/// "512 Б" / "1.5 КБ" / "3.2 МБ" / "1.1 ГБ" — Cyrillic units, 1 decimal.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
}

/// "m:ss" (e.g. "3:07"); with [padMinutes] the minutes are zero-padded ("03:07").
String formatDurationMmSs(Duration d, {bool padMinutes = false}) {
  final m = d.inMinutes;
  return '${padMinutes ? _two(m) : m}:${_two(d.inSeconds % 60)}';
}

/// "m:ss" from a raw seconds count.
String formatSecondsMmSs(int seconds, {bool padMinutes = false}) =>
    formatDurationMmSs(Duration(seconds: seconds), padMinutes: padMinutes);

/// "HH:mm".
String formatClock(DateTime dt) => '${_two(dt.hour)}:${_two(dt.minute)}';

/// "5 мая 2024".
String formatDateWords(DateTime dt) =>
    '${dt.day} ${kRuMonthsShort[dt.month - 1]} ${dt.year}';

/// "05.04.2024".
String formatDateNumeric(DateTime dt) =>
    '${_two(dt.day)}.${_two(dt.month)}.${dt.year}';

/// "05.04.2024 14:30".
String formatDateTimeNumeric(DateTime dt) =>
    '${formatDateNumeric(dt)} ${formatClock(dt)}';

/// "5 мая 2024, 14:30".
String formatDateTimeWords(DateTime dt) =>
    '${formatDateWords(dt)}, ${formatClock(dt)}';

/// "Был(-а) только что / N мин назад / N ч назад / N дн назад / 5 мая 2024".
String formatLastSeen(int secondsSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000);
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 2) return 'Был(-а) только что';
  if (diff.inMinutes < 60) return 'Был(-а) ${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return 'Был(-а) ${diff.inHours} ч назад';
  if (diff.inDays < 7) return 'Был(-а) ${diff.inDays} дн назад';
  return 'Был(-а) ${formatDateWords(dt)}';
}

/// "+7 (912) 345-67-89" for RU numbers, "+digits" otherwise.
/// Accepts an int phone or a string; returns null if there is no usable number.
String? formatPhone(dynamic raw) {
  String? digits;
  if (raw is int && raw > 0) {
    digits = raw.toString();
  } else if (raw is String && raw.isNotEmpty && raw != '***') {
    digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
  }
  if (digits == null) return null;
  if (digits.length == 11 && digits.startsWith('7')) {
    return '+${digits[0]} (${digits.substring(1, 4)}) '
        '${digits.substring(4, 7)}-${digits.substring(7, 9)}-${digits.substring(9)}';
  }
  return '+$digits';
}

/// 1 → "Мужской", 2 → "Женский", anything else → null.
String? formatGender(dynamic raw) {
  if (raw is! int) return null;
  if (raw == 1) return 'Мужской';
  if (raw == 2) return 'Женский';
  return null;
}
