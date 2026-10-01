import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/message_copy.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/backend/modules/forward_sender.dart';
import 'package:komet/models/attachment.dart';

CachedMessage _message({
  String? text,
  List<Map<String, dynamic>> attaches = const [],
  List<Map<String, dynamic>> elements = const [],
  Map<String, dynamic>? link,
  int e2ee = CachedMessage.e2eeNone,
}) {
  final payload = <String, dynamic>{
    'id': 501,
    'sender': 9,
    'text': text,
    'attaches': attaches,
    'elements': elements,
    'link': ?link,
  };
  final (attachments, isControl) = CachedMessage.parseAttachments(payload);
  return CachedMessage(
    id: '501',
    accountId: 1,
    chatId: 10,
    senderId: 9,
    text: text,
    time: 1000,
    status: 'sent',
    payload: payload,
    attachments: attachments,
    isControl: isControl,
    e2ee: e2ee,
  );
}

ForwardRequest _request(List<CachedMessage> messages) => ForwardRequest(
  sourceChatId: 10,
  sourceChatName: 'Synthetic chat',
  sourceChatIconUrl: '',
  sourceChatType: 'CHAT',
  messages: messages,
);

void main() {
  group('MessageCopy', () {
    test('keeps text and formatting', () {
      final copy = MessageCopy.of(
        _message(
          text: 'Synthetic bold text',
          elements: [
            {'type': 'STRONG', 'from': 10, 'length': 4},
          ],
        ),
      )!;

      expect(copy.text, 'Synthetic bold text');
      expect(copy.elements, [
        {'type': 'STRONG', 'from': 10, 'length': 4},
      ]);
      expect(copy.wireAttaches, isEmpty);
    });

    test('drops the inline keyboard but keeps the rest of the message', () {
      final copy = MessageCopy.of(
        _message(
          text: 'Synthetic bot greeting',
          attaches: [
            {
              '_type': 'INLINE_KEYBOARD',
              'keyboard': {
                'buttons': [
                  [
                    {'type': 'CALLBACK', 'text': 'Synthetic button'},
                  ],
                ],
              },
            },
          ],
        ),
      )!;

      expect(copy.text, 'Synthetic bot greeting');
      expect(copy.attaches, isEmpty);
      expect(copy.wireAttaches, isEmpty);
    });

    test('has nothing to send when only a keyboard is left', () {
      final message = _message(
        text: '',
        attaches: [
          {'_type': 'INLINE_KEYBOARD', 'keyboard': const {}},
        ],
      );

      expect(MessageCopy.of(message), isNull);
    });

    test('refuses polls, calls and service messages', () {
      for (final type in ['POLL', 'CALL', 'CONTROL']) {
        final message = _message(
          text: 'Synthetic',
          attaches: [
            {'_type': type},
          ],
        );
        expect(MessageCopy.of(message), isNull, reason: type);
      }
    });

    test('refuses an attachment it does not know', () {
      final message = _message(
        attaches: [
          {'_type': 'SYNTHETIC_FUTURE_TYPE'},
        ],
      );

      expect(MessageCopy.of(message), isNull);
    });

    test('refuses an encrypted message', () {
      final message = _message(
        text: 'Synthetic ciphertext',
        e2ee: CachedMessage.e2eeText,
      );

      expect(MessageCopy.of(message), isNull);
    });

    test('refuses media it has no reference for', () {
      final message = _message(
        attaches: [
          {'_type': 'PHOTO', 'baseUrl': 'https://example.test/p.jpg'},
        ],
      );

      expect(MessageCopy.of(message), isNull);
    });

    test('re-sends media by reference', () {
      final copy = MessageCopy.of(
        _message(
          text: 'Synthetic caption',
          attaches: [
            {
              '_type': 'PHOTO',
              'photoId': 1,
              'photoToken': 'photo-token',
              'baseUrl': 'https://example.test/p.jpg',
              'width': 10,
              'height': 10,
            },
            {'_type': 'VIDEO', 'videoId': 2, 'token': 'video-token'},
            {'_type': 'FILE', 'fileId': 3, 'name': 'synthetic.pdf'},
            {'_type': 'STICKER', 'stickerId': '4'},
            {'_type': 'CONTACT', 'contactId': 5, 'name': 'Synthetic'},
            {'_type': 'LOCATION', 'latitude': 1, 'longitude': 2.5},
            {'_type': 'SHARE', 'url': 'https://example.test'},
          ],
        ),
      )!;

      expect(copy.text, 'Synthetic caption');
      expect(copy.attaches, hasLength(6));
      expect(copy.wireAttaches, [
        {'_type': 'PHOTO', 'photoToken': 'photo-token'},
        {'videoType': 0, '_type': 'VIDEO', 'token': 'video-token'},
        {'_type': 'FILE', 'fileId': 3},
        {'_type': 'STICKER', 'stickerId': 4},
        {'_type': 'CONTACT', 'contactId': 5},
        {'_type': 'LOCATION', 'latitude': 1.0, 'longitude': 2.5, 'zoom': 15.0},
      ]);
    });

    test('keeps the waveform of voice and video messages', () {
      final copy = MessageCopy.of(
        _message(
          attaches: [
            {
              '_type': 'AUDIO',
              'audioId': 6,
              'token': 'audio-token',
              'duration': 3000,
              'wave': [1, 2, 3],
            },
            {
              '_type': 'VIDEO',
              'videoType': 1,
              'token': 'note-token',
              'duration': 4000,
              'thumbhash': 'synthetic-hash',
            },
          ],
        ),
      )!;

      final voice = copy.wireAttaches[0];
      expect(voice['token'], 'audio-token');
      expect(voice['duration'], 3000);
      expect(voice['wave'], Uint8List.fromList([1, 2, 3]));

      final note = copy.wireAttaches[1];
      expect(note['videoType'], 1);
      expect(note['token'], 'note-token');
      expect(note['duration'], 4000);
      expect(note['thumbhash'], 'synthetic-hash');
      expect(note['wave'], hasLength(80));
    });

    test('copies the original of a forwarded message', () {
      final copy = MessageCopy.of(
        _message(
          link: {
            'type': 'FORWARD',
            'chatId': -20,
            'messageId': 77,
            'message': {
              'id': 77,
              'sender': 42,
              'text': 'Synthetic original',
              'attaches': [
                {'_type': 'PHOTO', 'photoToken': 'original-token'},
              ],
            },
          },
        ),
      )!;

      expect(copy.text, 'Synthetic original');
      expect(copy.wireAttaches, [
        {'_type': 'PHOTO', 'photoToken': 'original-token'},
      ]);
    });

    test('builds an outgoing message that renders right away', () {
      final copy = MessageCopy.of(
        _message(
          text: 'Synthetic caption',
          attaches: [
            {'_type': 'PHOTO', 'photoToken': 'photo-token'},
          ],
        ),
      )!;

      final outgoing = copy.toOutgoing(
        accountId: 1,
        chatId: 30,
        tempId: 'temp_1',
        time: 2000,
      );

      expect(outgoing.id, 'temp_1');
      expect(outgoing.chatId, 30);
      expect(outgoing.senderId, 1);
      expect(outgoing.text, 'Synthetic caption');
      expect(outgoing.status, 'sending');
      expect(outgoing.forwardedAttachment, isNull);
      expect(outgoing.attachments!.single, isA<PhotoAttachment>());
    });
  });

  group('ForwardRequest', () {
    test('hides the sender only when every message can be copied', () {
      final text = _message(text: 'Synthetic');
      final poll = _message(
        attaches: [
          {'_type': 'POLL', 'title': 'Synthetic poll'},
        ],
      );

      expect(_request([text]).canHideSender, isTrue);
      expect(_request([text, poll]).canHideSender, isFalse);
    });

    test('keeps the chosen mode while messages are sent one by one', () {
      final request = _request([
        _message(text: 'First'),
        _message(text: 'Second'),
      ]).withHideSender(true);

      final rest = request.withMessages([request.messages.last]);

      expect(rest.hideSender, isTrue);
      expect(rest.messages.single.text, 'Second');
    });
  });
}
