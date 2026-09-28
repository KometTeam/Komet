import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/ios_bubble_metrics.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/photo_bubble.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/album_layout.dart';

PhotoAttachment _photo(int width, int height, [String name = 'photo']) =>
    PhotoAttachment(
      baseUrl: 'https://example.com/synthetic-$name.jpg',
      width: width,
      height: height,
    );

CachedMessage _message(List<MessageAttachment> attachments) => CachedMessage(
  id: '1',
  accountId: 1,
  chatId: 2,
  senderId: 7,
  time: DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
  status: 'sent',
  attachments: attachments,
);

Future<void> _pump(
  WidgetTester tester,
  List<MessageAttachment> attachments,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: MessageBubble(
            message: _message(attachments),
            isMe: false,
            myId: 1,
            chatType: 'DIALOG',
            listWidth: 390,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Size _photoSize(WidgetTester tester) => tester.getSize(
  find
      .descendant(
        of: find.byType(PhotoBubble),
        matching: find.byType(ClipRRect),
      )
      .first,
);

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  test('single media fits 300×380 and is never smaller than 170×74', () {
    expect(
      IosBubbleMetrics.mediaSize(1600, 1200, maxWidth: 300),
      const Size(300, 225),
    );
    expect(
      IosBubbleMetrics.mediaSize(1000, 4000, maxWidth: 300),
      const Size(170, 380),
    );
    expect(
      IosBubbleMetrics.mediaSize(4000, 400, maxWidth: 300),
      const Size(300, 74),
    );
  });

  testWidgets('iOS: a photo sits inside the bubble with a 2 pt inset', (
    tester,
  ) async {
    await _pump(tester, [_photo(1600, 1200)]);
    expect(_photoSize(tester), const Size(300, 225));
    final bubble = tester.getSize(find.byType(PhotoBubble));
    expect(bubble.width, 300 + IosBubbleMetrics.mediaInset * 2);
  }, variant: ios);

  testWidgets('Android keeps the 280 pt photo box', (tester) async {
    await _pump(tester, [_photo(1600, 1200)]);
    expect(_photoSize(tester).width, 280);
  }, variant: android);

  testWidgets('iOS: an album is at most 300 wide and 380 tall', (tester) async {
    await _pump(tester, [
      _photo(600, 1200, 'a'),
      _photo(600, 1200, 'b'),
      _photo(600, 1200, 'c'),
    ]);
    final size = _photoSize(tester);
    expect(size.width, lessThanOrEqualTo(300));
    expect(size.height, lessThanOrEqualTo(IosBubbleMetrics.mediaMaxHeight));
  }, variant: ios);

  test('a stronger order penalty keeps short rows first', () {
    final cropped = [1.0, 1.0, 1.0, 1.0, 1.0];
    expect(AlbumLayout.rows(cropped), isNotEmpty);
    expect(
      AlbumLayout.rows(
        cropped,
        orderPenalty: IosBubbleMetrics.albumOrderPenalty,
      ).fold<int>(0, (a, b) => a + b),
      5,
    );
  });
}
