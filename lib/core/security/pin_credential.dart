import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinCredential {
  PinCredential(String prefix)
    : _kPin = '${prefix}_pin',
      _kFailed = '${prefix}_failed',
      _kBlockedUntil = '${prefix}_blocked_until';

  static const int length = 4;
  static const int maxAttempts = 5;
  static const Duration lockout = Duration(minutes: 5);
  static const int _iterations = 20000;

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  final String _kPin;
  final String _kFailed;
  final String _kBlockedUntil;

  final ValueNotifier<DateTime?> blockedUntil = ValueNotifier(null);
  int _failed = 0;

  int get attemptsLeft => maxAttempts - _failed;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _failed = prefs.getInt(_kFailed) ?? 0;
    final until = prefs.getInt(_kBlockedUntil);
    blockedUntil.value = until == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(until);
    refreshLockout();
  }

  Future<bool> isStored() async => await _secure.read(key: _kPin) != null;

  Future<void> save(String pin) async {
    await _secure.write(key: _kPin, value: await _hash(pin));
    await resetAttempts();
  }

  Future<void> clear() async {
    await _secure.delete(key: _kPin);
    await resetAttempts();
  }

  Future<bool> matches(String pin) async {
    final stored = await _secure.read(key: _kPin);
    return stored != null && await _matches(pin, stored);
  }

  Future<bool> verify(String pin) async {
    refreshLockout();
    if (blockedUntil.value != null) return false;
    if (await matches(pin)) {
      await resetAttempts();
      return true;
    }
    _failed++;
    final prefs = await SharedPreferences.getInstance();
    if (_failed >= maxAttempts) {
      _failed = 0;
      final until = DateTime.now().add(lockout);
      blockedUntil.value = until;
      await prefs.setInt(_kBlockedUntil, until.millisecondsSinceEpoch);
    }
    await prefs.setInt(_kFailed, _failed);
    return false;
  }

  void refreshLockout() {
    final until = blockedUntil.value;
    if (until != null && !DateTime.now().isBefore(until)) {
      blockedUntil.value = null;
      unawaited(
        SharedPreferences.getInstance().then((p) => p.remove(_kBlockedUntil)),
      );
    }
  }

  Future<void> resetAttempts() async {
    _failed = 0;
    blockedUntil.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFailed);
    await prefs.remove(_kBlockedUntil);
  }

  static Future<String> _hash(String pin) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    final digest = await compute(_derive, (pin, salt));
    return 'v1:${base64Encode(salt)}:${base64Encode(digest)}';
  }

  static Future<bool> _matches(String pin, String stored) async {
    final parts = stored.split(':');
    if (parts.length != 3 || parts[0] != 'v1') return false;
    final salt = base64Decode(parts[1]);
    final expected = base64Decode(parts[2]);
    final actual = await compute(_derive, (pin, salt));
    if (actual.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  static Uint8List _derive((String, Uint8List) input) {
    final (pin, salt) = input;
    final hmac = Hmac(sha256, utf8.encode(pin));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = Uint8List.fromList(block);
    for (var i = 1; i < _iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return result;
  }
}
