import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/app_database.dart';

void main() {
  Map<dynamic, dynamic> serverProfile({String? description}) =>
      <dynamic, dynamic>{
        'contact': <dynamic, dynamic>{
          'id': 1001,
          'phone': 70000000000,
          'country': 'RU',
          'accountStatus': 0,
          'updateTime': 1,
          'names': <dynamic>[
            <dynamic, dynamic>{
              'name': 'Имя',
              'firstName': 'Имя',
              'lastName': 'Фамилия',
              'type': 'ONEME',
            },
          ],
          'description': ?description,
        },
        'profileOptions': <dynamic>[2, 4],
      };

  test('description is parsed from the server profile', () {
    final profile = ProfileData.fromServerProfile(
      serverProfile(description: 'пара слов о себе'),
    );
    expect(profile.description, 'пара слов о себе');
  });

  test('missing and empty description both read as null', () {
    expect(ProfileData.fromServerProfile(serverProfile()).description, isNull);
    expect(
      ProfileData.fromServerProfile(serverProfile(description: '')).description,
      isNull,
    );
  });

  test('description survives a database row round-trip', () {
    final profile = ProfileData.fromServerProfile(
      serverProfile(description: 'пара слов о себе'),
    );
    final row = profile.toDbRow(isActive: true);
    expect(row['description'], 'пара слов о себе');

    final restored = ProfileData.fromDbRow(row);
    expect(restored.description, profile.description);
    expect(restored.firstName, 'Имя');
    expect(restored.lastName, 'Фамилия');
  });
}
