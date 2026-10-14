import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/widgets/link_text.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';
import 'package:komet/models/animoji.dart';

RichMessageController _controller(String text, int start, int end) =>
    RichMessageController()
      ..value = TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: start, extentOffset: end),
      );

void main() {
  group('heading', () {
    test('covers the whole line of the selection', () {
      final c = _controller('first line\nsecond', 6, 10);
      c.toggleFormat(TextFormat.heading);

      expect(c.elementsForSend(), [
        {'type': 'HEADING', 'from': 0, 'length': 10},
      ]);
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      expect(c.isFormatActive(TextFormat.heading), isTrue);
    });

    test('spans every selected line and toggles back off', () {
      final c = _controller('one\ntwo\nthree', 2, 5);
      c.toggleFormat(TextFormat.heading);
      expect(c.elementsForSend(), [
        {'type': 'HEADING', 'from': 0, 'length': 7},
      ]);

      c.toggleFormat(TextFormat.heading);
      expect(c.elementsForSend(), isEmpty);
    });

    test('a selection ending on a newline keeps to its own line', () {
      final c = _controller('one\ntwo', 0, 4);
      c.toggleFormat(TextFormat.heading);
      expect(c.elementsForSend(), [
        {'type': 'HEADING', 'from': 0, 'length': 3},
      ]);
    });
  });

  test('monospace stays on the selected characters', () {
    final c = _controller('run make test now', 4, 13);
    c.toggleFormat(TextFormat.monospaced);

    expect(c.isFormatActive(TextFormat.monospaced), isTrue);
    expect(c.elementsForSend(), [
      {'type': 'MONOSPACED', 'from': 4, 'length': 9},
    ]);
  });

  test('red text is sent as CODE and drawn red', () {
    final c = _controller('alarm now', 0, 5);
    c.toggleFormat(TextFormat.code);
    expect(c.elementsForSend(), [
      {'type': 'CODE', 'from': 0, 'length': 5},
    ]);

    final parsed = parseFormatElements([
      {'type': 'CODE', 'length': 5},
    ]);
    expect(parsed.single.format, TextFormat.code);
    final style = applyTextFormats(const TextStyle(color: Color(0xFF000000)), {
      TextFormat.code,
    });
    expect(style.color, codeTextColor);
  });

  group('link', () {
    test('wraps the selection with its url', () {
      final c = _controller('Test 123', 0, 8);
      c.setLink(c.selection, 'https://example.com');

      expect(c.isFormatActive(TextFormat.link), isTrue);
      expect(c.elementsForSend(), [
        {
          'type': 'LINK',
          'from': 0,
          'length': 8,
          'attributes': {'url': 'https://example.com'},
        },
      ]);
    });

    test('follows edits before and inside the link', () {
      final c = _controller('see docs now', 4, 8);
      c.setLink(c.selection, 'https://example.com/docs');

      c.value = const TextEditingValue(
        text: '>> see docs now',
        selection: TextSelection.collapsed(offset: 3),
      );
      c.value = const TextEditingValue(
        text: '>> see dooocs now',
        selection: TextSelection.collapsed(offset: 10),
      );

      final link = c.elementsForSend().single;
      expect(link['from'], 7);
      expect(link['length'], 6);
    });

    test('removing it from part of the range keeps the rest', () {
      final c = _controller('abcdef', 0, 6);
      c.setLink(c.selection, 'https://example.com');
      c.setLink(const TextRange(start: 2, end: 4), null);

      final froms = [
        for (final e in c.elementsForSend()) (e['from'], e['length']),
      ];
      expect(froms, [(0, 2), (4, 2)]);
    });

    test('server links survive editing a message', () {
      final ranges = parseFormatElements([
        {
          'type': 'LINK',
          'length': 4,
          'attributes': {'checkResult': 2, 'url': 'https://example.com'},
        },
        {'type': 'HEADING', 'from': 5, 'length': 3},
      ]);
      final c = RichMessageController(text: 'link top')
        ..setFormatRanges(ranges);

      final types = {
        for (final e in c.elementsForSend())
          e['type']: (e['attributes'] as Map?)?['url'],
      };
      expect(types, {'LINK': 'https://example.com', 'HEADING': null});
    });

    test('keeps its url next to animoji', () {
      final c = _controller('go ', 0, 2);
      c.setLink(c.selection, 'https://example.com');
      c.selection = const TextSelection.collapsed(offset: 3);
      c.insertAnimoji(const Animoji(id: 1, emoji: '🔥', lottieUrl: 'L'));

      final link = c.buildContent().elements.firstWhere(
        (e) => e['type'] == 'LINK',
      );
      expect(link['attributes'], {'url': 'https://example.com'});
    });
  });

  group('link input', () {
    test('adds a scheme to bare domains', () {
      expect(linkFromInput(' example.com/a '), 'https://example.com/a');
      expect(linkFromInput('Https://Example.com'), 'Https://Example.com');
      expect(linkFromInput('komet://chat'), 'komet://chat');
    });

    test('rejects text that is not a link', () {
      expect(linkFromInput(''), isNull);
      expect(linkFromInput('hello'), isNull);
      expect(linkFromInput('two words.com'), isNull);
    });
  });
}
