import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/message_bubble.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/animoji.dart';
import 'package:komet/models/attachment.dart';

const int _me = 1;
const int _peer = 7;

Map<String, dynamic> get _reactions => {
  'totalCount': 2,
  'counters': [
    {'reaction': '🔥', 'count': 2},
  ],
  'yourReaction': '🔥',
};

CachedMessage _photo({String? caption}) => CachedMessage(
  id: '1',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  text: caption,
  time: DateTime(2026, 1, 1, 12, 0).millisecondsSinceEpoch,
  status: 'sent',
  attachments: [
    PhotoAttachment(
      baseUrl: 'https://example.com/synthetic.jpg',
      width: 180,
      height: 240,
    ),
  ],
  payload: {'reactionInfo': _reactions},
);

CachedMessage _text() => CachedMessage(
  id: '2',
  accountId: _me,
  chatId: 2,
  senderId: _peer,
  text: 'привет',
  time: DateTime(2026, 1, 1, 12, 0).millisecondsSinceEpoch,
  status: 'sent',
  payload: {'reactionInfo': _reactions},
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
          key: const ValueKey('bubble'),
          message: message,
          isMe: false,
          myId: _me,
          chatType: 'DIALOG',
          reactionAnimojiResolver: (emoji) =>
              Animoji(id: 1, emoji: emoji, iconUrl: 'https://example.com/a.png'),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Прямоугольник контейнера-бабла (самый крупный Container внутри пузыря).
Rect _bubbleRect(WidgetTester tester) {
  final containers = find.descendant(
    of: find.byKey(const ValueKey('bubble')),
    matching: find.byType(Container),
  );
  Rect? best;
  for (final element in tester.elementList(containers)) {
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final current = best;
    if (current == null ||
        rect.height * rect.width > current.height * current.width) {
      best = rect;
    }
  }
  return best!;
}

/// Чип реакции ищем по счётчику: сам глиф может быть анимодзи, а не текстом.
Rect _reactionRect(WidgetTester tester) {
  final counter = find.descendant(
    of: find.byKey(const ValueKey('bubble')),
    matching: find.text('2'),
  );
  expect(counter, findsOneWidget);
  final chip = find
      .ancestor(of: counter, matching: find.byType(Container))
      .first;
  return tester.getTopLeft(chip) & tester.getSize(chip);
}

void main() {
  testWidgets('реакция под фото лежит внутри бабла', (tester) async {
    await _pump(tester, _photo());
    final bubble = _bubbleRect(tester);
    final chip = _reactionRect(tester);
    expect(
      bubble.contains(chip.topLeft) && bubble.contains(chip.bottomRight),
      isTrue,
      reason: 'чип реакции должен быть внутри бабла: $chip vs $bubble',
    );
  });

  testWidgets('реакция у фото с подписью тоже внутри бабла', (tester) async {
    await _pump(tester, _photo(caption: 'подпись'));
    final bubble = _bubbleRect(tester);
    final chip = _reactionRect(tester);
    expect(bubble.contains(chip.topLeft), isTrue);
    expect(bubble.contains(chip.bottomRight), isTrue);
  });

  testWidgets('реакция в текстовом сообщении внутри бабла', (tester) async {
    await _pump(tester, _text());
    final bubble = _bubbleRect(tester);
    final chip = _reactionRect(tester);
    expect(bubble.contains(chip.topLeft), isTrue);
    expect(bubble.contains(chip.bottomRight), isTrue);
  });
}
