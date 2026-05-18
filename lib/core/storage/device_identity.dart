import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

abstract class DeviceIdentity {
  static const String _instanceIdKey = 'mt_instance_id';
  static const String _deviceIdKey = 'device_id_local';

  static final Random _rng = Random.secure();
  static int? _clientSessionId;

  static int get clientSessionId =>
      _clientSessionId ??= _rng.nextInt(0x7FFFFFFF) + 1;

  static Future<String> instanceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_instanceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _uuidV4();
    await prefs.setString(_instanceIdKey, generated);
    return generated;
  }

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _hex(8);
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  static String _hex(int bytes) {
    final sb = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      sb.write(_rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static String _uuidV4() {
    final b = List<int>.generate(16, (_) => _rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
        '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
  }
}
