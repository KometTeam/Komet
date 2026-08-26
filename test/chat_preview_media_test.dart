import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/chat_preview.dart';
import 'package:komet/models/chat_preview_media.dart';

const String _thumbA = 'data:image/webp;base64,AAAA';
const String _thumbB = 'data:image/webp;base64,BBBB';
const String _thumbC = 'data:image/webp;base64,CCCC';
const String _thumbD = 'data:image/webp;base64,DDDD';

Map<String, dynamic> _photo(String preview) => {
  '_type': 'PHOTO',
  'previewData': preview,
  'photoId': 1,
};

Map<String, dynamic> _video(String preview) => {
  '_type': 'VIDEO',
  'previewData': preview,
  'videoId': 2,
};

ChatPreviewMedia _media(Map<String, dynamic> msg) {
  final encoded = messagePreviewMedia(msg);
  expect(encoded, isNotNull);
  final decoded = ChatPreviewMedia.decode(encoded);
  expect(decoded, isNotNull);
  return decoded!;
}

void main() {
  group('превью вложений', () {
    test('одиночное фото без подписи даёт миниатюру и словесную подпись', () {
      final msg = {
        'text': '',
        'attaches': [_photo(_thumbA)],
      };
      final media = _media(msg);
      expect(media.kind, ChatPreviewKind.photo);
      expect(media.captioned, isFalse);
      expect(media.label, 'Изображение');
      expect(media.detail, isNull);
      expect(media.thumbs.map((t) => t.source), [_thumbA]);
      expect(media.thumbs.single.video, isFalse);
      expect(messagePreviewText(msg), 'Изображение');
    });

    test('фото с подписью оставляет текст сообщения', () {
      final msg = {
        'text': 'подпись',
        'attaches': [_photo(_thumbA)],
      };
      final media = _media(msg);
      expect(media.captioned, isTrue);
      expect(media.label, isNull);
      expect(media.thumbs, hasLength(1));
      expect(messagePreviewText(msg), 'подпись');
    });

    test('альбом отдаёт не больше трёх миниатюр и помечает видео', () {
      final msg = {
        'text': '',
        'attaches': [
          _photo(_thumbA),
          _video(_thumbB),
          _photo(_thumbC),
          _photo(_thumbD),
        ],
      };
      final media = _media(msg);
      expect(media.label, 'Изображения');
      expect(media.thumbs.map((t) => t.source), [_thumbA, _thumbB, _thumbC]);
      expect(media.thumbs.map((t) => t.video), [false, true, false]);
    });

    test('кружок не считается обычным видео', () {
      final msg = {
        'text': '',
        'attaches': [
          {'_type': 'VIDEO', 'videoType': 1, 'previewData': _thumbA},
        ],
      };
      final media = _media(msg);
      expect(media.kind, ChatPreviewKind.videoNote);
      expect(media.label, 'Видео-сообщение');
    });

    test('файл отдаёт имя отдельно от подписи', () {
      final msg = {
        'text': '',
        'attaches': [
          {'_type': 'FILE', 'name': 'notes.pdf', 'fileId': 3},
        ],
      };
      final media = _media(msg);
      expect(media.kind, ChatPreviewKind.file);
      expect(media.label, 'Файл');
      expect(media.detail, 'notes.pdf');
      expect(media.thumbs, isEmpty);
      expect(messagePreviewText(msg), 'Файл: notes.pdf');
    });

    test('пропущенный звонок отличается от состоявшегося', () {
      final missed = _media({
        'text': '',
        'attaches': [
          {'_type': 'CALL', 'callType': 'AUDIO', 'duration': 0},
        ],
      });
      expect(missed.kind, ChatPreviewKind.missedCall);
      expect(missed.label, 'Пропущенный звонок');

      final answered = _media({
        'text': '',
        'attaches': [
          {'_type': 'CALL', 'callType': 'VIDEO', 'duration': 42},
        ],
      });
      expect(answered.kind, ChatPreviewKind.videoCall);
      expect(answered.label, 'Видеозвонок');
    });

    test('пересланное вложение сохраняет метку пересылки', () {
      final msg = {
        'text': '',
        'link': {
          'type': 'FORWARD',
          'message': {
            'text': '',
            'attaches': [_photo(_thumbA)],
          },
        },
      };
      final media = _media(msg);
      expect(media.kind, ChatPreviewKind.photo);
      expect(media.label, '↪ Изображение');
      expect(media.thumbs, hasLength(1));
      expect(messagePreviewText(msg), '↪ Изображение');
    });

    test('клавиатура бота не считается вложением', () {
      final encoded = messagePreviewMedia({
        'text': 'выбери вариант',
        'attaches': [
          {'_type': 'INLINE_KEYBOARD'},
        ],
      });
      expect(encoded, isNull);
    });

    test('без вложений описания нет', () {
      expect(messagePreviewMedia({'text': 'привет'}), isNull);
    });

    test('слишком тяжёлая миниатюра не попадает в кеш чатов', () {
      final heavy = 'data:image/webp;base64,${'A' * 30000}';
      final media = _media({
        'text': '',
        'attaches': [_photo(heavy)],
      });
      expect(media.thumbs, isEmpty);
    });

    test('описание переживает сериализацию', () {
      const media = ChatPreviewMedia(
        kind: ChatPreviewKind.video,
        thumbs: [
          ChatPreviewThumb(source: _thumbA, video: true),
          ChatPreviewThumb(source: _thumbB),
        ],
        label: 'Видео',
      );
      final restored = ChatPreviewMedia.decode(media.encode())!;
      expect(restored.kind, ChatPreviewKind.video);
      expect(restored.label, 'Видео');
      expect(restored.detail, isNull);
      expect(restored.thumbs.map((t) => t.source), [_thumbA, _thumbB]);
      expect(restored.thumbs.map((t) => t.video), [true, false]);
    });

    test('битое описание не роняет разбор', () {
      expect(ChatPreviewMedia.decode('{'), isNull);
      expect(ChatPreviewMedia.decode('{"k":"чтоэто"}'), isNull);
      expect(ChatPreviewMedia.decode(null), isNull);
    });
  });
}
