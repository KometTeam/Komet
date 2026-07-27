import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet_crypto/komet_crypto.dart' as kc;

const _libPath = 'build/linux/x64/debug/bundle/lib/libkomet_crypto.so';

void main() {
  if (!File(_libPath).existsSync()) {
    // ignore: avoid_print
    print('skipping: run `flutter build linux --debug` first');
    return;
  }

  setUpAll(() async {
    await kc.RustLib.init(
      externalLibrary: ExternalLibrary.open(_libPath),
    );
  });

  test('round-trips through the native bridge', () async {
    final key = await kc.deriveKey(password: 'общий ключ');
    expect(key.length, 32);

    const plaintext = 'встречаемся в 19:00 у метро';
    final encrypted = await kc.encryptMessage(plaintext: plaintext, key: key);

    expect(encrypted, isNot(contains(RegExp(r'[a-zA-Z0-9]'))));
    expect(encrypted, contains(' '));
    expect(await kc.decryptMessage(text: encrypted, key: key), plaintext);
  });

  test('derives the same key from the same password', () async {
    final a = await kc.deriveKey(password: 'один ключ');
    final b = await kc.deriveKey(password: 'один ключ');
    expect(a, b);
  });

  test('rejects a wrong key', () async {
    final key = await kc.deriveKey(password: 'правильный');
    final wrong = await kc.deriveKey(password: 'неправильный');
    final encrypted = await kc.encryptMessage(plaintext: 'секрет', key: key);

    expect(
      () => kc.decryptMessage(text: encrypted, key: wrong),
      throwsA(predicate((e) => e.toString().contains('wrong_key'))),
    );
  });

  test('reports plain text as not encrypted', () async {
    final key = await kc.deriveKey(password: 'ключ');
    expect(await kc.looksEncrypted(text: 'привет как дела'), isFalse);
    expect(
      () => kc.decryptMessage(text: 'привет как дела', key: key),
      throwsA(predicate((e) => e.toString().contains('not_encrypted'))),
    );
  });

  group('images', _imageTests);

  test('survives whitespace mangling', () async {
    final key = await kc.deriveKey(password: 'ключ');
    final encrypted = await kc.encryptMessage(
      plaintext: 'пробелы декоративные',
      key: key,
    );
    final mangled = '  ${encrypted.replaceAll(' ', '   ')}\n';
    expect(
      await kc.decryptMessage(text: mangled, key: key),
      'пробелы декоративные',
    );
  });
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

void _imageTests() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('komet_img'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File writePlain() =>
      File('${tmp.path}/plain.png')..writeAsBytesSync(_tinyPng);

  test('round-trips a photo through the native bridge', () async {
    final key = await kc.deriveKey(password: 'фото-ключ');
    final plain = writePlain();
    final enc = '${tmp.path}/enc.png';
    final out = '${tmp.path}/out.png';

    await kc.encryptImageFile(
      sourcePath: plain.path,
      destPath: enc,
      key: key,
    );

    final encBytes = File(enc).readAsBytesSync();
    expect(encBytes.sublist(1, 4), 'PNG'.codeUnits);
    expect(encBytes, isNot(_tinyPng));
    expect(await kc.looksEncryptedImageFile(path: enc), isTrue);
    expect(await kc.looksEncryptedImageFile(path: plain.path), isFalse);

    await kc.decryptImageFile(sourcePath: enc, destPath: out, key: key);
    expect(File(out).readAsBytesSync(), _tinyPng);
  });

  test('rejects a photo decrypted with a wrong key', () async {
    final key = await kc.deriveKey(password: 'правильный');
    final wrong = await kc.deriveKey(password: 'неправильный');
    final enc = '${tmp.path}/enc.png';

    await kc.encryptImageFile(
      sourcePath: writePlain().path,
      destPath: enc,
      key: key,
    );
    expect(
      () => kc.decryptImageFile(
        sourcePath: enc,
        destPath: '${tmp.path}/out.png',
        key: wrong,
      ),
      throwsA(predicate((e) => e.toString().contains('wrong_key'))),
    );
  });
}
