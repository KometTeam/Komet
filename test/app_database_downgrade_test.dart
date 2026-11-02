import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

const _accountId = 101;

void main() {
  late Directory directory;
  late PathProviderPlatform previousProvider;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('synthetic_downgrade');
    previousProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    await AppDatabase.init();
  });

  tearDown(() async {
    await AppDatabase.close();
    PathProviderPlatform.instance = previousProvider;
    await directory.delete(recursive: true);
  });

  test(
    'база открывается после того, как старая сборка опустила версию',
    () async {
      await AppDatabase.saveProfile(ProfileData.stub(_accountId));
      await AppDatabase.close();

      final raw = await databaseFactory.openDatabase(
        '${directory.path}${Platform.pathSeparator}komet.db',
      );
      await raw.setVersion(27);
      await raw.close();

      expect(await AppDatabase.loadContacts(_accountId), isEmpty);
      expect((await AppDatabase.loadProfile(_accountId))?.id, _accountId);
    },
  );
}
