import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:komet/core/utils/image_format.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

Uint8List _bytes(List<int> head, {int pad = 32}) =>
    Uint8List.fromList([...head, ...List.filled(pad, 0)]);

Uint8List _riff(String fourcc, {List<int> chunk = const []}) => _bytes([
  ...'RIFF'.codeUnits,
  0,
  0,
  0,
  0,
  ...'WEBP'.codeUnits,
  ...fourcc.codeUnits,
  0,
  0,
  0,
  0,
  ...chunk,
]);

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String temporary;

  _FakePathProvider(this.temporary);

  @override
  Future<String?> getTemporaryPath() async => temporary;
}

img.Image _swatch({required bool opaque}) {
  final image = img.Image(width: 16, height: 16, numChannels: opaque ? 3 : 4);
  img.fill(
    image,
    color: opaque
        ? img.ColorRgb8(12, 180, 64)
        : img.ColorRgba8(12, 180, 64, 128),
  );
  return image;
}

void main() {
  group('sniffImageFormat', () {
    test('reads the signature, not the name', () {
      expect(
        sniffImageFormat(_bytes([0xFF, 0xD8, 0xFF, 0xE0])),
        ImageByteFormat.jpeg,
      );
      expect(
        sniffImageFormat(
          _bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        ),
        ImageByteFormat.png,
      );
      expect(
        sniffImageFormat(_bytes('GIF89a'.codeUnits)),
        ImageByteFormat.gif,
      );
      expect(sniffImageFormat(_riff('VP8 ')), ImageByteFormat.webp);
      expect(sniffImageFormat(_bytes('BM'.codeUnits)), ImageByteFormat.bmp);
      expect(
        sniffImageFormat(_bytes([0, 0, 0, 0x18, ...'ftypheic'.codeUnits])),
        ImageByteFormat.heic,
      );
    });

    test('unknown bytes stay unknown', () {
      expect(sniffImageFormat(_bytes([1, 2, 3, 4])), ImageByteFormat.unknown);
      expect(sniffImageFormat(Uint8List(0)), ImageByteFormat.unknown);
    });

    test('RIFF without the WEBP tag is not webp', () {
      final wave = _bytes([
        ...'RIFF'.codeUnits,
        0,
        0,
        0,
        0,
        ...'WAVE'.codeUnits,
      ]);
      expect(sniffImageFormat(wave), ImageByteFormat.unknown);
    });
  });

  group('isAnimatedWebp', () {
    test('detects the ANIM flag in VP8X', () {
      expect(isAnimatedWebp(_riff('VP8X', chunk: [0x02])), isTrue);
      expect(isAnimatedWebp(_riff('VP8X', chunk: [0x10])), isFalse);
      expect(isAnimatedWebp(_riff('VP8 ')), isFalse);
      expect(isAnimatedWebp(_bytes([0xFF, 0xD8, 0xFF])), isFalse);
    });
  });

  group('withImageExtension', () {
    test('replaces whatever extension the caller guessed', () {
      expect(withImageExtension('IMG_17.jpg', '.webp'), 'IMG_17.webp');
      expect(withImageExtension('IMG_17.jpeg', '.jpg'), 'IMG_17.jpg');
      expect(withImageExtension('IMG_17', '.png'), 'IMG_17.png');
      expect(withImageExtension('my.photo.jpg', '.png'), 'my.photo.png');
    });

    test('keeps the name when the format is unknown', () {
      expect(withImageExtension('IMG_17.jpg', ''), 'IMG_17.jpg');
    });
  });

  group('extensionForImageFormat', () {
    test('jpeg keeps the short extension', () {
      expect(extensionForImageFormat(ImageByteFormat.jpeg), '.jpg');
      expect(extensionForImageFormat(ImageByteFormat.webp), '.webp');
      expect(extensionForImageFormat(ImageByteFormat.unknown), isNull);
    });
  });

  group('prepareImageForSave', () {
    late Directory workspace;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      workspace = Directory.systemTemp.createTempSync('komet_image_format');
      PathProviderPlatform.instance = _FakePathProvider(workspace.path);
    });

    tearDown(() => workspace.deleteSync(recursive: true));

    File write(String name, List<int> bytes) =>
        File('${workspace.path}/$name')..writeAsBytesSync(bytes);

    test('opaque webp is saved as a real jpeg', () async {
      final source = write(
        'photo.webp',
        img.encodeWebP(_swatch(opaque: true)),
      );

      final ready = await prepareImageForSave(source);

      expect(ready, isNotNull);
      expect(ready!.extension, '.jpg');
      expect(ready.temporary, isTrue);
      expect(
        sniffImageFormat(await ready.file.readAsBytes()),
        ImageByteFormat.jpeg,
      );
      await ready.discard();
      expect(ready.file.existsSync(), isFalse);
    });

    test('transparent webp keeps its pixels in png', () async {
      final source = write(
        'sticker.webp',
        img.encodeWebP(_swatch(opaque: false)),
      );

      final ready = await prepareImageForSave(source);

      expect(ready!.extension, '.png');
      expect(
        sniffImageFormat(await ready.file.readAsBytes()),
        ImageByteFormat.png,
      );
      await ready.discard();
    });

    test('jpeg named .webp is reported as jpeg', () async {
      final source = write(
        'wrong.webp',
        img.encodeJpg(_swatch(opaque: true)),
      );

      final ready = await prepareImageForSave(source);

      expect(ready!.extension, '.jpg');
      expect(ready.temporary, isFalse);
      expect(ready.file.path, source.path);
    });

    test('png is passed through untouched', () async {
      final source = write('shot.png', img.encodePng(_swatch(opaque: true)));

      final ready = await prepareImageForSave(source);

      expect(ready!.extension, '.png');
      expect(ready.temporary, isFalse);
      expect(ready.file.path, source.path);
    });

    test('missing file yields nothing to save', () async {
      expect(
        await prepareImageForSave(File('${workspace.path}/gone.webp')),
        isNull,
      );
    });
  });
}
