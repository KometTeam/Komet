import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/app_database.dart';

void main() {
  test('chat list state distinguishes previews from memberships', () {
    expect(AppDatabase.chatRowIsInList({'in_list': 0}), isFalse);
    expect(AppDatabase.chatRowIsInList({'in_list': 1}), isTrue);
    expect(AppDatabase.chatRowIsInList({'in_list': 2}), isTrue);
    expect(AppDatabase.chatRowIsInList({}), isTrue);
  });
}
