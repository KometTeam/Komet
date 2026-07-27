import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/download_history.dart';
import 'package:komet/core/utils/media_cache.dart';
import 'package:komet/frontend/screens/downloads_screen.dart';
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('download kinds are inferred from synthetic file names', () {
    expect(downloadKindForName('sample.gif'), DownloadKind.gif);
    expect(downloadKindForName('clip.mp4'), DownloadKind.video);
    expect(downloadKindForName('sound.ogg'), DownloadKind.audio);
    expect(downloadKindForName('picture.png'), DownloadKind.photo);
    expect(downloadKindForName('package.zip'), DownloadKind.file);
  });

  testWidgets('recent downloads show persisted metadata', (tester) async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_downloads_test',
    );
    addTearDown(() {
      DownloadHistory.resetForTesting();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    SharedPreferences.setMockInitialValues({});

    await tester.runAsync(() async {
      DownloadHistory.resetForTesting();
      final file = await MediaCache.fileFor('synthetic-package.zip');
      await file.writeAsBytes(List<int>.filled(2048, 1));
      await DownloadHistory.record(
        const DownloadMetadata(
          cacheName: 'synthetic-package.zip',
          name: 'sample-package.zip',
          kind: DownloadKind.file,
          sourceName: 'Synthetic channel',
          chatId: 77,
          messageId: 'synthetic-message',
          messageTime: 123456,
        ),
        file,
      );
      DownloadHistory.resetForTesting();
      await DownloadHistory.load();
    });

    final record = DownloadHistory.records.value.single;
    expect(record.chatId, 77);
    expect(record.messageId, 'synthetic-message');
    expect(record.messageTime, 123456);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DownloadsScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Недавние загрузки'), findsOneWidget);
    expect(find.text('sample-package.zip'), findsOneWidget);
    expect(find.text('2.0 КБ · Synthetic channel'), findsOneWidget);
    expect(find.byKey(const ValueKey('downloads-settings')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('download-more-synthetic-package.zip')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Перейти к сообщению'), findsOneWidget);
    expect(find.text('Сохранить как…'), findsOneWidget);
  });
}
