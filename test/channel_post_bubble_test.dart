import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/frontend/widgets/sending_clock_icon.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';

const int _me = 900401;
const int _otherAdmin = 900402;
const int _channelId = -900501;
const String _channel = 'Синтетический канал';
const double _width = 432;

CachedMessage _post({
  String id = '1',
  int sender = _me,
  String text = 'Первый пост',
  String status = 'sent',
  int minute = 0,
}) => CachedMessage(
  id: id,
  accountId: _me,
  chatId: _channelId,
  senderId: sender,
  text: text,
  time: DateTime(2026, 1, 1, 12, minute).millisecondsSinceEpoch,
  status: status,
);

MessageBubble _channelBubble(
  CachedMessage message, {
  CachedMessage? prev,
  CachedMessage? next,
}) => MessageBubble(
  message: message,
  isMe: message.senderId == _me,
  channelPost: true,
  myId: _me,
  chatType: 'CHANNEL',
  peerName: _channel,
  senderNameOverride: _channel,
  prevMessage: prev,
  nextMessage: next,
);

Future<void> _pump(WidgetTester tester, List<Widget> bubbles) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(_width, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Column(children: bubbles)),
    ),
  );
  await tester.pump();
}

bool _onLeft(WidgetTester tester, String text) =>
    tester.getCenter(find.text(text)).dx < _width / 2;

void main() {
  testWidgets('own channel post sits on the left under the channel name', (
    tester,
  ) async {
    await _pump(tester, [_channelBubble(_post())]);

    expect(_onLeft(tester, 'Первый пост'), isTrue);
    expect(find.text(_channel), findsOneWidget);
    expect(find.byIcon(Symbols.check), findsNothing);
    expect(find.byIcon(Symbols.done_all), findsNothing);
  });

  testWidgets('own channel post still shows that it is being sent or failed', (
    tester,
  ) async {
    await _pump(tester, [
      _channelBubble(_post(status: 'sending')),
      _channelBubble(_post(id: '2', text: 'Второй пост', status: 'error')),
    ]);

    expect(find.byType(SendingClockIcon), findsOneWidget);
    expect(find.byIcon(Symbols.error), findsOneWidget);
  });

  testWidgets('posts of different admins read as one channel', (tester) async {
    final mine = _post();
    final theirs = _post(
      id: '2',
      sender: _otherAdmin,
      text: 'Второй пост',
      minute: 1,
    );
    await _pump(tester, [
      _channelBubble(mine, next: theirs),
      _channelBubble(theirs, prev: mine),
    ]);

    expect(_onLeft(tester, 'Первый пост'), isTrue);
    expect(_onLeft(tester, 'Второй пост'), isTrue);
    expect(find.text(_channel), findsOneWidget);
  });

  testWidgets('own message outside a channel stays on the right', (
    tester,
  ) async {
    await _pump(tester, [
      MessageBubble(
        message: _post(text: 'Обычное сообщение'),
        isMe: true,
        myId: _me,
        chatType: 'DIALOG',
      ),
    ]);

    expect(_onLeft(tester, 'Обычное сообщение'), isFalse);
    expect(find.byIcon(Symbols.check), findsOneWidget);
  });
}
