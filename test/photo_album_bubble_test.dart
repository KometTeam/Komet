import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/frontend/widgets/photo_viewer.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';

CachedMessage _album(List<PhotoAttachment> photos) => CachedMessage(
  id: '1',
  accountId: 1,
  chatId: 2,
  senderId: 1,
  time: DateTime(2026, 1, 1).millisecondsSinceEpoch,
  status: 'sent',
  attachments: photos,
);

List<PhotoAttachment> _remote(int count) => List.generate(
  count,
  (i) => PhotoAttachment(
    baseUrl: 'https://example.com/$i.jpg',
    width: 1200,
    height: 1600,
  ),
);

List<PhotoAttachment> _local(int count) => List.generate(
  count,
  (i) => PhotoAttachment(localPath: '/tmp/photo$i.jpg', width: 1200, height: 1600),
);

Future<void> _pumpBubble(
  WidgetTester tester,
  CachedMessage message, {
  bool withInsets = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  tester.view.padding = withInsets
      ? const FakeViewPadding(top: 210, bottom: 120)
      : FakeViewPadding.zero;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: MessageBubble(
            message: message,
            isMe: true,
            myId: 1,
            chatType: 'DIALOG',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

int _viewerIndex(WidgetTester tester) =>
    tester.widget<PhotoViewerScreen>(find.byType(PhotoViewerScreen)).initialIndex;

Size _bubbleSize(WidgetTester tester) => tester.getSize(
  find
      .ancestor(
        of: find.byType(ClipRRect).first,
        matching: find.byType(ConstrainedBox),
      )
      .first,
);

void main() {
  testWidgets('album grid ignores safe area insets', (tester) async {
    await _pumpBubble(tester, _album(_remote(4)), withInsets: false);
    final plain = _bubbleSize(tester);

    await _pumpBubble(tester, _album(_remote(4)));
    final inset = _bubbleSize(tester);

    expect(inset.width, closeTo(plain.width, 1));
    expect(inset.height, closeTo(plain.height, 1));
  });

  testWidgets('tapping an album photo opens the viewer at its index', (
    tester,
  ) async {
    await _pumpBubble(tester, _album(_remote(4)));

    await tester.tap(find.byType(GestureDetector).at(2));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(_viewerIndex(tester), 2);
  });

  testWidgets('an album of six shows every photo', (tester) async {
    await _pumpBubble(tester, _album(_remote(6)));

    expect(find.textContaining('+'), findsNothing);

    await tester.tap(find.byType(GestureDetector).at(5));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(_viewerIndex(tester), 5);
  });

  testWidgets('the +N tile appears past ten photos and opens the viewer', (
    tester,
  ) async {
    await _pumpBubble(tester, _album(_remote(12)));

    expect(find.text('+2'), findsOneWidget);

    await tester.tap(find.text('+2'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(_viewerIndex(tester), 9);
  });

  testWidgets('photos still uploading open from their local file', (
    tester,
  ) async {
    await _pumpBubble(tester, _album(_local(4)));

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PhotoViewerScreen), findsOneWidget);
  });
}
