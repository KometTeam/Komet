import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'the active account id is known synchronously once read or set',
    () async {
      SharedPreferences.setMockInitialValues({'active_account_id': '4242'});

      expect(await TokenStorage.getActiveAccountId(), 4242);
      expect(TokenStorage.knownActiveAccountId, 4242);

      await TokenStorage.setActiveAccount(77);
      expect(TokenStorage.knownActiveAccountId, 77);

      await TokenStorage.clearActiveAccount();
      expect(TokenStorage.knownActiveAccountId, isNull);
    },
  );

  test('a read racing a switch does not leave the old id behind', () async {
    SharedPreferences.setMockInitialValues({'active_account_id': '1'});

    final read = TokenStorage.getActiveAccountId();
    final write = TokenStorage.setActiveAccount(2);
    await Future.wait([read, write]);

    expect(TokenStorage.knownActiveAccountId, 2);
  });
}
