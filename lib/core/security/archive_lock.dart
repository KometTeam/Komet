import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'pin_credential.dart';

class ArchiveLock {
  ArchiveLock._({DateTime Function()? now}) : _now = now ?? DateTime.now;

  @visibleForTesting
  ArchiveLock.withClock(DateTime Function() now) : this._(now: now);

  static final ArchiveLock instance = ArchiveLock._();

  static const List<int> relockOptions = [0, 1, 5, 15, 30, 60];
  static const int _defaultRelockMinutes = 5;

  static const String _kEnabled = 'archive_lock_enabled';
  static const String _kRelock = 'archive_lock_relock_minutes';

  final PinCredential credential = PinCredential('archive_lock');
  final ValueNotifier<bool> enabled = ValueNotifier(false);
  final ValueNotifier<int> relockMinutes = ValueNotifier(_defaultRelockMinutes);
  final ValueNotifier<bool> locked = ValueNotifier(false);

  final DateTime Function() _now;
  int _holders = 0;
  DateTime? _idleSince;
  Timer? _relockTimer;

  Duration get _grace => Duration(minutes: relockMinutes.value);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    var on = prefs.getBool(_kEnabled) ?? false;
    if (on) {
      try {
        on = await credential.isStored();
      } catch (e) {
        logger.w('ArchiveLock: не удалось прочитать пароль: $e');
      }
    }
    enabled.value = on;
    relockMinutes.value = prefs.getInt(_kRelock) ?? _defaultRelockMinutes;
    await credential.load();
    _stopIdle();
    locked.value = on;
  }

  Future<void> setPin(String pin) async {
    await credential.save(pin);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, true);
    enabled.value = true;
    if (_holders == 0) _lockNow();
  }

  Future<void> disable() async {
    await credential.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
    enabled.value = false;
    _stopIdle();
    locked.value = false;
  }

  Future<void> setRelockMinutes(int minutes) async {
    relockMinutes.value = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRelock, minutes);
    _scheduleRelock();
  }

  Future<bool> unlock(String pin) async {
    final ok = await credential.verify(pin);
    if (!ok) return false;
    locked.value = false;
    if (_holders == 0) _startIdle();
    return true;
  }

  void expireIfDue() => _relockIfExpired();

  void retain() {
    _holders++;
    _stopIdle();
  }

  void release() {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) _startIdle();
  }

  void onLifecycle(AppLifecycleState state, {required bool external}) {
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        if (_holders > 0 && !external) _startIdle();
      case AppLifecycleState.resumed:
        credential.refreshLockout();
        _relockIfExpired();
        if (_holders > 0) _stopIdle();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  void _startIdle() {
    if (!enabled.value || locked.value) return;
    _idleSince ??= _now();
    _scheduleRelock();
  }

  void _stopIdle() {
    _idleSince = null;
    _relockTimer?.cancel();
    _relockTimer = null;
  }

  void _scheduleRelock() {
    _relockTimer?.cancel();
    _relockTimer = null;
    final since = _idleSince;
    if (since == null) return;
    final left = since.add(_grace).difference(_now());
    if (left <= Duration.zero) {
      _lockNow();
      return;
    }
    _relockTimer = Timer(left, _relockIfExpired);
  }

  void _relockIfExpired() {
    final since = _idleSince;
    if (since == null) return;
    if (_now().isBefore(since.add(_grace))) {
      _scheduleRelock();
      return;
    }
    _lockNow();
  }

  void _lockNow() {
    _stopIdle();
    if (enabled.value) locked.value = true;
  }
}
