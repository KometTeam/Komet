import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/models/attachment.dart';

Map<String, dynamic> _replyTo(Map<String, dynamic> quoted) => {
  'link': {'type': 'REPLY', 'chatId': 100, 'message': quoted},
};

void main() {
  test('reply to a forwarded text quotes the forwarded text', () {
    final reply = ReplyInfo.fromPayload(
      _replyTo({
        'id': 501,
        'sender': 11,
        'text': '',
        'time': 1700000000000,
        'attaches': const [],
        'link': {
          'type': 'FORWARD',
          'chatId': 200,
          'message': {
            'id': 77,
            'sender': 22,
            'text': 'пересланный текст',
            'time': 1690000000000,
            'attaches': const [],
          },
        },
      }),
    );

    expect(reply, isNotNull);
    expect(reply!.missing, isFalse);
    expect(reply.text, 'пересланный текст');
    expect(reply.senderId, 11);
  });

  test('reply to a forwarded photo quotes the photo', () {
    final reply = ReplyInfo.fromPayload(
      _replyTo({
        'id': 502,
        'sender': 11,
        'text': '',
        'attaches': const [],
        'link': {
          'type': 'FORWARD',
          'message': {
            'id': 78,
            'sender': 22,
            'text': '',
            'attaches': [
              {'_type': 'PHOTO', 'photoId': 9, 'baseUrl': 'https://example.invalid/p'},
            ],
          },
        },
      }),
    );

    expect(reply!.missing, isFalse);
    expect(reply.attachments!.first.type, AttachmentType.photo);
    expect(reply.previewText(), 'Фото');
  });

  test('reply whose original is really gone stays missing', () {
    final reply = ReplyInfo.fromPayload(
      _replyTo({'id': 503, 'sender': 11, 'text': '', 'attaches': const []}),
    );

    expect(reply!.missing, isTrue);
  });
}
