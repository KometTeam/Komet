import 'dart:convert';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet_crypto/komet_crypto.dart' as kc;

const _libPath = 'build/linux/x64/debug/bundle/lib/libkomet_crypto.so';

const _phoneDigits = '79999999999';
const _code = '123456';
const _payload =
    'ймафлглэиыягптэитэлккдуяюмфлючшомуяяжцфпоемшшыедшпфщяовшцхиеьпощехемщыдтукщяъцнюшспрчщцхыхцьцбикъыдожеыфыбъадйапххлтчеьлацзнбъыкрфпкскщъжхпеяеоипкврлхсиауглшшэчъэинвмзнтккгэюэтшзатысьтйнкюрьацишщщэщмычнбъюцвдюжчискэббъчяишбдстъуцпеюжмышбътйьоойапакфиглхшьоожъбфцспсцлфхги';

void main() {
  if (!File(_libPath).existsSync()) {
    // ignore: avoid_print
    print('skipping: run `flutter build linux --debug` first');
    return;
  }

  setUpAll(() async {
    await kc.RustLib.init(externalLibrary: ExternalLibrary.open(_libPath));
  });

  test('review payload unlocks with the phone and the code', () async {
    final key = await kc.deriveKey(password: '$_phoneDigits:$_code');
    final decoded =
        jsonDecode(await kc.decryptMessage(text: _payload, key: key))
            as Map<String, dynamic>;

    expect(decoded['token'], 'synthetic-review-token');
    expect(decoded['spoof']['device_id'], 'synthetic-device-id');
  });

  test('review payload stays locked with a wrong code', () async {
    final key = await kc.deriveKey(password: '$_phoneDigits:000000');

    expect(
      () => kc.decryptMessage(text: _payload, key: key),
      throwsA(predicate((e) => e.toString().contains('wrong_key'))),
    );
  });
}
