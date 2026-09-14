import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/video_note_bubble.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/animoji.dart';
import 'package:komet/models/attachment.dart';

const int _me = 1;
const int _peer = 7;

CachedMessage _videoNote({bool reacted = false}) => CachedMessage(
  id: '10',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  time: DateTime(2026, 1, 1, 12, 0).millisecondsSinceEpoch,
  status: 'sent',
  attachments: const [
    VideoAttachment(
      videoId: 5,
      width: 480,
      height: 480,
      duration: 7,
      videoType: 1,
    ),
  ],
  payload: reacted
      ? {
          'reactionInfo': {
            'totalCount': 1,
            'counters': [
              {'reaction': '🔥', 'count': 1},
            ],
          },
        }
      : null,
);

Future<Size> _noteSize(WidgetTester tester, CachedMessage message) async {
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
            reactionAnimojiResolver: (emoji) => Animoji(
              id: 1,
              emoji: emoji,
              iconUrl: 'https://example.com/a.png',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.getSize(find.byType(VideoNoteBubble));
}

void main() {
  testWidgets('a reaction does not shrink the video note', (tester) async {
    final plain = await _noteSize(tester, _videoNote());
    final reacted = await _noteSize(tester, _videoNote(reacted: true));

    expect(tester.takeException(), isNull);
    expect(reacted, plain);
  });
}
