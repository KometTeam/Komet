import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/sent_message.dart';

void main() {
  test('reads the message the server actually stored', () {
    final sent = SentMessage.fromResponse({
      'chatId': 1,
      'message': {
        'id': 42,
        'text': 'Synthetic',
        'elements': [
          {'type': 'HEADING', 'length': 9},
        ],
      },
    });

    expect(sent.id, '42');
    expect(sent.text, 'Synthetic');
    expect(sent.elements, [
      {'type': 'HEADING', 'length': 9},
    ]);
  });

  test('an echo without elements means none were accepted', () {
    final sent = SentMessage.fromResponse({
      'message': {'id': 7, 'text': 'Synthetic'},
    });
    final local = {
      'link': {'type': 'REPLY', 'messageId': 3},
      'elements': [
        {'type': 'LINK', 'from': 0, 'length': 4},
      ],
    };

    expect(sent.payloadOver(local), {
      'link': {'type': 'REPLY', 'messageId': 3},
    });
    expect(
      sent.payloadOver({
        'elements': [
          {'type': 'LINK', 'from': 0, 'length': 4},
        ],
      }),
      isNull,
    );
  });

  test('a bare id keeps the local formatting', () {
    final sent = SentMessage.fromResponse({
      'message': {'id': 7, 'time': 1},
    });
    final local = {
      'elements': [
        {'type': 'STRONG', 'from': 0, 'length': 4},
      ],
    };

    expect(sent.text, isNull);
    expect(sent.elements, isNull);
    expect(sent.payloadOver(local), same(local));
  });

  test('an edit echo carries the attachments the server kept', () {
    final sent = SentMessage.fromResponse({
      'message': {
        'id': 9,
        'text': '',
        'status': 'EDITED',
        'attaches': [
          {'_type': 'PHOTO', 'photoId': 1, 'photoToken': 'synthetic-a'},
          'not a map',
        ],
      },
    });
    final stripped = SentMessage.fromResponse({
      'message': {'id': 9, 'text': 'Synthetic', 'attaches': []},
    });

    expect(sent.attaches, [
      {'_type': 'PHOTO', 'photoId': 1, 'photoToken': 'synthetic-a'},
    ]);
    expect(stripped.attaches, isEmpty);
    expect(
      SentMessage.fromResponse({
        'message': {'id': 9},
      }).attaches,
      isNull,
    );
  });
}
