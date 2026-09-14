import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/app_database.dart';

Map<String, dynamic> _contact(String first, String last, int phone) => {
  'first_name': first,
  'last_name': last,
  'phone': phone,
};

void main() {
  final masha = _contact('Маша', 'Иванова', 79990000001);

  test('lower-case cyrillic query finds a capitalised name', () {
    expect(AppDatabase.contactMatches(masha, 'маша'), isTrue);
  });

  test('full name matches in both orders', () {
    expect(AppDatabase.contactMatches(masha, 'маша иванова'), isTrue);
    expect(AppDatabase.contactMatches(masha, 'иванова маша'), isTrue);
  });

  test('phone digits still match', () {
    expect(AppDatabase.contactMatches(masha, '9990000001'), isTrue);
  });

  test('unrelated query does not match', () {
    expect(AppDatabase.contactMatches(masha, 'пётр'), isFalse);
  });
}
