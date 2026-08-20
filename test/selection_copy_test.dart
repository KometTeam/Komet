import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/screens/chats/chat/view/selection_bar.dart';
import 'package:material_symbols_icons/symbols.dart';

const int _me = 1;
const int _chatId = 2;

CachedMessage _text(String id, String? text) => CachedMessage(
  id: id,
  accountId: _me,
  chatId: _chatId,
  senderId: _me,
  text: text,
  time: DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
);

CachedMessage _forwarded(String id, String originalText) =>
    CachedMessage.fromPushPayload(_me, _chatId, {
      'id': id,
      'time': DateTime(2026, 1, 1, 12).millisecondsSinceEpoch,
      'type': 'USER',
      'sender': _me,
      'link': {
        'type': 'FORWARD',
        'message': {
          'id': '900',
          'time': 1000,
          'type': 'USER',
          'sender': 5,
          'text': originalText,
          'attaches': const [],
        },
        'chatId': -30,
        'chatName': 'Synthetic Channel',
      },
    });

Future<List<CachedMessage>?> _tapCopy(
  WidgetTester tester,
  List<CachedMessage> copyMsgs, {
  required bool glossy,
}) async {
  List<CachedMessage>? copied;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SelectionTopBar(
          cs: ThemeData.light().colorScheme,
          selected: copyMsgs.map((m) => m.id).toSet(),
          glossy: glossy,
          copyMsgs: copyMsgs,
          editMsg: null,
          onClear: () {},
          onCopy: (msgs) => copied = msgs,
          onEdit: (_) {},
          onDelete: () {},
        ),
      ),
    ),
  );
  final copyButton = find.widgetWithIcon(IconButton, Symbols.content_copy);
  if (copyButton.evaluate().isEmpty) return null;
  await tester.tap(copyButton);
  await tester.pump();
  return copied;
}

void main() {
  testWidgets('copy stays available for several selected messages', (
    tester,
  ) async {
    final msgs = [_text('1', 'первое'), _text('2', 'второе')];
    for (final glossy in [false, true]) {
      expect(await _tapCopy(tester, msgs, glossy: glossy), msgs);
    }
  });

  testWidgets('copy is hidden when nothing carries text', (tester) async {
    expect(await _tapCopy(tester, const [], glossy: false), isNull);
  });

  testWidgets('a forwarded message exposes its original text', (tester) async {
    final forwarded = _forwarded('3', 'исходный текст');
    expect(forwarded.text, isNull);
    expect(forwarded.selectableText, 'исходный текст');
    expect(await _tapCopy(tester, [forwarded], glossy: false), [forwarded]);
  });
}
