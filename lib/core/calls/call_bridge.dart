import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../utils/logger.dart';
import '../../backend/modules/messages.dart' show ContactCache;
import 'call_controller.dart';

// #***! мост к нативному экрану входящего, андроид
class CallBridge {
  CallBridge._();
  static final CallBridge instance = CallBridge._();

  static const _method = MethodChannel('ru.komet.app/calls');
  static const _events = EventChannel('ru.komet.app/calls_events');

  bool _started = false;

  bool get _native {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  bool get _isIOS {
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  // #***! события с натива, приняли сбросили закончился
  void init() {
    if (_started || !_native) return;
    _started = true;
    ContactCache.onNativeSync = (names, phones) =>
        unawaited(syncCallerNames(names, phones));
    unawaited(syncCallerNames(ContactCache.allNames, ContactCache.allPhones));
    _events.receiveBroadcastStream().listen(
      _handle,
      onError: (e) => logger.w('CallBridge.init: events stream error: $e'),
    );
  }

  // #***! звонок мог прийти пока приложение не запущено
  Future<void> checkInitialCall() async {
    if (!_native) return;
    try {
      _handle(await _method.invokeMethod<dynamic>('consumeInitialCall'));
    } catch (e) {
      logger.w('CallBridge.checkInitialCall: $e');
    }
  }

  // #***! hangup и ended без данных, остальное несёт payload
  void _handle(Object? event) {
    if (event is! Map) return;
    final action = event['action']?.toString();
    if (action == 'hangup') {
      unawaited(CallController.instance.endActive());
      return;
    }
    if (action == 'ended') {
      final dataStr = event['data'];
      if (dataStr is String) {
        Object? decoded;
        try {
          decoded = jsonDecode(dataStr);
        } catch (e) {
          logger.w('CallBridge._handle: action=$action jsonDecode failed: $e');
        }
        if (decoded is Map) {
          unawaited(CallController.instance.rejectFromNative(decoded));
          return;
        }
      }
      CallController.instance.dismissIncoming();
      return;
    }
    final dataStr = event['data'];
    if (dataStr is! String) return;
    Object? decoded;
    try {
      decoded = jsonDecode(dataStr);
    } catch (e) {
      logger.w('CallBridge._handle: action=$action jsonDecode failed: $e');
      return;
    }
    if (decoded is! Map) return;
    CallController.instance.injectFromNative(
      decoded,
      autoAccept: action == 'answer',
    );
  }

  // #***! дальше управление нативным уведомлением
  Future<void> notifyAccepted({String? caller}) async {
    if (!_native) return;
    try {
      await _method.invokeMethod<void>('notifyAccepted', {'caller': caller});
    } catch (e) {
      logger.w('CallBridge.notifyAccepted: caller=$caller $e');
    }
  }

  Future<void> ensureOngoing({String? caller}) async {
    if (!_native) return;
    try {
      await _method.invokeMethod<void>('ensureOngoing', {'caller': caller});
    } catch (e) {
      logger.w('CallBridge.ensureOngoing: $e');
    }
  }

  Future<void> setScreenShare(bool enabled, {String? caller}) async {
    if (!_native) return;
    try {
      await _method.invokeMethod<void>('setScreenShare', {
        'enabled': enabled,
        'caller': ?caller,
      });
    } catch (e) {
      logger.w('CallBridge.setScreenShare: $e');
    }
  }

  // PiP рисует собеседника из этой дорожки; вызывается при бинде видеотрека
  Future<void> setPiPTrack(String trackId) async {
    if (!_isIOS) return;
    try {
      await _method.invokeMethod<void>('setPiPTrack', {'trackId': trackId});
    } catch (e) {
      logger.w('CallBridge.setPiPTrack: $e');
    }
  }

  // Звонок разросся до группы — PiP выключаем
  Future<void> clearPiPTracks() async {
    if (!_isIOS) return;
    try {
      await _method.invokeMethod<void>('clearPiPTracks');
    } catch (e) {
      logger.w('CallBridge.clearPiPTracks: $e');
    }
  }

  Future<void> dropOngoing() async {
    if (!_native) return;
    try {
      await _method.invokeMethod<void>('dropOngoing');
    } catch (e) {
      logger.w('CallBridge.dropOngoing: $e');
    }
  }

  Future<void> notifyEnded() async {
    if (!_native) return;
    try {
      await _method.invokeMethod<void>('notifyEnded');
    } catch (e) {
      logger.w('CallBridge.notifyEnded: $e');
    }
  }

  Future<void> cancelIncoming() async {
    if (!_native) return;
    try {
      await _method.invokeMethod<void>('cancelIncoming');
    } catch (e) {
      logger.w('CallBridge.cancelIncoming: $e');
    }
  }

  Future<void> reportIncomingCall({
    required String conversationId,
    String? callerName,
    bool isVideo = false,
    String? vcp,
    int? callerId,
  }) async {
    if (!_native) return;
    try {
      await _method.invokeMethod<void>('reportIncomingCall', {
        'conversationId': conversationId,
        'callerName': callerName ?? 'Неизвестный номер',
        'isVideo': isVideo,
        'vcp': vcp,
        'callerId': callerId,
      });
    } catch (e) {
      logger.w('CallBridge.reportIncomingCall: $e');
    }
  }

  Future<void> syncCallerNames(
    Map<int, String> names,
    Map<int, int> phones,
  ) async {
    if (!_isIOS) return;
    try {
      await _method.invokeMethod<void>('syncCallerNames', {
        'names': {for (final e in names.entries) '${e.key}': e.value},
        'phones': {for (final e in phones.entries) '${e.key}': e.value},
      });
    } catch (e) {
      logger.w('CallBridge.syncCallerNames: $e');
    }
  }

  Future<bool> callViaPhone(int phone) async {
    if (!_isIOS || phone <= 0) return false;
    try {
      return await _method.invokeMethod<bool>('callViaPhone', {
            'phone': phone,
          }) ??
          false;
    } catch (e) {
      logger.w('CallBridge.callViaPhone: $e');
      return false;
    }
  }

  Future<void> reportOutgoingCall({
    required String conversationId,
    String? callerName,
    int? callerId,
    bool isVideo = false,
  }) async {
    if (!_native) return;
    try {
      await _method.invokeMethod<void>('reportOutgoingCall', {
        'conversationId': conversationId,
        'callerName': callerName ?? 'Неизвестный номер',
        'callerId': callerId,
        'isVideo': isVideo,
      });
    } catch (e) {
      logger.w('CallBridge.reportOutgoingCall: $e');
    }
  }

  Future<bool> canUseFullScreenIntent() async {
    if (!_native) return true;
    if (_isIOS) return true;
    try {
      return await _method.invokeMethod<bool>('canUseFullScreenIntent') ?? true;
    } catch (e) {
      logger.w('CallBridge.canUseFullScreenIntent: $e');
      return true;
    }
  }

  Future<void> openFullScreenIntentSettings() async {
    if (!_native) return;
    if (_isIOS) return;
    try {
      await _method.invokeMethod<void>('openFullScreenIntentSettings');
    } catch (e) {
      logger.w('CallBridge.openFullScreenIntentSettings: $e');
    }
  }
}
