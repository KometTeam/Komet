import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../backend/api.dart';
import '../../frontend/screens/chats/chat_list_screen.dart';
import '../../frontend/widgets/swipe_route.dart';
import '../../main.dart';
import '../../models/shared_payload.dart';
import '../utils/logger.dart';

// #***! системное поделиться, файлы с натива
class ShareIntentBridge {
  ShareIntentBridge._();
  static final ShareIntentBridge instance = ShareIntentBridge._();

  static const _method = MethodChannel('ru.komet.app/share');
  static const _events = EventChannel('ru.komet.app/share_events');
  // #***! экран может быть не готов, ретраим
  static const _retryDelay = Duration(milliseconds: 300);
  static const _maxRetries = 100;

  bool _started = false;
  bool _ready = false;
  bool _presenting = false;
  SharedPayload? _pending;
  int _retriesLeft = 0;
  Timer? _retry;

  bool get _native {
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  // #***! подписка на шаринг и состояние сессии
  void init() {
    if (_started || !_native) return;
    _started = true;
    _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (e) => logger.w('ShareIntentBridge: events stream error: $e'),
    );
    api.stateStream.listen((state) {
      if (state == SessionState.online) _flushPending();
    });
  }

  // #***! юишка говорит что готова
  void markReady() {
    _ready = true;
    _flushPending();
  }

  // #***! запустили сразу из поделиться, забираем что лежит
  Future<void> checkInitialShare() async {
    if (!_native) return;
    try {
      _onEvent(await _method.invokeMethod<dynamic>('consumeInitialShare'));
    } catch (e) {
      logger.w('ShareIntentBridge.checkInitialShare: $e');
    }
  }

  Future<void> clearCache() async {
    if (!_native) return;
    try {
      await _method.invokeMethod<void>('clearCache');
    } catch (e) {
      logger.w('ShareIntentBridge.clearCache: $e');
    }
  }

  // #***! полученное откладываем и пробуем показать
  void _onEvent(Object? event) {
    final payload = SharedPayload.fromMap(event);
    if (payload == null) return;
    logger.i(
      'Поделиться: получено ${payload.files.length} файлов'
      '${payload.text != null ? ' и текст' : ''}',
    );
    _pending = payload;
    _retriesLeft = _maxRetries;
    _flushPending();
  }

  // #***! показываем если есть контекст и сессия, иначе ретраим
  void _flushPending() {
    final payload = _pending;
    if (payload == null || _presenting) return;

    final context = KometApp.navigatorKey.currentContext;
    if (!_ready || context == null || api.state != SessionState.online) {
      if (_retriesLeft <= 0) {
        _pending = null;
        return;
      }
      _retriesLeft--;
      _retry ??= Timer(_retryDelay, () {
        _retry = null;
        _flushPending();
      });
      return;
    }

    // #***! кэш натива чистим после закрытия
    _pending = null;
    _presenting = true;
    unawaited(
      pushSwipeable<void>(
        context,
        (_) => ChatListScreen(sharePayload: payload),
      ).whenComplete(() {
        _presenting = false;
        unawaited(clearCache());
      }),
    );
  }
}
