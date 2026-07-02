import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'call_controller.dart';

class CallBridge {
  CallBridge._();
  static final CallBridge instance = CallBridge._();

  static const _method = MethodChannel('ru.komet.app/calls');
  static const _events = EventChannel('ru.komet.app/calls_events');

  bool _started = false;

  bool get _android {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  void init() {
    if (_started || !_android) return;
    _started = true;
    _events.receiveBroadcastStream().listen(_handle, onError: (_) {});
  }

  Future<void> checkInitialCall() async {
    if (!_android) return;
    try {
      _handle(await _method.invokeMethod<dynamic>('consumeInitialCall'));
    } catch (_) {}
  }

  void _handle(Object? event) {
    if (event is! Map) return;
    final action = event['action']?.toString();
    if (action == 'hangup') {
      unawaited(CallController.instance.endActive());
      return;
    }
    if (action == 'ended') {
      CallController.instance.dismissIncoming();
      return;
    }
    final dataStr = event['data'];
    if (dataStr is! String) return;
    Object? decoded;
    try {
      decoded = jsonDecode(dataStr);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    CallController.instance.injectFromNative(
      decoded,
      autoAccept: action == 'answer',
    );
  }

  Future<void> notifyAccepted({String? caller}) async {
    if (!_android) return;
    try {
      await _method.invokeMethod<void>('notifyAccepted', {'caller': caller});
    } catch (_) {}
  }

  Future<void> notifyEnded() async {
    if (!_android) return;
    try {
      await _method.invokeMethod<void>('notifyEnded');
    } catch (_) {}
  }

  Future<void> cancelIncoming() async {
    if (!_android) return;
    try {
      await _method.invokeMethod<void>('cancelIncoming');
    } catch (_) {}
  }

  Future<bool> canUseFullScreenIntent() async {
    if (!_android) return true;
    try {
      return await _method.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> openFullScreenIntentSettings() async {
    if (!_android) return;
    try {
      await _method.invokeMethod<void>('openFullScreenIntentSettings');
    } catch (_) {}
  }
}
