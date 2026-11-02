import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, Rect;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'pin_credential.dart';

class AppLock {
  AppLock._();

  static final AppLock instance = AppLock._();

  static const List<int> idleOptions = [0, 1, 5, 10, 15, 30];
  static const Duration _idleCheck = Duration(seconds: 15);

  static const String _kEnabled = 'app_lock_enabled';
  static const String _kBiometric = 'app_lock_biometric';
  static const String _kIdle = 'app_lock_idle_minutes';

  final PinCredential credential = PinCredential('app_lock');
  final ValueNotifier<bool> enabled = ValueNotifier(false);
  final ValueNotifier<bool> biometric = ValueNotifier(false);
  final ValueNotifier<int> idleMinutes = ValueNotifier(5);
  final ValueNotifier<bool> locked = ValueNotifier(false);

  final LocalAuthentication _auth = LocalAuthentication();
  int _externalDepth = 0;
  Rect? _origin;
  DateTime _lastInteraction = DateTime.now();
  Timer? _idleTimer;
  bool? _biometricAvailable;

  ValueListenable<DateTime?> get blockedUntil => credential.blockedUntil;

  int get attemptsLeft => credential.attemptsLeft;

  bool get inExternal => _externalDepth > 0;

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
        on = await credential.isStored();
      } catch (e) {
        logger.w('AppLock: не удалось прочитать код: $e');
      }
    }
    enabled.value = on;
    biometric.value = on && (prefs.getBool(_kBiometric) ?? false);
    idleMinutes.value = prefs.getInt(_kIdle) ?? 5;
    await credential.load();
    locked.value = on;
    _syncIdleTimer();
  }

  Future<void> setPin(String pin) async {
    await credential.save(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, true);
    enabled.value = true;
    noteInteraction();
    _syncIdleTimer();
  }

  Future<void> disable() async {
    await credential.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
    await prefs.setBool(_kBiometric, false);
    enabled.value = false;
    biometric.value = false;
    locked.value = false;
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

  Future<bool> checkPin(String pin) => credential.matches(pin);

  Future<bool> unlockWithPin(String pin) async {
    final ok = await credential.verify(pin);
    if (ok) unlock();
    return ok;
  }

  void refreshLockout() => credential.refreshLockout();

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
    if (state == AppLifecycleState.resumed) refreshLockout();
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

  Future<List<BiometricType>> biometricTypes() async {
    if (!await biometricAvailable()) return const [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> authenticateBiometric(String reason) async {
    if (!await biometricAvailable()) return false;
    try {
      return await _auth
          .authenticate(
            localizedReason: reason,
            biometricOnly: true,
            sensitiveTransaction: false,
          )
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
    } catch (e) {
      logger.w('AppLock: биометрия не прошла: $e');
      return false;
    }
  }

  Future<bool> unlockWithBiometric(String reason) async {
    if (!biometric.value) return false;
    final ok = await authenticateBiometric(reason);
    if (ok) {
      await credential.resetAttempts();
      unlock();
    }
    return ok;
  }
}
