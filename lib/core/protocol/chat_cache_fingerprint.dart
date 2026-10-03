import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// #***! отпечаток родной сборки, хэши подписи dex и so
class ChatCacheFingerprint {
  static const String defaultArch = 'arm64-v8a';

  static final Uint8List _signatureDigest = _hex(
    '1684414033eb263e2c615f8b7df5ed8793850a07656304997fbf07e9e21e1e93',
  );
  static final Uint8List _dexDigest = _hex(
    '9affa687874d88ea80b298949f826bcf8c1bba36f24d48c44b8f54cdbf01c96f',
  );
  // #***! отпечаток прошлой версии (26.23.2) — уходит в pre-login запросах без
  // токена, когда в хэндшейке мы представляемся preLoginAppVersion. Тогда была
  // одна so на все архитектуры, поэтому arch тут не учитываем.
  static final Uint8List _preLoginDexDigest = _hex(
    '38cff46f392dc1734c308be011c2f0d8da152a390b41063dbb2c913e3032f4b3',
  );
  static final Uint8List _preLoginSoDigest = _hex(
    '634ecc42b246784d975f180b4fecf903df235cdf0476da47163a85630eb1a6a8',
  );
  // #***! so своя на каждую архитектуру, берём ту что уехала в хэндшейк
  static final Map<String, Uint8List> _soDigests = {
    'arm64-v8a': _hex(
      '38e2e5de3d4a9010ea1053eb28573593683c5b2bb16b09914a8822476c8aab8c',
    ),
    'armeabi-v7a': _hex(
      'f60cb2576885e0af5350c98fe88355a2f26008a372c998c193b6222f717e274f',
    ),
    'x86': _hex(
      '80bd04964e7d0492740113047ff20ebdf88ba6e6eb48d8765cbd5fe678283065',
    ),
    'x86_64': _hex(
      '96173e7c2d9449c1ab4474265b410f37ce45f560b0974460a75c7c6000ca22fd',
    ),
  };

  // #***! три sha256 подряд, 96 байт серверу
  static Uint8List compute(
    int callsSeed,
    String deviceId, {
    String arch = defaultArch,
    bool preLogin = false,
  }) {
    final seed = _int64BigEndian(callsSeed);
    final device = Uint8List.fromList(utf8.encode(deviceId));
    final dexDigest = preLogin ? _preLoginDexDigest : _dexDigest;
    final soDigest = preLogin
        ? _preLoginSoDigest
        : (_soDigests[arch] ?? _soDigests[defaultArch]!);
    final result = BytesBuilder();
    result.add(_sha256(_signatureDigest, seed, device));
    result.add(_sha256(dexDigest, seed, device));
    result.add(_sha256(soDigest, seed, device));
    return result.toBytes();
  }

  static List<int> _sha256(Uint8List a, Uint8List b, Uint8List c) {
    final builder = BytesBuilder()
      ..add(a)
      ..add(b)
      ..add(c);
    return sha256.convert(builder.toBytes()).bytes;
  }

  // #***! seed звонков 8 байт big-endian
  static Uint8List _int64BigEndian(int value) {
    final data = ByteData(8)..setInt64(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  // #***! хэши строкой, разворачиваем в байты
  static Uint8List _hex(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
