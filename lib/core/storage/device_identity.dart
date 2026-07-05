import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/ids.dart';

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
    final generated = uuidV4();
    await prefs.setString(_instanceIdKey, generated);
    return generated;
  }

  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = randomHex(8);
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

}
