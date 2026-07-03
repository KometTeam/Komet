import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/text_format.dart';
import 'package:komet/frontend/widgets/formatted_message_text.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';

void main() {
  group('parse + segmentize', () {
    test('missing from defaults to 0', () {
      final ranges = parseFormatElements([
        {'type': 'STRONG', 'length': 2},
      ]);
      expect(ranges.single.start, 0);
      expect(ranges.single.length, 2);
      expect(ranges.single.format, TextFormat.strong);
    });

    test('overlapping ranges split into segments with merged formats', () {
      const text = 'Hi, how are you?';
      final ranges = parseFormatElements([
        {'type': 'STRIKETHROUGH', 'from': 0, 'length': 2},
        {'type': 'QUOTE', 'from': 0, 'length': 16},
        {'type': 'EMPHASIZED', 'from': 4, 'length': 3},
        {'type': 'UNDERLINE', 'from': 4, 'length': 3},
        {'type': 'EMPHASIZED', 'from': 7, 'length': 5},
        {'type': 'STRONG', 'from': 12, 'length': 4},
        {'type': 'EMPHASIZED', 'from': 12, 'length': 4},
      ]);
      final segments = segmentizeFormats(text, ranges);
      expect(segments.first.start, 0);
      expect(segments.last.end, 16);
      for (var i = 0; i + 1 < segments.length; i++) {
        expect(segments[i].end, segments[i + 1].start);
      }
      final seg = segments.firstWhere((s) => s.start == 4);
      expect(seg.formats, containsAll([
        TextFormat.quote,
        TextFormat.emphasized,
        TextFormat.underline,
      ]));
      final last = segments.firstWhere((s) => s.start == 12);
      expect(last.formats, containsAll([
        TextFormat.strong,
        TextFormat.emphasized,
        TextFormat.quote,
      ]));
    });
  });

  group('RichMessageController', () {
    test('toggle emits element and toggle again removes it', () {
      final c = RichMessageController(text: 'Hi druk');
      c.selection = const TextSelection(baseOffset: 3, extentOffset: 7);
      c.toggleFormat(TextFormat.underline);
      final els = c.elementsForSend();
      expect(els, [
        {'type': 'UNDERLINE', 'from': 3, 'length': 4},
      ]);
      c.selection = const TextSelection(baseOffset: 3, extentOffset: 7);
      c.toggleFormat(TextFormat.underline);
      expect(c.elementsForSend(), isEmpty);
    });

    test('range shifts when text inserted before it', () {
      final c = RichMessageController(text: 'bold');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
      c.toggleFormat(TextFormat.strong);
      c.value = c.value.copyWith(
        text: 'XXbold',
        selection: const TextSelection.collapsed(offset: 2),
      );
      expect(c.elementsForSend(), [
        {'type': 'STRONG', 'from': 2, 'length': 4},
      ]);
    });

    test('range grows when typing inside it', () {
      final c = RichMessageController(text: 'Hello');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      c.toggleFormat(TextFormat.strong);
      c.value = c.value.copyWith(
        text: 'HelXlo',
        selection: const TextSelection.collapsed(offset: 4),
      );
      expect(c.elementsForSend(), [
        {'type': 'STRONG', 'from': 0, 'length': 6},
      ]);
    });

    test('range drops when its text is deleted', () {
      final c = RichMessageController(text: 'alo');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      c.toggleFormat(TextFormat.strikethrough);
      c.value = c.value.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
      expect(c.elementsForSend(), isEmpty);
    });

    test('overlapping toggles of different types coexist', () {
      final c = RichMessageController(text: 'Hi, how are you?');
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
      c.toggleFormat(TextFormat.emphasized);
      c.toggleFormat(TextFormat.underline);
      final els = c.elementsForSend();
      expect(els.length, 2);
      expect(els, containsAll([
        {'type': 'EMPHASIZED', 'from': 4, 'length': 3},
        {'type': 'UNDERLINE', 'from': 4, 'length': 3},
      ]));
    });

    test('adjacent same-type toggles merge', () {
      final c = RichMessageController(text: 'abcdef');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
      c.toggleFormat(TextFormat.strong);
      c.selection = const TextSelection(baseOffset: 3, extentOffset: 6);
      c.toggleFormat(TextFormat.strong);
      expect(c.elementsForSend(), [
        {'type': 'STRONG', 'from': 0, 'length': 6},
      ]);
    });

    test('setFormatRanges loads composer formats and drops others', () {
      final c = RichMessageController(text: 'Hi druk');
      c.setFormatRanges(parseFormatElements([
        {'type': 'UNDERLINE', 'from': 3, 'length': 4},
        {'type': 'MONOSPACED', 'from': 0, 'length': 2},
        {'type': 'LINK', 'from': 0, 'length': 2, 'attributes': {'url': 'x'}},
      ]));
      expect(c.elementsForSend(), [
        {'type': 'UNDERLINE', 'from': 3, 'length': 4},
      ]);
    });

    test('buildInlineSpan reproduces preview text with prefix shift', () {
      const preview = 'Alice: Hi druk';
      final ranges = parseFormatElements([
        {'type': 'STRONG', 'from': 3, 'length': 4},
      ]).map((r) => FormatRange(
        format: r.format,
        start: r.start + 'Alice: '.length,
        length: r.length,
      ));
      final span = FormattedMessageText.buildInlineSpan(
        preview,
        ranges.toList(),
        const TextStyle(),
      );
      expect(span.toPlainText(), preview);
    });

    testWidgets('buildTextSpan reproduces text exactly', (tester) async {
      final c = RichMessageController(text: 'Hi, how are you?');
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
      c.toggleFormat(TextFormat.strong);
      c.toggleFormat(TextFormat.emphasized);
      late TextSpan span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              span = c.buildTextSpan(
                context: context,
                style: const TextStyle(),
                withComposing: false,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(span.toPlainText(), 'Hi, how are you?');
    });
  });
}
