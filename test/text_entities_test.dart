import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/text_entities.dart';

void main() {
  group('detectTextEntities', () {
    test('finds a phone and a card in one message', () {
      final found = detectTextEntities('+70001234567 тест 2200123456789019');

      expect(found, hasLength(2));
      expect(found.first.kind, TextEntityKind.phone);
      expect(found.first.value, '+70001234567');
      expect(found.last.kind, TextEntityKind.card);
      expect(found.last.value, '2200123456789019');
    });

    test('finds a bare russian phone and a spaced card', () {
      final found = detectTextEntities('80001234567 и 2200 1234 5678 9019');
      expect(found.map((e) => e.kind), [
        TextEntityKind.phone,
        TextEntityKind.card,
      ]);
      expect(found.first.value, '+80001234567');
      expect(found.last.value, '2200123456789019');
    });

    test('ignores digits that are not a valid card', () {
      expect(detectTextEntities('111411200327680777'), isEmpty);
      expect(detectTextEntities('2200123456789018'), isEmpty);
      expect(detectTextEntities('1234567890123456'), isEmpty);
    });

    test('ignores timestamps and short numbers', () {
      expect(detectTextEntities('05:46:16 1785041009832'), isEmpty);
    });

    test('finds a nickname but not an email', () {
      final found = detectTextEntities('привет @ExampleBot и mail@ya.ru');
      expect(found, hasLength(1));
      expect(found.single.kind, TextEntityKind.mention);
      expect(found.single.value, 'ExampleBot');
      expect(found.single.start, 7);
      expect(found.single.end, 18);
    });

    test('finds a formatted profile phone', () {
      final found = detectTextEntities('+7 (000) 123-45-67');
      expect(found, hasLength(1));
      expect(found.single.kind, TextEntityKind.phone);
      expect(found.single.value, '+70001234567');
    });

    test('skips ranges that are already claimed', () {
      const text = 'https://max.ru/ExampleBot';
      expect(
        detectTextEntities(text, skip: [(start: 0, end: text.length)]),
        isEmpty,
      );
    });
  });

  group('card metadata', () {
    test('recognises payment systems by BIN', () {
      expect(cardBrand('2200123456789019'), 'MIR');
      expect(cardBrand('4111111111111111'), 'VISA');
      expect(cardBrand('5500000000000004'), 'MASTERCARD');
      expect(cardBrand('340000000000009'), 'AMEX');
      expect(cardBrand('6200000000000005'), 'UNIONPAY');
      expect(cardBrand('1234567890123456'), isNull);
    });

    test('builds the mask shown in the action menu', () {
      expect(cardMask('2200123456789019'), 'MIR*9019');
      expect(cardBrandTitle('2200123456789019'), 'МИР');
    });

    test('formats a card number in groups of four', () {
      expect(formatCardNumber('2200123456789019'), '2200 1234 5678 9019');
    });

    test('luhn rejects a corrupted number', () {
      expect(isLuhnValid('2200123456789019'), isTrue);
      expect(isLuhnValid('2200123456789018'), isFalse);
    });
  });
}
