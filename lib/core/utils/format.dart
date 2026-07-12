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

String pad2(int n) => n.toString().padLeft(2, '0');

String pluralRu(int n, String one, String few, String many) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return many;
  switch (n % 10) {
    case 1:
      return one;
    case 2:
    case 3:
    case 4:
      return few;
    default:
      return many;
  }
}

String formatVoiceElapsed(int ms) {
  final totalSec = ms ~/ 1000;
  final m = totalSec ~/ 60;
  final s = pad2(totalSec % 60);
  final ds = (ms % 1000) ~/ 100;
  return '$m:$s,$ds';
}

final RegExp _phoneNonDigits = RegExp(r'[^0-9]');

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
}

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

String formatFileStamp(DateTime t) =>
    '${t.year}${pad2(t.month)}${pad2(t.day)}_'
    '${pad2(t.hour)}${pad2(t.minute)}${pad2(t.second)}';

String formatClock(DateTime dt, {bool withSeconds = false}) => withSeconds
    ? '${pad2(dt.hour)}:${pad2(dt.minute)}:${pad2(dt.second)}'
    : '${pad2(dt.hour)}:${pad2(dt.minute)}';

String formatDateWords(DateTime dt) =>
    '${dt.day} ${kRuMonthsShort[dt.month - 1]} ${dt.year}';

String formatDateNumeric(DateTime dt) =>
    '${pad2(dt.day)}.${pad2(dt.month)}.${dt.year}';

String formatDateTimeNumeric(DateTime dt) =>
    '${formatDateNumeric(dt)} ${formatClock(dt)}';

String formatDateTimeWords(DateTime dt) =>
    '${formatDateWords(dt)}, ${formatClock(dt)}';

String formatLastSeen(int secondsSinceEpoch) {
  final dt = DateTime.fromMillisecondsSinceEpoch(secondsSinceEpoch * 1000);
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 2) return 'Был(-а) только что';
  if (diff.inMinutes < 60) return 'Был(-а) ${diff.inMinutes} мин назад';
  if (diff.inHours < 24) return 'Был(-а) ${diff.inHours} ч назад';
  if (diff.inDays < 7) return 'Был(-а) ${diff.inDays} дн назад';
  return 'Был(-а) ${formatDateWords(dt)}';
}

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

String? formatGender(dynamic raw) {
  if (raw is! int) return null;
  if (raw == 1) return 'Мужской';
  if (raw == 2) return 'Женский';
  return null;
}
