import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/share/share_labels.dart';
import 'package:komet/models/shared_payload.dart';

late Directory _dir;

String _makeFile(String name, {int bytes = 8}) {
  final file = File('${_dir.path}${Platform.pathSeparator}$name')
    ..writeAsBytesSync(List<int>.filled(bytes, 0x41));
  return file.path;
}

Map<String, Object?> _entry(String path, String mime, {int size = 8}) => {
  'path': path,
  'name': path.split(Platform.pathSeparator).last,
  'mime': mime,
  'size': size,
};

void main() {
  setUp(() {
    _dir = Directory.systemTemp.createTempSync('synthetic_share_test');
    addTearDown(() {
      if (_dir.existsSync()) _dir.deleteSync(recursive: true);
    });
  });

  group('SharedPayload.fromMap', () {
    test('classifies photos, videos and documents by mime', () {
      final payload = SharedPayload.fromMap({
        'files': [
          _entry(_makeFile('a.jpg'), 'image/jpeg'),
          _entry(_makeFile('b.mp4'), 'video/mp4'),
          _entry(_makeFile('c.pdf'), 'application/pdf'),
        ],
        'text': null,
      });

      expect(payload, isNotNull);
      expect(payload!.photos.map((f) => f.name), ['a.jpg']);
      expect(payload.videos.map((f) => f.name), ['b.mp4']);
      expect(payload.documents.map((f) => f.name), ['c.pdf']);
      expect(payload.dominantKind, SharedFileKind.file);
    });

    test('an svg is a document, not a photo', () {
      final payload = SharedPayload.fromMap({
        'files': [_entry(_makeFile('d.svg'), 'image/svg+xml')],
      });

      expect(payload!.files.single.kind, SharedFileKind.file);
    });

    test('drops entries whose file is gone', () {
      final payload = SharedPayload.fromMap({
        'files': [
          _entry(_makeFile('present.jpg'), 'image/jpeg'),
          _entry('${_dir.path}/missing.jpg', 'image/jpeg'),
        ],
      });

      expect(payload!.files.map((f) => f.name), ['present.jpg']);
    });

    test('a text-only share survives with no files', () {
      final payload = SharedPayload.fromMap({
        'files': const [],
        'text': '  https://komet.pw  ',
      });

      expect(payload!.isTextOnly, isTrue);
      expect(payload.text, 'https://komet.pw');
    });

    test('an empty share is rejected', () {
      expect(SharedPayload.fromMap({'files': const [], 'text': '   '}), isNull);
      expect(SharedPayload.fromMap(null), isNull);
      expect(SharedPayload.fromMap('nonsense'), isNull);
    });

    test('a missing mime falls back to a document', () {
      final payload = SharedPayload.fromMap({
        'files': [
          {'path': _makeFile('e.bin'), 'name': 'e.bin', 'size': 8},
        ],
      });

      expect(payload!.files.single.mime, 'application/octet-stream');
      expect(payload.files.single.kind, SharedFileKind.file);
    });
  });

  group('shareTitleFor', () {
    test('photos use Russian plural forms', () {
      expect(
        shareTitleFor(photos: 1, videos: 0, documents: 0),
        'Отправить фотографию',
      );
      expect(
        shareTitleFor(photos: 3, videos: 0, documents: 0),
        'Отправить 3 фотографии',
      );
      expect(
        shareTitleFor(photos: 5, videos: 0, documents: 0),
        'Отправить 5 фотографий',
      );
      expect(
        shareTitleFor(photos: 11, videos: 0, documents: 0),
        'Отправить 11 фотографий',
      );
    });

    test('videos stay uninflected', () {
      expect(
        shareTitleFor(photos: 0, videos: 1, documents: 0),
        'Отправить видео',
      );
      expect(
        shareTitleFor(photos: 0, videos: 2, documents: 0),
        'Отправить 2 видео',
      );
    });

    test('documents and mixed sets fall back to file wording', () {
      expect(
        shareTitleFor(photos: 0, videos: 0, documents: 1),
        'Отправить файл',
      );
      expect(
        shareTitleFor(photos: 0, videos: 0, documents: 4),
        'Отправить 4 файла',
      );
      expect(
        shareTitleFor(photos: 1, videos: 1, documents: 0),
        'Отправить 2 файла',
      );
    });

    test('a text share has no media wording', () {
      expect(
        shareTitleFor(photos: 0, videos: 0, documents: 0, textOnly: true),
        'Отправить сообщение',
      );
    });
  });

  group('shareSubtitleFor', () {
    test('names are listed up to two recipients', () {
      expect(shareSubtitleFor(const ['ЛУКА']), 'В чат ЛУКА');
      expect(shareSubtitleFor(const ['ЛУКА', 'Zarub']), 'В чат ЛУКА, Zarub');
    });

    test('three or more recipients collapse to a count', () {
      expect(shareSubtitleFor(const ['a', 'b', 'c']), 'В 3 чата');
      expect(shareSubtitleFor(List.filled(5, 'x')), 'В 5 чатов');
    });

    test('an empty selection asks for one', () {
      expect(shareSubtitleFor(const []), 'Выберите чат');
    });
  });
}
