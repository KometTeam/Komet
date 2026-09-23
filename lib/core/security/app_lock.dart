import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, Rect;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';

class AppLock {
  AppLock._();

  static final AppLock instance = AppLock._();

  static const int pinLength = 4;
  static const int maxAttempts = 5;
  static const Duration lockout = Duration(minutes: 5);
  static const List<int> idleOptions = [0, 1, 5, 10, 15, 30];
  static const Duration _idleCheck = Duration(seconds: 15);
  static const int _iterations = 20000;

  static const String _kPin = 'app_lock_pin';
  static const String _kEnabled = 'app_lock_enabled';
  static const String _kBiometric = 'app_lock_biometric';
  static const String _kIdle = 'app_lock_idle_minutes';
  static const String _kFailed = 'app_lock_failed';
  static const String _kBlockedUntil = 'app_lock_blocked_until';

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
      synchronizable: false,
    ),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  final ValueNotifier<bool> enabled = ValueNotifier(false);
  final ValueNotifier<bool> biometric = ValueNotifier(false);
  final ValueNotifier<int> idleMinutes = ValueNotifier(5);
  final ValueNotifier<bool> locked = ValueNotifier(false);
  final ValueNotifier<DateTime?> blockedUntil = ValueNotifier(null);

  final LocalAuthentication _auth = LocalAuthentication();
  int _failed = 0;
  int _externalDepth = 0;
  Rect? _origin;
  DateTime _lastInteraction = DateTime.now();
  Timer? _idleTimer;
  bool? _biometricAvailable;

  int get attemptsLeft => maxAttempts - _failed;

  Rect? takeOrigin() {
    final origin = _origin;
    _origin = null;
    return origin;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var on = prefs.getBool(_kEnabled) ?? false;
    if (on) {
      try {
        on = await _secure.read(key: _kPin) != null;
      } catch (e) {
        logger.w('AppLock: не удалось прочитать код: $e');
      }
    }
    enabled.value = on;
    biometric.value = on && (prefs.getBool(_kBiometric) ?? false);
    idleMinutes.value = prefs.getInt(_kIdle) ?? 5;
    _failed = prefs.getInt(_kFailed) ?? 0;
    final until = prefs.getInt(_kBlockedUntil);
    blockedUntil.value = until == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(until);
    _expireLockout();
    locked.value = on;
    _syncIdleTimer();
  }

  Future<void> setPin(String pin) async {
    await _secure.write(key: _kPin, value: await _hash(pin));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, true);
    enabled.value = true;
    await _resetAttempts();
    noteInteraction();
    _syncIdleTimer();
  }

  Future<void> disable() async {
    await _secure.delete(key: _kPin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
    await prefs.setBool(_kBiometric, false);
    enabled.value = false;
    biometric.value = false;
    locked.value = false;
    await _resetAttempts();
    _syncIdleTimer();
  }

  Future<void> setBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometric, value);
    biometric.value = value;
  }

  Future<void> setIdleMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kIdle, minutes);
    idleMinutes.value = minutes;
    noteInteraction();
    _syncIdleTimer();
  }

  Future<bool> checkPin(String pin) async {
    final stored = await _secure.read(key: _kPin);
    return stored != null && await _matches(pin, stored);
  }

  Future<bool> unlockWithPin(String pin) async {
    _expireLockout();
    if (blockedUntil.value != null) return false;
    if (await checkPin(pin)) {
      await _resetAttempts();
      unlock();
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

  void _expireLockout() {
    final until = blockedUntil.value;
    if (until != null && !DateTime.now().isBefore(until)) {
      blockedUntil.value = null;
      unawaited(
        SharedPreferences.getInstance().then((p) => p.remove(_kBlockedUntil)),
      );
    }
  }

  void refreshLockout() => _expireLockout();

  Future<void> _resetAttempts() async {
    _failed = 0;
    blockedUntil.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFailed);
    await prefs.remove(_kBlockedUntil);
  }

  void lock({Rect? origin}) {
    if (!enabled.value || locked.value) return;
    _origin = origin;
    locked.value = true;
  }

  void unlock() {
    locked.value = false;
    noteInteraction();
  }

  Future<T> external<T>(Future<T> Function() action) async {
    _externalDepth++;
    try {
      return await action();
    } finally {
      _externalDepth--;
    }
  }

  void onLifecycle(AppLifecycleState state) {
    final background =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (background && _externalDepth == 0) lock();
    if (state == AppLifecycleState.resumed) _expireLockout();
  }

  void noteInteraction() => _lastInteraction = DateTime.now();

  void _syncIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
    if (!enabled.value || idleMinutes.value <= 0) return;
    _idleTimer = Timer.periodic(_idleCheck, (_) {
      if (locked.value || _externalDepth > 0) return;
      final idle = DateTime.now().difference(_lastInteraction);
      if (idle >= Duration(minutes: idleMinutes.value)) lock();
    });
  }

  Future<bool> biometricAvailable() async {
    final known = _biometricAvailable;
    if (known != null) return known;
    try {
      final available =
          await _auth.isDeviceSupported() &&
          await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
      return _biometricAvailable = available;
    } catch (_) {
      return _biometricAvailable = false;
    }
  }

  Future<bool> authenticateBiometric(String reason) async {
    if (!await biometricAvailable()) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        sensitiveTransaction: false,
      );
    } catch (e) {
      logger.w('AppLock: биометрия не прошла: $e');
      return false;
    }
  }

  Future<bool> unlockWithBiometric(String reason) async {
    if (!biometric.value) return false;
    final ok = await authenticateBiometric(reason);
    if (ok) {
      await _resetAttempts();
      unlock();
    }
    return ok;
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
