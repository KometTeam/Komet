import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../storage/chat_encryption_store.dart';
import '../utils/download_progress.dart';
import '../utils/logger.dart';
import '../utils/media_cache.dart';
import 'chat_crypto_service.dart';
import 'encrypted_photo.dart';

typedef EncryptedPhotoUrlLoader = Future<String?> Function();

enum EncryptedPhotoStatus { plain, decrypted, wrongKey, locked }

@immutable
class EncryptedPhotoView {
  final File? file;
  final EncryptedPhotoStatus status;

  const EncryptedPhotoView.plain()
    : file = null,
      status = EncryptedPhotoStatus.plain;

  const EncryptedPhotoView.decrypted(File this.file)
    : status = EncryptedPhotoStatus.decrypted;

  const EncryptedPhotoView.wrongKey()
    : file = null,
      status = EncryptedPhotoStatus.wrongKey;

  const EncryptedPhotoView.locked()
    : file = null,
      status = EncryptedPhotoStatus.locked;

  bool get isDecrypted => status == EncryptedPhotoStatus.decrypted;
}

class _AutoRequest {
  final int accountId;
  final int chatId;
  final String cacheName;
  final EncryptedPhotoUrlLoader urlLoader;
  final int size;

  const _AutoRequest({
    required this.accountId,
    required this.chatId,
    required this.cacheName,
    required this.urlLoader,
    required this.size,
  });
}

class EncryptedPhotoCache {
  EncryptedPhotoCache._() {
    ChatEncryptionStore.instance.revision.addListener(clear);
  }

  static final EncryptedPhotoCache instance = EncryptedPhotoCache._();

  // #***! двести последних расшифрованных
  static const int _maxEntries = 200;
  // #***! сами расшифровываем только до 32 МБ
  static const int _maxAutoBytes = 32 * 1024 * 1024;
  // #***! не больше трёх разом иначе скролл просаживается
  static const int _maxConcurrentAuto = 3;

  // #***! на картинку свой notifier, перерисуется только её пузырь
  final LinkedHashMap<String, ValueNotifier<EncryptedPhotoView?>> _entries =
      LinkedHashMap();
  final Map<String, Future<EncryptedPhotoView>> _inFlight = {};
  // #***! очередь расшифровок для видимых пузырей
  final Queue<_AutoRequest> _queue = Queue();
  final Set<String> _queued = {};
  int _running = 0;

  ValueListenable<EncryptedPhotoView?> listenableFor(String cacheName) =>
      _entryFor(cacheName);

  ValueNotifier<EncryptedPhotoView?> _entryFor(String cacheName) =>
      _entries[cacheName] ??= ValueNotifier<EncryptedPhotoView?>(null);

  void _evictStale(String keep) {
    while (_entries.length > _maxEntries) {
      final oldest = _entries.keys.first;
      if (oldest == keep) break;
      _entries.remove(oldest);
    }
  }

  // #***! запрос из пузыря, картинка уехала с экрана значит задание снимаем
  void request({
    required int accountId,
    required int chatId,
    required String cacheName,
    required EncryptedPhotoUrlLoader urlLoader,
    required int size,
  }) {
    if (!ChatCryptoService.instance.isEnabled(accountId, chatId)) return;
    if (_entryFor(cacheName).value != null) return;
    if (_inFlight.containsKey(cacheName)) return;
    if (!_queued.add(cacheName)) return;
    _evictStale(cacheName);
    _queue.add(
      _AutoRequest(
        accountId: accountId,
        chatId: chatId,
        cacheName: cacheName,
        urlLoader: urlLoader,
        size: size,
      ),
    );
    _pump();
  }

  // #***! открыли просмотрщик, расшифровываем мимо очереди
  Future<EncryptedPhotoView> resolve({
    required int accountId,
    required int chatId,
    required String cacheName,
    required EncryptedPhotoUrlLoader urlLoader,
  }) {
    final known = _entryFor(cacheName).value;
    if (known != null && known.status != EncryptedPhotoStatus.locked) {
      return Future.value(known);
    }
    _dequeue(cacheName);
    return _start(accountId, chatId, cacheName, urlLoader, null);
  }

  void clear() {
    _queue.clear();
    _queued.clear();
    for (final entry in _entries.values) {
      entry.value = null;
    }
  }

  void _dequeue(String cacheName) {
    if (!_queued.remove(cacheName)) return;
    _queue.removeWhere((request) => request.cacheName == cacheName);
  }

  // #***! насос очереди
  void _pump() {
    while (_running < _maxConcurrentAuto && _queue.isNotEmpty) {
      final next = _queue.removeLast();
      _queued.remove(next.cacheName);
      _running++;
      final done = _start(
        next.accountId,
        next.chatId,
        next.cacheName,
        next.urlLoader,
        next.size,
      );
      unawaited(
        done.whenComplete(() {
          _running--;
          _pump();
        }),
      );
    }
  }

  Future<EncryptedPhotoView> _start(
    int accountId,
    int chatId,
    String cacheName,
    EncryptedPhotoUrlLoader urlLoader,
    int? autoSize,
  ) {
    final running = _inFlight[cacheName];
    if (running != null) return running;
    final future = _resolve(accountId, chatId, cacheName, urlLoader, autoSize);
    _inFlight[cacheName] = future;
    unawaited(future.whenComplete(() => _inFlight.remove(cacheName)));
    return future;
  }

  Future<EncryptedPhotoView> _resolve(
    int accountId,
    int chatId,
    String cacheName,
    EncryptedPhotoUrlLoader urlLoader,
    int? autoSize,
  ) async {
    EncryptedPhotoView view;
    try {
      view = await _decrypt(accountId, chatId, cacheName, urlLoader, autoSize);
    } catch (e) {
      logger.w('encrypted preview $cacheName: $e');
      view = const EncryptedPhotoView.locked();
    }
    _entryFor(cacheName).value = view;
    return view;
  }

  // #***! само скачивание и расшифровка
  Future<EncryptedPhotoView> _decrypt(
    int accountId,
    int chatId,
    String cacheName,
    EncryptedPhotoUrlLoader urlLoader,
    int? autoSize,
  ) async {
    final ready = await MediaCache.existing(decryptedCacheName(cacheName));
    if (ready != null) return EncryptedPhotoView.decrypted(ready);

    var encrypted = await MediaCache.existing(cacheName);
    if (encrypted == null) {
      if (autoSize != null && autoSize > _maxAutoBytes) {
        return const EncryptedPhotoView.locked();
      }
      encrypted = await _download(cacheName, urlLoader);
    }
    if (encrypted == null) return const EncryptedPhotoView.locked();

    if (!await ChatCryptoService.instance.looksEncryptedImage(encrypted.path)) {
      return const EncryptedPhotoView.plain();
    }

    final result = await openEncryptedPhoto(
      accountId: accountId,
      chatId: chatId,
      encrypted: encrypted,
      cacheName: cacheName,
    );
    if (result.isOk) return EncryptedPhotoView.decrypted(result.file!);
    return result.failure == CryptoFailure.unavailable
        ? const EncryptedPhotoView.locked()
        : const EncryptedPhotoView.wrongKey();
  }

  Future<File?> _download(
    String cacheName,
    EncryptedPhotoUrlLoader urlLoader,
  ) async {
    final url = await urlLoader();
    if (url == null || url.isEmpty) return null;
    MediaDownloadProgress.set(cacheName, 0);
    try {
      return await MediaCache.getOrDownload(
        cacheName,
        url,
        onProgress: (p) => MediaDownloadProgress.set(cacheName, p),
      );
    } finally {
      MediaDownloadProgress.set(cacheName, null);
    }
  }
}
