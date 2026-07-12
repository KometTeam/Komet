import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:komet/frontend/widgets/rich_message_controller.dart';
import 'package:komet/models/animoji.dart';

Animoji _a(int id, String emoji, String lottie) =>
    Animoji(id: id, emoji: emoji, lottieUrl: lottie);

void main() {
  test('standalone animoji builds one ANIMOJI element at offset 0', () {
    final c = RichMessageController();
    c.insertAnimoji(_a(125, '❤️', 'L1'));

    final content = c.buildContent();
    expect(content.text, '❤️');
    expect(content.elements, [
      {
        'type': 'ANIMOJI',
        'from': 0,
        'length': 2,
        'entityId': 125,
        'attributes': {'animojiLottieUrl': 'L1'},
      },
    ]);
  });

  test('animoji appended after text gets the correct utf16 offset', () {
    final c = RichMessageController();
    c.value = const TextEditingValue(
      text: 'test',
      selection: TextSelection.collapsed(offset: 4),
    );
    c.insertAnimoji(_a(7, '🤣', 'L2'));

    final content = c.buildContent();
    expect(content.text, 'test🤣');
    expect(content.elements.single['from'], 4);
    expect(content.elements.single['length'], 2);
    expect(content.elements.single['type'], 'ANIMOJI');
  });

  test('multiple animoji with surrounding text keep glyph offsets in order', () {
    final c = RichMessageController();
    c.value = const TextEditingValue(
      text: 'a',
      selection: TextSelection.collapsed(offset: 1),
    );
    c.insertAnimoji(_a(1, '❤️', 'L1'));
    // caret now after first placeholder; type "b"
    final t1 = c.value.text; // "a￼"
    c.value = TextEditingValue(
      text: '${t1}b',
      selection: TextSelection.collapsed(offset: t1.length + 1),
    );
    c.insertAnimoji(_a(2, '🔥', 'L3'));

    final content = c.buildContent();
    expect(content.text, 'a❤️b🔥');

    final froms = content.elements
        .where((e) => e['type'] == 'ANIMOJI')
        .map((e) => e['from'])
        .toList();
    expect(froms, [1, 4]);
  });

  testWidgets('built span plain text matches controller text (caret invariant)', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        builder: (context, _) {
          ctx = context;
          return const SizedBox();
        },
      ),
    );

    final c = RichMessageController();
    c.value = const TextEditingValue(
      text: 'hi',
      selection: TextSelection.collapsed(offset: 2),
    );
    c.insertAnimoji(_a(1, '❤️', 'L1'));
    c.value = TextEditingValue(
      text: '${c.value.text}!',
      selection: TextSelection.collapsed(offset: c.value.text.length + 1),
    );

    final span = c.buildTextSpan(
      context: ctx,
      style: const TextStyle(fontSize: 16),
      withComposing: false,
    );
    expect(span.toPlainText(), c.text);
  });

  test('deleting the placeholder char drops the entity', () {
    final c = RichMessageController();
    c.insertAnimoji(_a(1, '❤️', 'L1'));
    expect(c.value.text.length, 1);
    // backspace: remove the placeholder
    c.value = const TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    final content = c.buildContent();
    expect(content.text, '');
    expect(content.elements, isEmpty);
  });
}
