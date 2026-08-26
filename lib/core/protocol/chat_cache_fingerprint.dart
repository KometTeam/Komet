import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class ChatCacheFingerprint {
  static final Uint8List _signatureDigest = _hex(
    '1684414033eb263e2c615f8b7df5ed8793850a07656304997fbf07e9e21e1e93',
  );
  static final Uint8List _soDigest = _hex(
    '634ecc42b246784d975f180b4fecf903df235cdf0476da47163a85630eb1a6a8',
  );
  static final Uint8List _dexDigest = _hex(
    '38cff46f392dc1734c308be011c2f0d8da152a390b41063dbb2c913e3032f4b3',
  );

  static Uint8List compute(int callsSeed, String deviceId) {
    final seed = _int64BigEndian(callsSeed);
    final device = Uint8List.fromList(utf8.encode(deviceId));
    final result = BytesBuilder();
    result.add(_sha256(_signatureDigest, seed, device));
    result.add(_sha256(_dexDigest, seed, device));
    result.add(_sha256(_soDigest, seed, device));
    return result.toBytes();
  }

  static List<int> _sha256(Uint8List a, Uint8List b, Uint8List c) {
    final builder = BytesBuilder()
      ..add(a)
      ..add(b)
      ..add(c);
    return sha256.convert(builder.toBytes()).bytes;
  }

  static Uint8List _int64BigEndian(int value) {
    final data = ByteData(8)..setInt64(0, value, Endian.big);
    return data.buffer.asUint8List();
  }

  static Uint8List _hex(String hex) {
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
