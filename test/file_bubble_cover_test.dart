import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';

const int _me = 1;
const int _peer = 7;

CachedMessage _fileMessage(String name) => CachedMessage(
  id: '1',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  time: DateTime(2026, 1, 1, 5, 46).millisecondsSinceEpoch,
  status: 'sent',
  attachments: [
    FileAttachment(
      fileId: 42,
      name: name,
      size: 580100,
      preview: const PhotoAttachment(
        baseUrl: 'https://example.invalid/synthetic-cover',
        width: 320,
        height: 240,
      ),
    ),
  ],
);

Future<void> _pump(WidgetTester tester, CachedMessage message) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: MessageBubble(
            message: message,
            isMe: false,
            myId: _me,
            chatType: 'DIALOG',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('видеофайлу обложка не выделяет место', (tester) async {
    await _pump(tester, _fileMessage('2026-05-14 12-27-50.mp4'));

    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('архиву обложка тоже не положена', (tester) async {
    await _pump(tester, _fileMessage('backup.zip'));

    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('картинке-файлу обложка остаётся', (tester) async {
    await _pump(tester, _fileMessage('scan.jpg'));

    expect(find.byType(CachedNetworkImage), findsOneWidget);
  });

  testWidgets('файл без расширения обходится без обложки', (tester) async {
    await _pump(tester, _fileMessage('dump'));

    expect(find.byType(CachedNetworkImage), findsNothing);
  });
}
