import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/animoji.dart';
import 'package:komet/models/attachment.dart';

const int _me = 1;
const int _peer = 7;
const String _clock = '12:00';

Map<String, dynamic> get _reactions => {
  'totalCount': 2,
  'counters': [
    {'reaction': '🔥', 'count': 1},
    {'reaction': '🤔', 'count': 1},
  ],
};

CachedMessage _message(
  List<MessageAttachment> attachments, {
  bool reacted = true,
}) => CachedMessage(
  id: 'synthetic-message',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  time: DateTime(2026, 1, 1, 12, 0).millisecondsSinceEpoch,
  status: 'sent',
  attachments: attachments,
  payload: {if (reacted) 'reactionInfo': _reactions},
);

const _voice = AudioAttachment(
  audioId: 11,
  duration: 57000,
  fileUrl: 'https://example.test/voice.ogg',
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
        body: MessageBubble(
          message: message,
          isMe: false,
          myId: _me,
          chatType: 'DIALOG',
          reactionAnimojiResolver: (emoji) => Animoji(
            id: 1,
            emoji: emoji,
            iconUrl: 'https://example.test/a.png',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _textContaining(String part) => find.byWidgetPredicate(
  (widget) => widget is Text && (widget.data ?? '').contains(part),
);

void main() {
  testWidgets('a voice message with reactions shows its time once', (
    tester,
  ) async {
    await _pump(tester, _message(const [_voice]));

    expect(find.text(_clock), findsOneWidget);
  });

  testWidgets('a voice message without reactions keeps its own time', (
    tester,
  ) async {
    await _pump(tester, _message(const [_voice], reacted: false));

    expect(find.text(_clock), findsOneWidget);
  });

  testWidgets('a call with reactions shows its time once', (tester) async {
    await _pump(
      tester,
      _message(const [CallAttachment(isVideo: false, durationMs: 83000)]),
    );

    expect(_textContaining(_clock), findsOneWidget);
    expect(find.text('1:23'), findsOneWidget);
  });

  testWidgets('a missed call with reactions shows its time once', (
    tester,
  ) async {
    await _pump(tester, _message(const [CallAttachment(isVideo: false)]));

    expect(_textContaining(_clock), findsOneWidget);
  });

  testWidgets('a call without reactions keeps time and duration together', (
    tester,
  ) async {
    await _pump(
      tester,
      _message(const [
        CallAttachment(isVideo: false, durationMs: 83000),
      ], reacted: false),
    );

    expect(find.text('$_clock · 1:23'), findsOneWidget);
  });
}
