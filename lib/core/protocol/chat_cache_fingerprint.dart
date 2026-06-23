import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class ChatCacheFingerprint {
  static final Uint8List _signatureDigest = _hex(
    '2917772b58095daca2a99a099f85ee0214c9a9d72bea2007cbaf5b45f29c8d18',
  );
  static final Uint8List _soDigest = _hex(
    'ec3f447f41e161b0dec7ce6d5ce9d52428895da54e0d9d036d93913b45c7a3c1',
  );
  static final Uint8List _dexDigest = _hex(
    'd590910db09464e19553e22c184c135ace8c6cb6d4407920f949d561724fb8fe',
  );

  static Uint8List compute(int callsSeed, String deviceId) {
    final seed = _int64BigEndian(callsSeed);
    final device = Uint8List.fromList(utf8.encode(deviceId));
    final result = BytesBuilder();
    result.add(_sha256(_signatureDigest, seed, device));
    result.add(_sha256(_soDigest, seed, device));
    result.add(_sha256(_dexDigest, seed, device));
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
