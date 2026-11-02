import 'dart:convert';

// #***! числа то int то строкой, безопасный разбор
int? parseIntOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

List<int> parseIntList(Object? v) =>
    v is List ? v.map(parseIntOrNull).whereType<int>().toList() : const <int>[];

// #***! имя ушло на сервер сырыми байтами UTF-8, а прочитано как Latin-1:
// «Ð¾ÑÐ¿ÑÑÐº» — это «отпуск». Чиним, только если байты дают валидный UTF-8
String? repairLatin1Mojibake(String? value) {
  if (value == null || value.isEmpty) return value;
  var extended = false;
  for (final unit in value.codeUnits) {
    if (unit > 0xFF) return value;
    if (unit >= 0x80) extended = true;
  }
  if (!extended) return value;
  try {
    return utf8.decode(latin1.encode(value));
  } on FormatException {
    return value;
  }
}
