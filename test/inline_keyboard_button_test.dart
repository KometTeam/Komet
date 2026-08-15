import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';

const int _me = 1;

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
}
