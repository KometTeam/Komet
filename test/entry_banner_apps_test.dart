import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/account/account_models.dart';
import 'package:komet/backend/modules/webapp.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

Map<String, Object?> _banners(List<Map<String, Object?>> items) => {
  'settings-entry-banners': [
    {'id': 1, 'items': items},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('разбор баннеров', () {
    test('ids берутся по имени иконки', () {
      final resolved = EntryBannerApps.appIdsFrom(
        _banners([
          {
            'icon': 'https://example.test/icons/digital_id_new_40_3x.png',
            'title': 'Цифровой ID',
            'appid': 111,
          },
          {
            'icon': 'https://example.test/icons/sferum_with_padding.png',
            'title': 'Войти в Cферум',
            'appid': 222,
          },
        ]),
      );

      expect(resolved, {
        EntryBannerApps.digitalIdKey: 111,
        EntryBannerApps.sferumKey: 222,
      });
    });

    test('переименованная иконка подстрахована заголовком', () {
      final resolved = EntryBannerApps.appIdsFrom(
        _banners([
          {
            'icon': 'https://example.test/icons/epgu_white.png',
            'title': 'Цифровой ID',
            'appid': 333,
          },
        ]),
      );

      expect(resolved, {EntryBannerApps.digitalIdKey: 333});
    });

    test('иконка важнее заголовка', () {
      final resolved = EntryBannerApps.appIdsFrom(
        _banners([
          {'title': 'Цифровой ID и документы', 'appid': 444},
          {
            'icon': 'https://example.test/icons/digital_id.png',
            'title': 'Документы',
            'appid': 555,
          },
        ]),
      );

      expect(resolved, {EntryBannerApps.digitalIdKey: 555});
    });

    test('мусор в конфиге не ломает разбор', () {
      expect(EntryBannerApps.appIdsFrom(const {}), isEmpty);
      expect(
        EntryBannerApps.appIdsFrom(const {'settings-entry-banners': 'нет'}),
        isEmpty,
      );
      expect(
        EntryBannerApps.appIdsFrom(
          _banners([
            {'icon': 'https://example.test/digital.png', 'appid': '777'},
            {'icon': 'https://example.test/digital.png'},
          ]),
        ),
        isEmpty,
      );
    });

    test('известные id есть для обеих мини-аппок', () {
      expect(
        EntryBannerApps.knownAppIds.keys.toSet(),
        EntryBannerApps.iconMatchers.keys.toSet(),
      );
      expect(EntryBannerApps.knownAppIds.values.every((id) => id > 0), isTrue);
    });
  });

  group('повторный запрос конфига', () {
    const accountId = 1;

    setUp(() async {
      final directory = Directory.systemTemp.createTempSync(
        'synthetic_entry_banner_apps',
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
        isActive: true,
      );
      await AppDatabase.setSyncValue(accountId, SyncKey.lastLogin, '1');
      await AppDatabase.setSyncValue(
        accountId,
        SyncKey.serverConfigSeen,
        LoginSyncParams.serverConfigRevision,
      );
      await AppDatabase.setSyncValue(
        accountId,
        SyncKey.configHash,
        'synthetic-hash',
      );
    });

    test('маркер сбрасывается, конфиг запросится заново', () async {
      var params = await LoginSyncParams.fromDatabase(accountId);
      expect(params!.serverConfigSeen, isTrue);

      await LoginSyncParams.forgetServerConfig(accountId);
      params = await LoginSyncParams.fromDatabase(accountId);

      expect(params!.serverConfigSeen, isFalse);
      expect(params.configHash, 'synthetic-hash');
    });
  });
}
