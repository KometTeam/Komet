import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/account/account_models.dart';

void main() {
  test('uses account id from login response without a phone lookup', () async {
    var lookedUp = false;

    final accountId = await resolveLoginAccountId(
      {
        'profile': {
          'contact': {'id': 42},
        },
      },
      phone: '+7 999 171-65-36',
      lookupByPhone: (_) async {
        lookedUp = true;
        return 99;
      },
    );

    expect(accountId, 42);
    expect(lookedUp, isFalse);
  });

  test('falls back to phone lookup when login response omits account id', () async {
    String? lookedUpPhone;

    final accountId = await resolveLoginAccountId(
      {
        'time': 123,
        'config': <String, Object?>{},
      },
      phone: '+7 999 171-65-36',
      lookupByPhone: (phone) async {
        lookedUpPhone = phone;
        return 77;
      },
    );

    expect(accountId, 77);
    expect(lookedUpPhone, '+7 999 171-65-36');
  });

  test('does not attempt a fallback without a phone hint', () async {
    var lookedUp = false;

    final accountId = await resolveLoginAccountId(
      {'time': 123},
      lookupByPhone: (_) async {
        lookedUp = true;
        return 77;
      },
    );

    expect(accountId, isNull);
    expect(lookedUp, isFalse);
  });
}
