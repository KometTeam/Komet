// #***! что подсвечиваем в тексте
enum TextEntityKind { mention, phone, card }

class TextEntity {
  final TextEntityKind kind;
  final int start;
  final int end;
  final String value;

  const TextEntity({
    required this.kind,
    required this.start,
    required this.end,
    required this.value,
  });

  int get length => end - start;
}

typedef TextSpanRange = ({int start, int end});

// #***! регулярки терпят пробелы и дефисы но не цепляют обычные числа
final RegExp _cardPattern = RegExp(
  r'(?<![\d.,])\d(?:[ -]?\d){12,18}(?![\d.,])',
);
final RegExp _phonePattern = RegExp(
  r'(?<![\d.,])(?:\+\d(?:[ ()-]{0,3}\d){9,14}|[78](?:[ ()-]{0,3}\d){10})(?![\d.,])',
);
final RegExp _mentionPattern = RegExp(r'(?<![\w@/])@([A-Za-z0-9_]{2,32})');

// #***! человеческие названия платёжных систем
const Map<String, String> _cardBrands = {
  'MIR': 'МИР',
  'VISA': 'Visa',
  'MASTERCARD': 'Mastercard',
  'MAESTRO': 'Maestro',
  'AMEX': 'American Express',
  'UNIONPAY': 'UnionPay',
  'JCB': 'JCB',
  'DINERS': 'Diners Club',
  'DISCOVER': 'Discover',
};

// #***! платёжка по первым цифрам
String? cardBrand(String digits) {
  if (digits.length < 13) return null;
  int prefix(int length) => int.parse(digits.substring(0, length));

  final p1 = prefix(1);
  final p2 = prefix(2);
  final p3 = prefix(3);
  final p4 = prefix(4);
  final p6 = digits.length >= 6 ? prefix(6) : 0;

  if (p4 >= 2200 && p4 <= 2204) return 'MIR';
  if (p1 == 4) return 'VISA';
  if (p2 >= 51 && p2 <= 55) return 'MASTERCARD';
  if (p4 >= 2221 && p4 <= 2720) return 'MASTERCARD';
  if (p2 == 34 || p2 == 37) return 'AMEX';
  if (p2 == 62) return 'UNIONPAY';
  if (p4 >= 3528 && p4 <= 3589) return 'JCB';
  if (p3 >= 300 && p3 <= 305) return 'DINERS';
  if (p2 == 36 || p2 == 38 || p2 == 39) return 'DINERS';
  if (p4 == 6011 || p2 == 65) return 'DISCOVER';
  if (p3 >= 644 && p3 <= 649) return 'DISCOVER';
  if (p6 >= 622126 && p6 <= 622925) return 'DISCOVER';
  if (p4 == 5018 || p4 == 5020 || p4 == 5038 || p4 == 6304) return 'MAESTRO';
  if (p4 == 6759 || (p4 >= 6761 && p4 <= 6763)) return 'MAESTRO';
  return null;
}

String? cardBrandTitle(String digits) {
  final brand = cardBrand(digits);
  return brand == null ? null : _cardBrands[brand];
}

// #***! показываем маскированный номер а не полный
String cardMask(String digits) {
  final brand = cardBrand(digits) ?? 'CARD';
  final tail = digits.length >= 4
      ? digits.substring(digits.length - 4)
      : digits;
  return '$brand*$tail';
}

String formatCardNumber(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

// #***! алгоритм луна отсекает случайные длинные числа
bool isLuhnValid(String digits) {
  if (digits.length < 12) return false;
  var sum = 0;
  var double = false;
  for (var i = digits.length - 1; i >= 0; i--) {
    var value = digits.codeUnitAt(i) - 0x30;
    if (value < 0 || value > 9) return false;
    if (double) {
      value *= 2;
      if (value > 9) value -= 9;
    }
    sum += value;
    double = !double;
  }
  return sum % 10 == 0;
}

String _digitsOf(String raw) {
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final code = raw.codeUnitAt(i);
    if (code >= 0x30 && code <= 0x39) buffer.writeCharCode(code);
  }
  return buffer.toString();
}

// #***! быстрый отсев, зовётся на каждое сообщение
bool _mayContainEntities(String text) {
  for (var i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    if (code == 0x40) return true;
    if (code >= 0x30 && code <= 0x39) return true;
  }
  return false;
}

// #***! поиск сущностей, skip это уже занятые куски
List<TextEntity> detectTextEntities(
  String text, {
  Iterable<TextSpanRange> skip = const [],
}) {
  if (text.isEmpty || !_mayContainEntities(text)) return const [];

  final taken = <TextSpanRange>[...skip];
  bool free(int start, int end) =>
      !taken.any((r) => start < r.end && end > r.start);

  final found = <TextEntity>[];

  // #***! занимаем диапазоны чтоб сущности не накладывались
  void collect(
    RegExp pattern,
    TextEntityKind kind,
    String? Function(RegExpMatch match) valueOf,
  ) {
    for (final match in pattern.allMatches(text)) {
      if (!free(match.start, match.end)) continue;
      final value = valueOf(match);
      if (value == null) continue;
      taken.add((start: match.start, end: match.end));
      found.add(
        TextEntity(
          kind: kind,
          start: match.start,
          end: match.end,
          value: value,
        ),
      );
    }
  }

  // #***! карту берём только если сходится бренд и контрольная сумма
  collect(_cardPattern, TextEntityKind.card, (match) {
    final digits = _digitsOf(match.group(0)!);
    if (digits.length < 13 || digits.length > 19) return null;
    if (cardBrand(digits) == null) return null;
    if (!isLuhnValid(digits)) return null;
    return digits;
  });

  collect(_phonePattern, TextEntityKind.phone, (match) {
    final digits = _digitsOf(match.group(0)!);
    if (digits.length < 10 || digits.length > 15) return null;
    return '+$digits';
  });

  collect(_mentionPattern, TextEntityKind.mention, (match) => match.group(1));

  found.sort((a, b) => a.start.compareTo(b.start));
  return found;
}

bool hasTextEntities(String text, {Iterable<TextSpanRange> skip = const []}) =>
    detectTextEntities(text, skip: skip).isNotEmpty;
