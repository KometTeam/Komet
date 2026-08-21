import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Канал к нативному сервису FKM (foreground komet messaging).
class FkmBridge {
  FkmBridge._();
  static final FkmBridge instance = FkmBridge._();

  static const _method = MethodChannel('ru.komet.app/fkm');

  VoidCallback? _onDisabled;
  bool _handlerSet = false;

  bool get isSupported {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Вызывается, когда пользователь выключил FKM кнопкой в самом уведомлении.
  void setDisabledCallback(VoidCallback callback) {
    _onDisabled = callback;
    if (_handlerSet || !isSupported) return;
    _handlerSet = true;
    _method.setMethodCallHandler((call) async {
      if (call.method == 'disabled') _onDisabled?.call();
      return null;
    });
  }

  Future<bool> isEnabled() async {
    if (!isSupported) return false;
    return await _invoke<bool>('isEnabled') ?? false;
  }

  Future<void> setEnabled(bool enabled) =>
      _invoke<void>('setEnabled', {'enabled': enabled});

  Future<void> setConnected(bool connected) =>
      _invoke<void>('setConnected', {'connected': connected});

  Future<void> showMessage(Map<String, String> data) =>
      _invoke<void>('showMessage', {'data': data});

  Future<void> showCall(Map<String, String> data) =>
      _invoke<void>('showCall', {'data': data});

  Future<bool> hasNotificationPermission() async {
    if (!isSupported) return false;
    return await _invoke<bool>('hasNotificationPermission') ?? false;
  }

  Future<bool> requestNotificationPermission() async {
    if (!isSupported) return false;
    return await _invoke<bool>('requestNotificationPermission') ?? false;
  }

  Future<bool> isIgnoringBatteryOptimizations() async {
    if (!isSupported) return true;
    return await _invoke<bool>('isIgnoringBatteryOptimizations') ?? true;
  }

  Future<void> requestIgnoreBatteryOptimizations() =>
      _invoke<void>('requestIgnoreBatteryOptimizations');

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    if (!isSupported) return null;
    try {
      return await _method.invokeMethod<T>(method, args);
    } catch (e) {
      logger.w('FkmBridge.$method: $e');
      return null;
    }
  }
}
