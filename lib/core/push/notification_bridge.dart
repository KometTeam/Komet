import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../backend/api.dart';
import '../../frontend/widgets/max_link_nav.dart';
import '../../main.dart';
import '../utils/logger.dart';

class NotificationBridge {
  NotificationBridge._();
  static final NotificationBridge instance = NotificationBridge._();

  static const _method = MethodChannel('ru.komet.app/notifications');
  static const _events = EventChannel('ru.komet.app/notification_events');
  static const _retryDelay = Duration(milliseconds: 300);
  static const _maxRetries = 100;

  bool _started = false;
  bool _ready = false;
  int _pendingChatId = 0;
  int _activeChatId = 0;
  int _retriesLeft = 0;
  Timer? _retry;

  bool get _native {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  void init() {
    if (_started || !_native) return;
    _started = true;
    _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (e) => logger.w('NotificationBridge: events stream error: $e'),
    );
    api.stateStream.listen((state) {
      if (state == SessionState.online) _flushPending();
    });
  }

  void markReady() {
    _ready = true;
    _flushPending();
  }

  Future<void> checkInitialChat() async {
    if (!_native) return;
    try {
      _onEvent(await _method.invokeMethod<dynamic>('consumeInitialChat'));
    } catch (e) {
      logger.w('NotificationBridge.checkInitialChat: $e');
    }
  }

  Future<void> setActiveChat(int chatId) async {
    if (!_native || chatId <= 0) return;
    if (_activeChatId == chatId) return;
    _activeChatId = chatId;
    try {
      await _method.invokeMethod<void>('setActiveChat', {'chatId': chatId});
    } catch (e) {
      logger.w('NotificationBridge.setActiveChat: $e');
    }
  }

  Future<void> clearActiveChat(int chatId) async {
    if (!_native) return;
    if (chatId > 0 && _activeChatId != chatId) return;
    _activeChatId = 0;
    try {
      await _method.invokeMethod<void>('clearActiveChat');
    } catch (e) {
      logger.w('NotificationBridge.clearActiveChat: $e');
    }
  }

  void _onEvent(Object? event) {
    final chatId = event is int ? event : int.tryParse(event?.toString() ?? '');
    if (chatId == null || chatId <= 0) return;
    _pendingChatId = chatId;
    _retriesLeft = _maxRetries;
    _flushPending();
  }

  void _flushPending() {
    final chatId = _pendingChatId;
    if (chatId <= 0) return;

    final context = KometApp.navigatorKey.currentContext;
    if (!_ready || context == null || api.state != SessionState.online) {
      if (_retriesLeft <= 0) {
        _pendingChatId = 0;
        return;
      }
      _retriesLeft--;
      _retry ??= Timer(_retryDelay, () {
        _retry = null;
        _flushPending();
      });
      return;
    }

    _pendingChatId = 0;
    if (_activeChatId == chatId) return;
    unawaited(openChatById(context, chatId));
  }
}
