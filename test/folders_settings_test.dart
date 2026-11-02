import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/models/chat_folder.dart';
import 'package:komet/backend/modules/folders.dart';
import 'package:komet/core/storage/app_database.dart';
import 'package:komet/frontend/screens/profile/folders_settings_section.dart';
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

const _accountId = 1;

ChatFolder _folder(List<int> filters) => ChatFolder(
  id: 'synthetic-${filters.join('-')}',
  title: 'x',
  filters: filters,
);

Future<void> _seed({required bool channelsSuggested}) async {
  await AppDatabase.saveProfile(
    ProfileData(
      id: _accountId,
      firstName: 'Synthetic owner',
      phone: 100000,
      country: 'ZZ',
      accountStatus: 0,
      updateTime: 1,
    ),
  );
  await FoldersModule.applyPayload(_accountId, {
    'folders': [
      {
        'id': FoldersModule.allChatsFolderId,
        'title': 'Все',
        'options': [1],
      },
      {
        'id': 'synthetic-work',
        'title': 'Синтетическая работа',
        'filters': [FolderFilter.chat],
      },
      {
        'id': 'synthetic-unread',
        'title': 'Непрочитанное',
        'filters': [FolderFilter.unread],
      },
    ],
    'foldersOrder': [
      FoldersModule.allChatsFolderId,
      'synthetic-work',
      'synthetic-unread',
    ],
  }, replace: true);
  await AppDatabase.setSyncValue(
    _accountId,
    SyncKey.channelsFolderSuggested,
    channelsSuggested ? '1' : '0',
  );
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(children: const [FoldersSettingsSection()]),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pump();
}

void main() {
  group('recommended folder presets', () {
    test('«Новые» is a folder of unread chats', () {
      final unread = _folder([FolderFilter.unread]);
      final narrowed = _folder([FolderFilter.unread, FolderFilter.channel]);

      expect(FoldersModule.isUnreadFolder(unread, filtersEnabled: false), true);
      expect(
        FoldersModule.isUnreadFolder(narrowed, filtersEnabled: false),
        false,
      );
      expect(
        FoldersModule.isUnreadFolder(narrowed, filtersEnabled: true),
        true,
      );
    });

    test('«Личные» needs both contacts and non-contacts', () {
      final personal = _folder([FolderFilter.contact, FolderFilter.notContact]);
      final contactsOnly = _folder([FolderFilter.contact]);
      final narrowed = _folder([
        FolderFilter.contact,
        FolderFilter.notContact,
        FolderFilter.notMuted,
      ]);

      expect(
        FoldersModule.isPersonalFolder(personal, filtersEnabled: false),
        true,
      );
      expect(
        FoldersModule.isPersonalFolder(contactsOnly, filtersEnabled: true),
        false,
      );
      expect(
        FoldersModule.isPersonalFolder(narrowed, filtersEnabled: false),
        false,
      );
      expect(
        FoldersModule.isPersonalFolder(narrowed, filtersEnabled: true),
        true,
      );
    });

    test('«Каналы» holds nothing but channels', () {
      expect(
        FoldersModule.isChannelsFolder(_folder([FolderFilter.channel])),
        true,
      );
      expect(
        FoldersModule.isChannelsFolder(
          _folder([FolderFilter.channel, FolderFilter.unread]),
        ),
        false,
      );
    });
  });

  group('spliceOrder', () {
    test('moves user folders and keeps the rest in place', () {
      expect(
        FoldersModule.spliceOrder(
          ['all', 'a', 'hidden', 'b', 'c'],
          ['c', 'a', 'b'],
        ),
        ['all', 'c', 'hidden', 'a', 'b'],
      );
    });

    test('appends folders the stored order does not know yet', () {
      expect(FoldersModule.spliceOrder(['all', 'a'], ['new', 'a']), [
        'all',
        'new',
        'a',
      ]);
    });

    test('drops duplicates of the stored order', () {
      expect(FoldersModule.spliceOrder(['all', 'a', 'a', 'b'], ['b', 'a']), [
        'all',
        'b',
        'a',
      ]);
    });
  });

  group('FoldersSettingsSection', () {
    late Directory directory;

    setUp(() async {
      directory = Directory.systemTemp.createTempSync('synthetic_folders_test');
      PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
      SharedPreferences.setMockInitialValues({
        'active_account_id': '$_accountId',
      });
      await AppDatabase.init();
    });

    tearDown(() async {
      await AppDatabase.close();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });

    testWidgets('lists folders and recommends the missing presets', (
      tester,
    ) async {
      await tester.runAsync(() => _seed(channelsSuggested: true));
      await _pumpScreen(tester);

      expect(find.text('Все'), findsOneWidget);
      expect(find.text('Синтетическая работа'), findsOneWidget);
      expect(find.text('Непрочитанное'), findsOneWidget);
      expect(find.text('Создать папку'), findsOneWidget);
      expect(find.text('РЕКОМЕНДОВАННЫЕ ПАПКИ'), findsOneWidget);
      expect(find.text('Новые'), findsNothing);
      expect(find.text('Личные'), findsOneWidget);
      expect(find.text('Каналы'), findsOneWidget);
    });

    testWidgets('channels are recommended only when the server asks', (
      tester,
    ) async {
      await tester.runAsync(() => _seed(channelsSuggested: false));
      await _pumpScreen(tester);

      expect(find.text('Личные'), findsOneWidget);
      expect(find.text('Каналы'), findsNothing);
    });

    testWidgets('a deletable folder offers delete in its menu', (tester) async {
      await tester.runAsync(() => _seed(channelsSuggested: false));
      await _pumpScreen(tester);

      final menus = find.byTooltip('Показать меню');
      expect(menus, findsNWidgets(2));
      await tester.tap(menus.first);
      await tester.pumpAndSettle();

      expect(find.text('Удалить'), findsOneWidget);
    });
  });
}
