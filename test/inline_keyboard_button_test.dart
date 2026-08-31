import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';

const int _me = 1;
const String _caption = 'Нажмите на один из вариантов ниже';

const Map<String, dynamic> _keyboardAttach = {
  '_type': 'INLINE_KEYBOARD',
  'keyboard': {
    'buttons': [
      [
        {'type': 'CALLBACK', 'text': 'Тренды интерьера', 'payload': 'go'},
      ],
    ],
  },
};

const Map<String, dynamic> _videoAttach = {
  '_type': 'VIDEO',
  'videoId': 501,
  'width': 240,
  'height': 240,
};

CachedMessage _withAttaches(List<Map<String, dynamic>> attaches) =>
    CachedMessage.fromPushPayload(_me, 2, {
      'id': '7007',
      'time': DateTime(2026, 1, 1, 12, 30).millisecondsSinceEpoch,
      'type': 'USER',
      'sender': 2,
      'text': _caption,
      'attaches': attaches,
    });

CachedMessage _withButton(Map<String, dynamic> button) =>
    CachedMessage.fromPushPayload(_me, 2, {
      'id': '7007',
      'time': DateTime(2026, 1, 1, 12, 30).millisecondsSinceEpoch,
      'type': 'USER',
      'sender': 2,
      'text': 'Ваш код',
      'attaches': [
        {
          '_type': 'INLINE_KEYBOARD',
          'keyboard': {
            'buttons': [
              [button],
            ],
          },
        },
      ],
    });

double _captionInset(WidgetTester tester) {
  final caption = find.textContaining(_caption, findRichText: true).first;
  final bubble = find
      .ancestor(of: caption, matching: find.byType(Container))
      .last;
  return tester.getTopLeft(caption).dx - tester.getTopLeft(bubble).dx;
}

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

double _horizontalDrift(WidgetTester tester, String label) {
  final button = tester.getRect(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );
  final text = tester.getRect(find.text(label));
  return text.center.dx - button.center.dx;
}

void main() {
  testWidgets('a clipboard button keeps its label centred', (tester) async {
    await _pump(tester, _withButton({
      'type': 'CLIPBOARD',
      'text': 'Копировать',
      'payload': '123456',
    }));

    expect(find.text('Копировать'), findsOneWidget);
    expect(_horizontalDrift(tester, 'Копировать').abs(), lessThan(0.5));
  });

  testWidgets('a plain callback button keeps its label centred', (
    tester,
  ) async {
    await _pump(tester, _withButton({
      'type': 'CALLBACK',
      'text': 'Продолжить',
      'payload': 'go',
    }));

    expect(_horizontalDrift(tester, 'Продолжить').abs(), lessThan(0.5));
  });

  testWidgets('a keyboard listed first does not strip the text padding', (
    tester,
  ) async {
    await _pump(tester, _withAttaches([_videoAttach, _keyboardAttach]));
    final mediaFirst = _captionInset(tester);

    await _pump(tester, _withAttaches([_keyboardAttach, _videoAttach]));

    expect(mediaFirst, greaterThan(0));
    expect(_captionInset(tester), mediaFirst);
  });
}
