import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class ChatCacheFingerprint {
  static final Uint8List _signatureDigest = _hex(
    '1684414033eb263e2c615f8b7df5ed8793850a07656304997fbf07e9e21e1e93',
  );
  static final Uint8List _soDigest = _hex(
    'c77b89270f44bd26c218a946c18911f2b156312693ea00b419d169b71c1ed111',
  );
  static final Uint8List _dexDigest = _hex(
    '490a2746c7ebbff050353c575a186ca65bc708f9b6e0c1329b59a3bfab6c3924',
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
