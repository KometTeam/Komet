import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/komet_settings.dart';
import 'package:komet/frontend/widgets/attachment/bubbles/meta_marks.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';

const int _me = 1;
const int _peer = 2;
const String _hint = 'Сообщения скорее всего пересланы';

const int _window = MessageBubble.forwardBurstWindowMs;

final int _instant = DateTime(2026, 1, 1, 12, 30).millisecondsSinceEpoch;

CachedMessage _message(String id, {int? time, int sender = _peer}) =>
    CachedMessage.fromPushPayload(_me, _peer, {
      'id': id,
      'time': time ?? _instant,
      'type': 'USER',
      'sender': sender,
      'text': 'Сообщение $id',
    });

Future<void> _pump(WidgetTester tester, List<CachedMessage> messages) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < messages.length; i++)
              MessageBubble(
                message: messages[i],
                isMe: messages[i].senderId == _me,
                myId: _me,
                prevMessage: i > 0 ? messages[i - 1] : null,
                nextMessage: i < messages.length - 1 ? messages[i + 1] : null,
                chatType: 'DIALOG',
              ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _marks => find.descendant(
  of: find.byType(LikelyForwardedMark),
  matching: find.byType(Icon),
);

void main() {
  setUp(() => KometSettings.showForward.value = true);
  tearDown(() => KometSettings.showForward.value = false);

  testWidgets('метка стоит на каждом сообщении, ушедшем одной пачкой', (
    tester,
  ) async {
    await _pump(tester, [
      _message('101', time: _instant - 60000),
      _message('102'),
      _message('103', time: _instant + 144),
      _message('104', time: _instant + 144 + _window),
      _message('105', time: _instant + 144 + _window * 2 + 1),
    ]);

    expect(_marks, findsNWidgets(3));
  });

  testWidgets('сообщение вне окна пачки остаётся без метки', (tester) async {
    await _pump(tester, [
      _message('101', time: _instant - _window - 1),
      _message('102'),
      _message('103', time: _instant + _window + 1),
    ]);

    expect(_marks, findsNothing);
  });

  testWidgets('близкие по времени сообщения разных авторов не помечаются', (
    tester,
  ) async {
    await _pump(tester, [_message('101'), _message('102', sender: _me)]);

    expect(_marks, findsNothing);
  });

  testWidgets('метка слева от времени и по тапу объясняет себя', (
    tester,
  ) async {
    await _pump(tester, [_message('101'), _message('102')]);

    final mark = tester.getRect(_marks.first);
    final clock = tester.getRect(find.text('12:30').first);
    expect(mark.right, lessThanOrEqualTo(clock.left));

    await tester.tap(_marks.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(_hint), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('настройка включает и выключает метку на лету', (tester) async {
    KometSettings.showForward.value = false;
    await _pump(tester, [_message('101'), _message('102')]);
    expect(_marks, findsNothing);

    KometSettings.showForward.value = true;
    await tester.pump();
    expect(_marks, findsNWidgets(2));

    KometSettings.showForward.value = false;
    await tester.pump();
    expect(_marks, findsNothing);
  });
}
