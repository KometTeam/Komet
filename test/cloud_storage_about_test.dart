import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chats.dart';
import 'package:komet/backend/modules/cloud_storage.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/frontend/screens/profile/cloud_storage_screen.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String directory;

  _SyntheticPathProvider(this.directory);

  @override
  Future<String?> getApplicationSupportPath() async => directory;

  @override
  Future<String?> getTemporaryPath() async => directory;
}

CachedChat _group(int id, String title) => CachedChat(
  id: id,
  accountId: 1,
  type: 'CHAT',
  title: title,
  unreadCount: 0,
  lastEventTime: 0,
  cachedAt: 0,
  dontDisturbUntil: 0,
  isOnline: false,
  seenTime: 0,
  participants: const {},
);

void main() {
  test('the group title is the one storage recognizes', () {
    const id = -71234567890;
    final title = CloudStorageModule.titleFor(id);

    expect(title, 'CLST15013');
    expect(CloudStorageModule.isCloudStorageGroup(_group(id, title)), isTrue);
    expect(
      CloudStorageModule.isCloudStorageGroup(_group(id + 1, title)),
      isFalse,
    );
    expect(CloudStorageModule.sampleTitle, startsWith('CLST'));
  });

  group('CloudStorageScreen', () {
    late Directory directory;

    setUp(() async {
      directory = Directory.systemTemp.createTempSync('synthetic_cloud_test');
      PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
      SharedPreferences.setMockInitialValues({});
      await AppDatabase.init();
    });

    tearDown(() async {
      await AppDatabase.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    testWidgets('the info button explains the hidden group', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CloudStorageScreen(),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      expect(find.text('Начать'), findsOneWidget);

      await tester.tap(find.byTooltip('Как работает хранилище'));
      await tester.pumpAndSettle();

      expect(find.text('Это скрытая группа в MAX'), findsOneWidget);
      expect(
        find.text(
          'Группа называется примерно так: '
          '${CloudStorageModule.sampleTitle}',
        ),
        findsOneWidget,
      );
      expect(find.text('В других приложениях группа видна'), findsOneWidget);
    });
  });
}
