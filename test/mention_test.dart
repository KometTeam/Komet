import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:komet/core/utils/text_format.dart';
import 'package:komet/models/contact_info.dart';
import 'package:komet/frontend/screens/chats/chat/mention_panel_controller.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';

void main() {
  group('mentionQueryAt', () {
    test('detects a bare @ at the start', () {
      final q = mentionQueryAt('@', 1)!;
      expect(q.start, 0);
      expect(q.end, 1);
      expect(q.text, '');
    });

    test('detects a query after a space', () {
      final q = mentionQueryAt('hi @ал', 6)!;
      expect(q.start, 3);
      expect(q.end, 6);
      expect(q.text, 'ал');
    });

    test('ignores an @ glued to a preceding word', () {
      expect(mentionQueryAt('mail@ya', 7), isNull);
    });

    test('ignores a token that already contains a space', () {
      expect(mentionQueryAt('@ал ексей', 9), isNull);
    });

    test('ignores text without an @ before the caret', () {
      expect(mentionQueryAt('привет', 6), isNull);
    });
  });

  group('RichMessageController mentions', () {
    test('insertMention replaces the token and emits USER_MENTION', () {
      final c = RichMessageController();
      c.value = const TextEditingValue(
        text: '@ал',
        selection: TextSelection.collapsed(offset: 3),
      );
      final query = mentionQueryAt(c.text, 3)!;
      c.insertMention(
        userId: 555001,
        name: 'Пётр Синицын',
        start: query.start,
        end: query.end,
      );
      c.value = TextEditingValue(
        text: '${c.text}test',
        selection: TextSelection.collapsed(offset: c.text.length + 4),
      );

      final content = c.buildContent();
      expect(content.text, 'Пётр Синицын test');
      expect(content.elements, [
        {'type': 'USER_MENTION', 'from': 0, 'length': 12, 'entityId': 555001},
      ]);
    });

    test('editing inside a mention drops it', () {
      final c = RichMessageController();
      c.value = const TextEditingValue(
        text: '@a',
        selection: TextSelection.collapsed(offset: 2),
      );
      c.insertMention(userId: 42, name: 'Иван', start: 0, end: 2);
      expect(c.buildContent().elements, hasLength(1));

      c.value = const TextEditingValue(
        text: 'Ив ',
        selection: TextSelection.collapsed(offset: 2),
      );
      expect(c.buildContent().elements, isEmpty);
    });

    test('text typed before a mention shifts its offset', () {
      final c = RichMessageController();
      c.value = const TextEditingValue(
        text: '@a',
        selection: TextSelection.collapsed(offset: 2),
      );
      c.insertMention(userId: 42, name: 'Иван', start: 0, end: 2);
      c.value = const TextEditingValue(
        text: 'эй, Иван ',
        selection: TextSelection.collapsed(offset: 4),
      );

      final element = c.buildContent().elements.single;
      expect(element['from'], 4);
      expect(element['length'], 4);
      expect(element['entityId'], 42);
    });

    test('setFormatRanges restores mentions for editing', () {
      final c = RichMessageController(text: 'Иван привет');
      c.setFormatRanges(const [
        FormatRange(
          format: TextFormat.userMention,
          start: 0,
          length: 4,
          entityId: 42,
        ),
      ]);

      expect(c.buildContent().elements, [
        {'type': 'USER_MENTION', 'from': 0, 'length': 4, 'entityId': 42},
      ]);
    });
  });

  group('ContactInfo names', () {
    ContactInfo info(List<Map<String, dynamic>> names) =>
        ContactInfo.fromMap({'id': 1, 'names': names});

    test('full name joins first and last, not the short name field', () {
      final contact = info([
        {
          'name': 'Светлана',
          'firstName': 'Светлана',
          'lastName': 'Михайловна',
          'type': 'CUSTOM',
        },
        {
          'name': 'Светлана',
          'firstName': 'Светлана',
          'lastName': '',
          'type': 'ONEME',
        },
      ]);

      expect(contact.fullName, 'Светлана Михайловна');
      expect(contact.isSavedContact, isTrue);
    });

    test('a non-contact falls back to the ONEME name', () {
      final contact = info([
        {
          'name': 'Пётр',
          'firstName': 'Пётр',
          'lastName': 'Синицын',
          'type': 'ONEME',
        },
      ]);

      expect(contact.fullName, 'Пётр Синицын');
      expect(contact.isSavedContact, isFalse);
    });

    test('a custom name wins over the oneme one', () {
      final contact = info([
        {'firstName': 'Лёша', 'lastName': 'сосед', 'type': 'CUSTOM'},
        {'firstName': 'Пётр', 'lastName': 'Синицын', 'type': 'ONEME'},
      ]);

      expect(contact.fullName, 'Лёша сосед');
    });
  });

  group('parseFormatElements', () {
    test('reads a server USER_MENTION without an explicit from', () {
      final ranges = parseFormatElements([
        {'entityId': 555001, 'type': 'USER_MENTION', 'length': 12},
      ]);
      expect(ranges.single.format, TextFormat.userMention);
      expect(ranges.single.start, 0);
      expect(ranges.single.length, 12);
      expect(ranges.single.entityId, 555001);
    });

    test('segmentizeFormats carries the mention id onto its segment', () {
      final segments = segmentizeFormats('Пётр Синицын test', const [
        FormatRange(
          format: TextFormat.userMention,
          start: 0,
          length: 12,
          entityId: 555001,
        ),
      ]);
      expect(segments.first.mentionId, 555001);
      expect(segments.last.mentionId, isNull);
    });
  });
}
