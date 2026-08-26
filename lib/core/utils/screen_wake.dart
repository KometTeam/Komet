import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'logger.dart';

class ScreenWake {
  ScreenWake._();

  static final ScreenWake instance = ScreenWake._();

  static const _channel = MethodChannel('ru.komet.app/screen');

  final Set<Object> _holders = <Object>{};

  bool get _supported {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  Future<void> acquire(Object holder) async {
    if (!_supported || !_holders.add(holder)) return;
    if (_holders.length == 1) await _apply(true);
  }

  Future<void> release(Object holder) async {
    if (!_supported || !_holders.remove(holder)) return;
    if (_holders.isEmpty) await _apply(false);
  }

  Future<void> _apply(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setKeepAwake', {'enabled': enabled});
    } catch (e) {
      logger.w('ScreenWake._apply: enabled=$enabled $e');
    }
  }
}
