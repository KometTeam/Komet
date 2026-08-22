import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/contacts.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String directory;

  _SyntheticPathProvider(this.directory);

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

Map<dynamic, dynamic> _serverContact({
  required int id,
  required String firstName,
  required int phone,
  int accountStatus = 0,
}) {
  return {
    'id': id,
    'phone': phone,
    'updateTime': 1,
    'accountStatus': accountStatus,
    'names': [
      {'type': 'ONEME', 'firstName': firstName, 'lastName': 'Synthetic'},
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const accountId = 1;

  setUp(() async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_contacts_deleted_test',
    );
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    addTearDown(() async {
      await AppDatabase.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    await AppDatabase.init();
    await AppDatabase.saveProfile(
      ProfileData(
        id: accountId,
        firstName: 'Synthetic owner',
        phone: 100000,
        country: 'ZZ',
        accountStatus: 0,
        updateTime: 1,
      ),
    );
    await ContactsModule.syncFromLoginPayload({
      'contacts': [
        _serverContact(id: 11, firstName: 'Alive', phone: 700000011),
        _serverContact(
          id: 12,
          firstName: 'Gone',
          phone: 700000012,
          accountStatus: 2,
        ),
      ],
    }, accountId);
  });

  test('deleted accounts are hidden from the contact list', () async {
    final visible = await ContactsModule.getContacts(accountId);

    expect(visible.map((c) => c.id), [11]);
    expect(visible.single.isDeleted, isFalse);
  });

  test('deleted accounts stay available when explicitly requested', () async {
    final all = await ContactsModule.getContacts(
      accountId,
      includeDeleted: true,
    );

    expect(all.map((c) => c.id).toSet(), {11, 12});
    expect(all.firstWhere((c) => c.id == 12).isDeleted, isTrue);
  });

  test(
    'a re-synced deleted account does not come back into the list',
    () async {
      await ContactsModule.syncFromLoginPayload({
        'contacts': [
          _serverContact(
            id: 12,
            firstName: 'Gone',
            phone: 700000012,
            accountStatus: 2,
          ),
        ],
      }, accountId);

      final visible = await ContactsModule.getContacts(accountId);

      expect(visible.map((c) => c.id), [11]);
    },
  );

  test('a contact without accountStatus is treated as alive', () async {
    await ContactsModule.syncFromLoginPayload({
      'contacts': [
        {
          'id': 13,
          'phone': 700000013,
          'updateTime': 1,
          'names': [
            {'type': 'ONEME', 'firstName': 'Legacy', 'lastName': 'Synthetic'},
          ],
        },
      ],
    }, accountId);

    final visible = await ContactsModule.getContacts(accountId);

    expect(visible.map((c) => c.id).toSet(), {11, 13});
  });
}
