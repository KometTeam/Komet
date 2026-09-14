import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../backend/api.dart';
import '../../frontend/widgets/max_link_nav.dart';
import '../../main.dart';
import '../storage/app_database.dart';
import '../storage/token_storage.dart';
import '../utils/logger.dart';

// #***! открытие чата по тапу на уведомление
class NotificationBridge {
  NotificationBridge._();
  static final NotificationBridge instance = NotificationBridge._();

  static const _method = MethodChannel('ru.komet.app/notifications');
  static const _events = EventChannel('ru.komet.app/notification_events');
  static const _retryDelay = Duration(milliseconds: 300);
  static const _maxRetries = 100;

  // #***! стек открытых чатов, натив не уведомляет про то что на экране
  final List<int> _activeChats = [];

  bool _started = false;
  bool _ready = false;
  int _pendingChatId = 0;
  int _openingChatId = 0;
  int? _sentChatId;
  int _retriesLeft = 0;
  Timer? _retry;

  int get _activeChatId => _activeChats.isEmpty ? 0 : _activeChats.last;

  bool get _native {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  bool get _android {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  // #***! подписка на уведомления и сессию
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

  // #***! запустили тапом по уведомлению, забираем чат который натив придержал
  Future<void> checkInitialChat() async {
    if (!_native) return;
    try {
      _onEvent(await _method.invokeMethod<dynamic>('consumeInitialChat'));
    } catch (e) {
      logger.w('NotificationBridge.checkInitialChat: $e');
    }
  }

  // #***! вошли в чат, говорим нативу чтоб не уведомлял
  Future<void> pushActiveChat(int chatId) async {
    if (!_native || chatId == 0) return;
    if (_openingChatId == chatId) _openingChatId = 0;
    _activeChats.add(chatId);
    await _syncActiveChat();
  }

  Future<void> popActiveChat(int chatId) async {
    if (!_native || chatId == 0) return;
    final index = _activeChats.lastIndexOf(chatId);
    if (index < 0) return;
    _activeChats.removeAt(index);
    await _syncActiveChat();
  }

  Future<void> cancelChat(int chatId) async {
    if (!_android || chatId == 0) return;
    try {
      await _method.invokeMethod<void>('cancelChat', {'chatId': chatId});
    } catch (e) {
      logger.w('NotificationBridge.cancelChat: $e');
    }
  }

  Future<void> dismissReadChats() async {
    if (!_android) return;
    final List<int> notified;
    try {
      notified =
          (await _method.invokeListMethod<int>('notifiedChats')) ?? const [];
    } catch (e) {
      logger.w('NotificationBridge.notifiedChats: $e');
      return;
    }
    if (notified.isEmpty) return;
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;
    for (final chatId in notified) {
      final rows = await AppDatabase.loadChat(accountId, chatId);
      if (rows.isEmpty) continue;
      if ((rows.first['unread_count'] as int? ?? 0) == 0) {
        await cancelChat(chatId);
      }
    }
  }

  Future<void> onAppResumed() async {
    if (!_native) return;
    _sentChatId = null;
    await _syncActiveChat();
    final chatId = _activeChatId;
    if (chatId != 0) await cancelChat(chatId);
    await dismissReadChats();
  }

  Future<void> _syncActiveChat() async {
    final chatId = _activeChatId;
    if (chatId == _sentChatId) return;
    _sentChatId = chatId;
    try {
      if (chatId != 0) {
        await _method.invokeMethod<void>('setActiveChat', {'chatId': chatId});
      } else {
        await _method.invokeMethod<void>('clearActiveChat');
      }
    } catch (e) {
      logger.w('NotificationBridge: активный чат не синхронизирован: $e');
    }
  }

  // #***! событие это просто id чата
  void _onEvent(Object? event) {
    final chatId = event is int ? event : int.tryParse(event?.toString() ?? '');
    if (chatId == null || chatId == 0) return;
    _pendingChatId = chatId;
    _retriesLeft = _maxRetries;
    _flushPending();
  }

  // #***! ждём дерево и сессию иначе ретраим, открытый чат не переоткрываем
  void _flushPending() {
    final chatId = _pendingChatId;
    if (chatId == 0) return;

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
    if (_activeChatId == chatId || _openingChatId == chatId) return;
    _openingChatId = chatId;
    unawaited(
      openChatById(context, chatId).whenComplete(() {
        if (_openingChatId == chatId) _openingChatId = 0;
      }),
    );
  }
}
