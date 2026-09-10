import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet_crypto/komet_crypto.dart';

const _libraryCandidates = [
  'native/crypto-core/build/libkomet_crypto.dylib',
  'native/crypto-core/build/libkomet_crypto.so',
  'build/linux/x64/debug/bundle/lib/libkomet_crypto.so',
];

const _phoneDigits = '79999999999';
const _code = '123456';
const _payload =
    'ймафлглэиыягптэитэлккдуяюмфлючшомуяяжцфпоемшшыедшпфщяовшцхиеьпощехемщыдтукщяъцнюшспрчщцхыхцьцбикъыдожеыфыбъадйапххлтчеьлацзнбъыкрфпкскщъжхпеяеоипкврлхсиауглшшэчъэинвмзнтккгэюэтшзатысьтйнкюрьацишщщэщмычнбъюцвдюжчискэббъчяишбдстъуцпеюжмышбътйьоойапакфиглхшьоожъбфцспсцлфхги';

String? _library() {
  for (final path in _libraryCandidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

void main() {
  final library = _library();
  if (library == null) {
    // ignore: avoid_print
    print('skipping: run `make shared` in native/crypto-core first');
    return;
  }
  KometCrypto.libraryPath = library;

  test('review payload unlocks with the phone and the code', () {
    final key = KometCrypto.deriveKey('$_phoneDigits:$_code');
    final decoded =
        jsonDecode(KometCrypto.decryptMessage(_payload, key))
            as Map<String, dynamic>;

    expect(decoded['token'], 'synthetic-review-token');
    expect(decoded['spoof']['device_id'], 'synthetic-device-id');
  });

  test('review payload stays locked with a wrong code', () {
    final key = KometCrypto.deriveKey('$_phoneDigits:000000');

    expect(
      () => KometCrypto.decryptMessage(_payload, key),
      throwsA(
        isA<KometCryptoException>().having(
          (e) => e.status,
          'status',
          CryptoStatus.wrongKey,
        ),
      ),
    );
  });
}
