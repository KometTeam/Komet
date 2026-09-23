import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/share_bubble.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/main.dart' show animojiModule;
import 'package:komet/models/attachment.dart';

const _reactions = ['👍', '❤️', '🔥', '🍑', '💩', '🤡', '💘', '👻'];

CachedMessage _post({
  required String text,
  List<MessageAttachment>? attaches,
  int reactions = 8,
}) => CachedMessage(
  id: '1',
  accountId: 1,
  chatId: 2,
  senderId: 3,
  text: text,
  time: DateTime(2026, 1, 1).millisecondsSinceEpoch,
  status: 'sent',
  attachments: attaches,
  payload: {
    'text': text,
    'reactionInfo': {
      'counters': [
        for (var i = 0; i < reactions; i++)
          {'reaction': _reactions[i], 'count': 40 - i * 4},
      ],
      'totalCount': 200,
    },
  },
);

Future<void> _pump(
  WidgetTester tester,
  CachedMessage message, {
  double width = 1920,
}) async {
  tester.view.physicalSize = Size(width, 1080);
  tester.view.devicePixelRatio = 1;
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
            myId: 1,
            chatType: 'CHANNEL',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

double _reactionsWidth(WidgetTester tester) => tester
    .getSize(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_ReactionsFlow',
      ),
    )
    .width;

void main() {
  setUpAll(() => expect(animojiModule, isNotNull));

  testWidgets('many reactions do not widen a link preview bubble', (
    tester,
  ) async {
    await _pump(
      tester,
      _post(
        text: 'Synthetic site https://example.com',
        attaches: const [
          ShareAttachment(
            title: 'Synthetic title',
            description: 'Synthetic description',
            url: 'https://example.com',
            host: 'example.com',
          ),
        ],
      ),
    );

    final preview = tester.getSize(find.byType(ShareBubble)).width;
    expect(_reactionsWidth(tester), lessThanOrEqualTo(preview));
  });

  testWidgets('plain text still grows to fit its reactions on one line', (
    tester,
  ) async {
    await _pump(tester, _post(text: 'Hi'));

    final first = tester.getTopLeft(find.text('40')).dy;
    final last = tester.getTopLeft(find.text('12')).dy;
    expect(last, closeTo(first, 1));
  });

  testWidgets('reactions use the whole line and the time takes what is left', (
    tester,
  ) async {
    for (final width in [440.0, 520.0, 600.0, 700.0, 900.0]) {
      await _pump(tester, _post(text: 'Hi', reactions: 7), width: width);
      final flow = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_ReactionsFlow',
      );
      final box = tester.getRect(flow);
      final chips = [
        for (var i = 0; i < 7; i++) tester.getRect(find.text('${40 - i * 4}')),
      ];
      final time = tester.getRect(find.text('00:00'));

      for (var i = 1; i < chips.length; i++) {
        final sameLine = (chips[i].top - chips[i - 1].top).abs() < 1;
        if (!sameLine) {
          final lineEnd = chips[i - 1].right;
          expect(
            lineEnd + 60 > box.right,
            isTrue,
            reason: 'chip $i wrapped early at width $width',
          );
        }
      }
      final last = chips.last;
      final timeOnLastLine = time.bottom <= last.bottom + 6;
      if (!timeOnLastLine) {
        expect(
          last.right + 8 + time.width > box.right - 4,
          isTrue,
          reason: 'time left the last line at width $width',
        );
      }
      expect(time.right, closeTo(box.right, 12));
    }
  });

  testWidgets('a sticker with reactions shows its time once', (tester) async {
    await _pump(
      tester,
      _post(
        text: '',
        reactions: 4,
        attaches: const [StickerAttachment(stickerId: '1')],
      ),
      width: 420,
    );

    expect(find.text('00:00'), findsOneWidget);
    final first = tester.getTopLeft(find.text('40')).dy;
    final second = tester.getTopLeft(find.text('36')).dy;
    expect(second, closeTo(first, 1));
  });
}
