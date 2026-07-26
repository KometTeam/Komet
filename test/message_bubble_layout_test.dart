import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';

const int _me = 1;
const int _peer = 7;

CachedMessage _message({
  required String text,
  bool withReply = false,
  int senderId = _peer,
}) => CachedMessage(
  id: '1',
  accountId: _me,
  chatId: 2,
  senderId: senderId,
  text: text,
  time: DateTime(2026, 1, 1, 5, 46).millisecondsSinceEpoch,
  status: 'sent',
  payload: withReply
      ? {
          'link': {
            'type': 'REPLY',
            'message': {
              'id': '9',
              'sender': _me,
              'text': 'Алексей Поляков написал очень длинный ответ',
              'time': 0,
              'attaches': [],
            },
          },
        }
      : null,
);

Future<void> _pumpBubble(WidgetTester tester, CachedMessage message) async {
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
            chatType: 'CHAT',
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Rect _rectOf(WidgetTester tester, Finder finder) {
  final size = tester.getSize(finder);
  final topLeft = tester.getTopLeft(finder);
  return topLeft & size;
}

void main() {
  setUp(() => ContactCache.put(_peer, 'Алексей Поляков123'));

  testWidgets('a long sender name pushes the clock to the bubble edge', (
    tester,
  ) async {
    await _pumpBubble(tester, _message(text: 'нет'));

    final header = _rectOf(tester, find.text('Алексей Поляков123'));
    final clock = _rectOf(tester, find.textContaining('05:46'));
    final body = _rectOf(tester, find.text('нет'));

    expect(header.width, greaterThan(body.width + clock.width));
    expect(clock.right, closeTo(header.right, 1));
  });

  testWidgets('the reply quote fills the width the sender name opened up', (
    tester,
  ) async {
    await _pumpBubble(tester, _message(text: 'нет', withReply: true));

    final header = _rectOf(tester, find.text('Алексей Поляков123'));
    final label = _rectOf(tester, find.text('Вы'));
    final quote = _rectOf(
      tester,
      find
          .ancestor(of: find.text('Вы'), matching: find.byType(Container))
          .first,
    );
    final clock = _rectOf(tester, find.textContaining('05:46'));

    expect(quote.right, greaterThan(label.right));
    expect(quote.right, closeTo(header.right, 1));
    expect(clock.right, closeTo(header.right, 1));
  });

  testWidgets('a bubble without a header or reply still hugs its text', (
    tester,
  ) async {
    await _pumpBubble(tester, _message(text: 'нет', senderId: 404));

    final clock = _rectOf(tester, find.textContaining('05:46'));
    final body = _rectOf(tester, find.text('нет'));

    expect(clock.left, closeTo(body.right + 8, 1));
  });
}
