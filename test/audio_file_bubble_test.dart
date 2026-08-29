import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/utils/media_cache.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _SyntheticPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _SyntheticPathProvider(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationSupportPath() async => directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('скачанный аудиофайл показывает кнопку воспроизведения', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_audio_file_bubble',
    );
    addTearDown(() {
      MediaCache.resetForTesting();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    MediaCache.resetForTesting();

    final file = await MediaCache.fileFor('42_sample.mp3');
    await file.writeAsBytes(List<int>.filled(128, 1));
    await MediaCache.existing('42_sample.mp3');

    final message = CachedMessage(
      id: 'synthetic-message',
      accountId: 1,
      chatId: 2,
      senderId: 7,
      time: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      status: 'sent',
      attachments: const [
        FileAttachment(fileId: 42, name: 'sample.mp3', size: 128),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(
            message: message,
            isMe: false,
            myId: 1,
            chatType: 'DIALOG',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Symbols.audio_file), findsOneWidget);
    expect(find.byIcon(Symbols.play_arrow), findsOneWidget);
    expect(find.byIcon(Symbols.download), findsNothing);
  });

  testWidgets('нескачанный аудиофайл показывает кнопку загрузки', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'synthetic_audio_file_bubble_missing',
    );
    addTearDown(() {
      MediaCache.resetForTesting();
      if (directory.existsSync()) directory.deleteSync(recursive: true);
    });
    PathProviderPlatform.instance = _SyntheticPathProvider(directory.path);
    MediaCache.resetForTesting();

    final message = CachedMessage(
      id: 'synthetic-message',
      accountId: 1,
      chatId: 2,
      senderId: 7,
      time: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      status: 'sent',
      attachments: const [
        FileAttachment(fileId: 43, name: 'missing.mp3', size: 128),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessageBubble(
            message: message,
            isMe: false,
            myId: 1,
            chatType: 'DIALOG',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(Symbols.audio_file), findsOneWidget);
    expect(find.byIcon(Symbols.download), findsOneWidget);
    expect(find.byIcon(Symbols.play_arrow), findsNothing);
  });
}
