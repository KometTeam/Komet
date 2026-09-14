import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/crypto/noise_png.dart';
import 'package:komet_crypto/komet_crypto.dart';

String get _libPath {
  final name = Platform.isMacOS
      ? 'libkomet_crypto.dylib'
      : Platform.isWindows
      ? 'komet_crypto.dll'
      : 'libkomet_crypto.so';
  return 'native/crypto-core/build/$name';
}

const List<int> _tinyPng = [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 4, 0,
  0, 0, 4, 8, 2, 0, 0, 0, 38, 147, 9, 41, 0, 0, 0, 63, 73, 68, 65, 84, 120,
  156, 1, 52, 0, 203, 255, 0, 0, 40, 80, 120, 160, 200, 240, 24, 64, 104, 144,
  184, 0, 17, 57, 97, 137, 177, 217, 1, 41, 81, 121, 161, 201, 0, 34, 74, 114,
  154, 194, 234, 18, 58, 98, 138, 178, 218, 0, 51, 91, 131, 171, 211, 251, 35,
  75, 115, 155, 195, 235, 36, 246, 23, 9, 123, 15, 58, 142, 0, 0, 0, 0, 73, 69,
  78, 68, 174, 66, 96, 130,
];

Uint8List _pattern(int length) =>
    Uint8List.fromList(List.generate(length, (i) => (i * 13 + 5) & 0xff));

void main() {
  group('noise png', () {
    test('wraps a blob into an RGB8 PNG and unwraps it', () {
      final blob = _pattern(73);
      final png = wrapNoisePng(blob, random: Random(1))!;
      expect(png.sublist(1, 4), 'PNG'.codeUnits);
      final raw = unwrapNoisePng(png)!;
      expect(raw.length, greaterThanOrEqualTo(blob.length));
      expect(raw.sublist(0, blob.length), blob);
    });

    test('rejects other images', () {
      expect(unwrapNoisePng(Uint8List.fromList(_tinyPng)), isNotNull);
      expect(unwrapNoisePng(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('a zip bomb is capped at what the header describes', () {
      final bomb = BytesBuilder();
      bomb.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
      _chunk(bomb, 'IHDR', [..._be32(1), ..._be32(1), 8, 2, 0, 0, 0]);
      _chunk(bomb, 'IDAT', ZLibEncoder().convert(Uint8List(8 << 20)));
      _chunk(bomb, 'IEND', const []);
      final bytes = bomb.toBytes();
      expect(bytes.length, lessThan(100 * 1024));
      final raw = unwrapNoisePng(bytes);
      expect(raw, isNotNull);
      expect(raw!.length, 3, reason: 'ровно один RGB-пиксель, не восемь мегабайт');
    });

    test('a header promising more than the data holds is rejected', () {
      final short = BytesBuilder();
      short.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
      _chunk(short, 'IHDR', [..._be32(64), ..._be32(64), 8, 2, 0, 0, 0]);
      _chunk(short, 'IDAT', ZLibEncoder().convert(Uint8List(10)));
      _chunk(short, 'IEND', const []);
      expect(unwrapNoisePng(short.toBytes()), isNull);
    });

    test('unfilters every PNG filter type', () {
      const width = 5;
      const height = 4;
      final pixels = _pattern(width * height * 3);
      for (var filter = 0; filter <= 4; filter++) {
        final png = _encodeWithFilter(pixels, width, height, filter);
        expect(unwrapNoisePng(png), pixels, reason: 'filter $filter');
      }
    });
  });

  if (!File(_libPath).existsSync()) {
    // ignore: avoid_print
    print('skipping native tests: run `make shared` in native/crypto-core');
    return;
  }

  setUpAll(() {
    KometCrypto.libraryPath = File(_libPath).absolute.path;
  });

  test('round-trips through the native core', () {
    final key = KometCrypto.deriveKey('общий ключ');
    expect(key.length, 32);
    const plaintext = 'встречаемся в 19:00 у метро';
    final encrypted = KometCrypto.encryptMessage(plaintext, key);
    expect(encrypted, isNot(contains(RegExp(r'[a-zA-Z0-9]'))));
    expect(encrypted, contains(' '));
    expect(KometCrypto.decryptMessage(encrypted, key), plaintext);
    expect(KometCrypto.deriveKey('общий ключ'), key);
  });

  test('rejects a wrong key and plain text', () {
    final key = KometCrypto.deriveKey('правильный');
    final wrong = KometCrypto.deriveKey('неправильный');
    final encrypted = KometCrypto.encryptMessage('секрет', key);
    expect(
      () => KometCrypto.decryptMessage(encrypted, wrong),
      throwsA(
        isA<KometCryptoException>().having(
          (e) => e.status,
          'status',
          CryptoStatus.wrongKey,
        ),
      ),
    );
    expect(KometCrypto.looksEncryptedMessage('привет как дела'), isFalse);
    final mangled = '  ${encrypted.replaceAll(' ', '   ')}\n';
    expect(KometCrypto.decryptMessage(mangled, key), 'секрет');
  });

  test('round-trips a photo through the noise wrapper', () {
    final key = KometCrypto.deriveKey('фото-ключ');
    final plain = Uint8List.fromList(_tinyPng);
    final blob = KometCrypto.encryptImageBlob(plain, key);
    final noise = wrapNoisePng(blob)!;
    expect(noise, isNot(plain));
    final raw = unwrapNoisePng(noise)!;
    expect(KometCrypto.looksEncryptedImageBlob(raw), isTrue);
    expect(KometCrypto.looksEncryptedImageBlob(plain), isFalse);
    expect(KometCrypto.decryptImageBlob(raw, key), plain);
    final wrong = KometCrypto.deriveKey('неправильный');
    expect(
      () => KometCrypto.decryptImageBlob(raw, wrong),
      throwsA(isA<KometCryptoException>()),
    );
  });
}

Uint8List _encodeWithFilter(Uint8List pixels, int width, int height, int filter) {
  final stride = width * 3;
  final raw = BytesBuilder();
  final previous = Uint8List(stride);
  for (var row = 0; row < height; row++) {
    final current = pixels.sublist(row * stride, (row + 1) * stride);
    final filtered = Uint8List(stride);
    for (var i = 0; i < stride; i++) {
      final left = i >= 3 ? current[i - 3] : 0;
      final up = previous[i];
      final upLeft = i >= 3 ? previous[i - 3] : 0;
      final predictor = switch (filter) {
        0 => 0,
        1 => left,
        2 => up,
        3 => (left + up) >> 1,
        _ => _paeth(left, up, upLeft),
      };
      filtered[i] = (current[i] - predictor) & 0xff;
    }
    raw.addByte(filter);
    raw.add(filtered);
    previous.setAll(0, current);
  }
  final out = BytesBuilder();
  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  _chunk(out, 'IHDR', [..._be32(width), ..._be32(height), 8, 2, 0, 0, 0]);
  _chunk(out, 'IDAT', ZLibEncoder().convert(raw.toBytes()));
  _chunk(out, 'IEND', const []);
  return out.toBytes();
}

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

List<int> _be32(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

void _chunk(BytesBuilder out, String type, List<int> data) {
  out.add(_be32(data.length));
  out.add(type.codeUnits);
  out.add(data);
  out.add(_be32(_crc([...type.codeUnits, ...data])));
}

int _crc(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
