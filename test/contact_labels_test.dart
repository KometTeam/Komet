import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/contacts/contact_labels.dart';

void main() {
  group('contactLabels', () {
    test('unknown phone never renders as +0', () {
      final labels = contactLabels(
        idLabel: 'ID 4242',
        firstName: 'Ада',
        lastName: 'Лавлейс',
        phone: 0,
      );

      expect(labels.title, 'Ада Лавлейс');
      expect(labels.subtitle, 'ID 4242');
    });

    test('known phone is formatted', () {
      final labels = contactLabels(
        idLabel: 'ID 4242',
        firstName: 'Ада',
        phone: 79001234567,
      );

      expect(labels.title, 'Ада');
      expect(labels.subtitle, '+7 (900) 123-45-67');
    });

    test('nameless contact falls back to the phone without repeating it', () {
      final labels = contactLabels(idLabel: 'ID 4242', phone: 79001234567);

      expect(labels.title, '+7 (900) 123-45-67');
      expect(labels.subtitle, isNull);
    });

    test('nameless contact without a phone falls back to the id once', () {
      final labels = contactLabels(idLabel: 'ID 4242', phone: 0);

      expect(labels.title, 'ID 4242');
      expect(labels.subtitle, isNull);
    });

    test('sort key ignores the id fallback', () {
      expect(contactSortKey(firstName: 'Ада', phone: 0), 'Ада');
      expect(contactSortKey(phone: 79001234567), '+7 (900) 123-45-67');
      expect(contactSortKey(phone: 0), '');
    });
  });
}
