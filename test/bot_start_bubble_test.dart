import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';

const int _me = 1;

CachedMessage _botStart({String? payload}) => CachedMessage.fromPushPayload(
  _me,
  2,
  {
    'id': '5005',
    'time': DateTime(2026, 1, 1, 18, 6).millisecondsSinceEpoch,
    'type': 'USER',
    'sender': _me,
    'text': payload ?? '',
    'attaches': [
      {'_type': 'CONTROL', 'event': 'botStarted'},
    ],
  },
);

Future<void> _pump(WidgetTester tester, CachedMessage message) async {
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
            isMe: true,
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
  testWidgets('a start with a payload shows a service line', (tester) async {
    await _pump(tester, _botStart(payload: 'abc123'));

    expect(find.text('Бот запущен: abc123'), findsOneWidget);
  });

  testWidgets('a start without a payload takes no space', (tester) async {
    await _pump(tester, _botStart());

    expect(find.textContaining('Бот запущен'), findsNothing);
    expect(tester.getSize(find.byType(MessageBubble)), Size.zero);
  });
}
