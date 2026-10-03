import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_preview.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/models/attachment.dart';
import 'package:komet/models/chat_preview_media.dart';

const int _accountId = 77;
const int _chatId = 4242;

CachedMessage _pending(List<MessageAttachment> attachments, {String? text}) =>
    CachedMessage(
      id: 'temp_1_1700000000000000',
      accountId: _accountId,
      chatId: _chatId,
      senderId: _accountId,
      text: text,
      time: 1700000000000,
      status: 'sending',
      attachments: attachments,
    );

ChatPreviewMedia _media(CachedMessage message) {
  final decoded = ChatPreviewMedia.decode(
    messagePreviewMedia(message.previewPayload),
  );
  expect(decoded, isNotNull);
  return decoded!;
}

void main() {
  group('превью своего медиа, которое ещё грузится', () {
    test('фото без подписи показывает файл с диска как миниатюру', () {
      final message = _pending([
        const PhotoAttachment(localPath: '/tmp/komet/shot.jpg'),
      ]);

      final media = _media(message);
      expect(media.kind, ChatPreviewKind.photo);
      expect(media.label, 'Изображение');
      expect(media.thumbs.single.source, 'file:///tmp/komet/shot.jpg');
      expect(media.thumbs.single.video, isFalse);
      expect(messagePreviewText(message.previewPayload), 'Изображение');
    });

    test('альбом отдаёт миниатюру на каждое фото', () {
      final message = _pending([
        const PhotoAttachment(localPath: '/tmp/komet/one.jpg'),
        const PhotoAttachment(localPath: '/tmp/komet/two.jpg'),
      ]);

      final media = _media(message);
      expect(media.label, 'Изображения');
      expect(media.thumbs.map((t) => t.source), [
        'file:///tmp/komet/one.jpg',
        'file:///tmp/komet/two.jpg',
      ]);
    });

    test('подпись к фото вытесняет словесную метку', () {
      final message = _pending([
        const PhotoAttachment(localPath: '/tmp/komet/shot.jpg'),
      ], text: 'смотри какой закат');

      final media = _media(message);
      expect(media.captioned, isTrue);
      expect(media.label, isNull);
      expect(
        messagePreviewText(message.previewPayload),
        'смотри какой закат',
      );
    });

    test('видео берёт свой кадр, а не файл с диска', () {
      const thumb = 'data:image/jpeg;base64,AAAA';
      final message = _pending([
        const VideoAttachment(
          localPath: '/tmp/komet/clip.mp4',
          previewData: thumb,
          duration: 3000,
        ),
      ]);

      final media = _media(message);
      expect(media.kind, ChatPreviewKind.video);
      expect(media.thumbs.single.source, thumb);
      expect(media.thumbs.single.video, isTrue);
    });

    test('кружок без кадра остаётся без миниатюры', () {
      final message = _pending([
        const VideoAttachment(
          localPath: '/tmp/komet/note.mp4',
          videoType: 1,
          duration: 3000,
        ),
      ]);

      final media = _media(message);
      expect(media.kind, ChatPreviewKind.videoNote);
      expect(media.thumbs, isEmpty);
      expect(media.label, 'Видео-сообщение');
    });

    test('файл подписывается именем', () {
      final message = _pending([
        const FileAttachment(name: 'отчёт.pdf', size: 1024),
      ]);

      final media = _media(message);
      expect(media.kind, ChatPreviewKind.file);
      expect(media.label, 'Файл');
      expect(media.detail, 'отчёт.pdf');
    });

    test('ответ сервера вытесняет локальный payload', () {
      final real = CachedMessage.fromPushPayload(_accountId, _chatId, {
        'id': '900',
        'sender': _accountId,
        'time': 1700000001000,
        'text': '',
        'attaches': [
          {
            '_type': 'PHOTO',
            'photoId': 5,
            'baseUrl': 'https://cdn.example.test/shot.jpg',
          },
        ],
      });

      final media = _media(real);
      expect(media.kind, ChatPreviewKind.photo);
      expect(media.thumbs.single.source, 'https://cdn.example.test/shot.jpg');
    });
  });
}
