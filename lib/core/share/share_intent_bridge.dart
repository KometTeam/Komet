import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../backend/api.dart';
import '../../frontend/screens/chats/chat_list_screen.dart';
import '../../frontend/widgets/swipe_route.dart';
import '../../main.dart';
import '../../models/shared_payload.dart';
import '../utils/logger.dart';
import 'share_inbox.dart';
import 'shared_file_usage.dart';

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
  late final _inbox = ShareInbox(
    consume: () => _method.invokeMethod<dynamic>('consumeInitialShare'),
    acknowledge: (id) =>
        _method.invokeMethod<void>('acknowledgeShare', {'id': id}),
    release: (id) => _method.invokeMethod<void>('releaseShare', {'id': id}),
    onShare: _receivePayload,
  );

  bool get _native {
    try {
      return Platform.isAndroid || Platform.isIOS;
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
      if (Platform.isIOS) {
        await _inbox.check();
      } else {
        _onEvent(await _method.invokeMethod<dynamic>('consumeInitialShare'));
      }
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
    if (Platform.isIOS) {
      unawaited(checkInitialShare());
      return;
    }
    final payload = SharedPayload.fromMap(event);
    if (payload == null) return;
    _receivePayload(payload);
  }

  void _receivePayload(SharedPayload payload) {
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

    final context = KometApp.overlayContext;
    if (!_ready || context == null || api.state != SessionState.online) {
      if (Platform.isIOS && (!_ready || api.state != SessionState.online)) {
        return;
      }
      if (!Platform.isIOS && _retriesLeft <= 0) {
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
    _retry?.cancel();
    _retry = null;
    _presenting = true;
    unawaited(
      pushSwipeable<void>(
        context,
        (_) => ChatListScreen(sharePayload: payload),
      ).whenComplete(() => _finishShare(payload)),
    );
  }

  Future<void> _finishShare(SharedPayload payload) async {
    Future<void> waitForFiles() => SharedFileUsage.instance.waitUntilUnused(
      payload.files.map((file) => file.path),
    );
    try {
      if (Platform.isIOS) {
        await _inbox.complete(waitForRelease: waitForFiles);
      } else {
        await waitForFiles();
        if (_pending == null) await clearCache();
      }
    } catch (e) {
      logger.w('ShareIntentBridge.complete: $e');
    } finally {
      _presenting = false;
      _flushPending();
    }
  }
}
