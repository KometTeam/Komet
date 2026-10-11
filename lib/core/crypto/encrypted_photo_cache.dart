import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import '../storage/chat_encryption_store.dart';
import 'e2ee_service.dart';
import '../utils/download_progress.dart';
import '../utils/logger.dart';
import '../utils/cache_notifier.dart';
import '../utils/media_cache.dart';
import 'chat_crypto_service.dart';
import 'encrypted_photo.dart';
import 'decrypted_photo_store.dart';

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
  final Uint8List? sealedTicket;

  const _AutoRequest({
    required this.accountId,
    required this.chatId,
    required this.cacheName,
    required this.urlLoader,
    required this.size,
    required this.sealedTicket,
  });
}

class EncryptedPhotoCache {
  EncryptedPhotoCache._() {
    ChatEncryptionStore.instance.revision.addListener(clear);
    E2eeService.instance.revision.addListener(clear);
  }

  static final EncryptedPhotoCache instance = EncryptedPhotoCache._();

  // #***! двести последних расшифрованных
  static const int _maxEntries = 200;
  // #***! сами расшифровываем только до 32 МБ
  static const int _maxAutoBytes = 32 * 1024 * 1024;
  // #***! не больше трёх разом иначе скролл просаживается
  static const int _maxConcurrentAuto = 3;

  // #***! на картинку свой notifier, перерисуется только её пузырь
  final LinkedHashMap<String, CacheNotifier<EncryptedPhotoView?>> _entries =
      LinkedHashMap();
  final Map<String, Future<EncryptedPhotoView>> _inFlight = {};
  // #***! очередь расшифровок для видимых пузырей
  final Queue<_AutoRequest> _queue = Queue();
  final Set<String> _queued = {};
  int _running = 0;
  int _generation = 0;

  String _key(
    int accountId,
    int chatId,
    String cacheName, [
    Uint8List? sealedTicket,
  ]) =>
      '$accountId/$chatId/$cacheName/${sealedTicket == null ? '' : sha256.convert(sealedTicket)}';

  ValueListenable<EncryptedPhotoView?> listenableFor(
    String cacheName, {
    required int accountId,
    required int chatId,
    Uint8List? sealedTicket,
  }) => _entryFor(_key(accountId, chatId, cacheName, sealedTicket));

  CacheNotifier<EncryptedPhotoView?> _entryFor(String cacheName) =>
      _entries[cacheName] ??= CacheNotifier<EncryptedPhotoView?>(null);

  void _evictStale(String keep) {
    if (_entries.length <= _maxEntries) return;
    for (final key in _entries.keys.toList()) {
      if (_entries.length <= _maxEntries) break;
      final entry = _entries[key]!;
      if (key == keep ||
          entry.isObserved ||
          _inFlight.containsKey(key) ||
          _queued.contains(key)) {
        continue;
      }
      _entries.remove(key);
      entry.dispose();
    }
  }

  // #***! запрос из пузыря, картинка уехала с экрана значит задание снимаем
  void request({
    required int accountId,
    required int chatId,
    required String cacheName,
    required EncryptedPhotoUrlLoader urlLoader,
    required int size,
    Uint8List? sealedTicket,
  }) {
    if (sealedTicket == null &&
        !ChatCryptoService.instance.isEnabled(accountId, chatId)) {
      return;
    }
    final key = _key(accountId, chatId, cacheName, sealedTicket);
    if (_entryFor(key).value != null) return;
    if (_inFlight.containsKey(key)) return;
    if (!_queued.add(key)) return;
    _evictStale(key);
    _queue.add(
      _AutoRequest(
        accountId: accountId,
        chatId: chatId,
        cacheName: cacheName,
        urlLoader: urlLoader,
        size: size,
        sealedTicket: sealedTicket,
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
    int? size,
    Uint8List? sealedTicket,
  }) {
    final known = _entryFor(
      _key(accountId, chatId, cacheName, sealedTicket),
    ).value;
    if (known != null && known.status != EncryptedPhotoStatus.locked) {
      return Future.value(known);
    }
    _dequeue(_key(accountId, chatId, cacheName, sealedTicket));
    return _start(accountId, chatId, cacheName, urlLoader, size, sealedTicket);
  }

  void clear() {
    _generation++;
    _inFlight.clear();
    unawaited(
      DecryptedPhotoStore.clear().catchError((Object error) {
        logger.w('decrypted cache clear: $error');
      }),
    );
    _queue.clear();
    _queued.clear();
    for (final entry in _entries.values) {
      entry.value = null;
    }
  }

  void _dequeue(String cacheName) {
    if (!_queued.remove(cacheName)) return;
    _queue.removeWhere(
      (request) =>
          _key(
            request.accountId,
            request.chatId,
            request.cacheName,
            request.sealedTicket,
          ) ==
          cacheName,
    );
  }

  // #***! насос очереди
  void _pump() {
    while (_running < _maxConcurrentAuto && _queue.isNotEmpty) {
      final next = _queue.removeLast();
      _queued.remove(
        _key(next.accountId, next.chatId, next.cacheName, next.sealedTicket),
      );
      _running++;
      final done = _start(
        next.accountId,
        next.chatId,
        next.cacheName,
        next.urlLoader,
        next.size,
        next.sealedTicket,
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
    Uint8List? sealedTicket,
  ) {
    final key = _key(accountId, chatId, cacheName, sealedTicket);
    final generation = _generation;
    final running = _inFlight[key];
    if (running != null) return running;
    final future = _resolve(
      accountId,
      chatId,
      cacheName,
      urlLoader,
      autoSize,
      sealedTicket,
      generation,
    );
    _inFlight[key] = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight[key], future)) _inFlight.remove(key);
      }),
    );
    return future;
  }

  Future<EncryptedPhotoView> _resolve(
    int accountId,
    int chatId,
    String cacheName,
    EncryptedPhotoUrlLoader urlLoader,
    int? autoSize,
    Uint8List? sealedTicket,
    int generation,
  ) async {
    EncryptedPhotoView view;
    try {
      view = await _decrypt(
        accountId,
        chatId,
        cacheName,
        urlLoader,
        autoSize,
        sealedTicket,
        generation,
      );
    } catch (e) {
      logger.w('encrypted preview $cacheName: $e');
      view = const EncryptedPhotoView.locked();
    }
    if (generation != _generation) return const EncryptedPhotoView.locked();
    _entryFor(_key(accountId, chatId, cacheName, sealedTicket)).value = view;
    return view;
  }

  // #***! само скачивание и расшифровка
  Future<EncryptedPhotoView> _decrypt(
    int accountId,
    int chatId,
    String cacheName,
    EncryptedPhotoUrlLoader urlLoader,
    int? autoSize,
    Uint8List? sealedTicket,
    int generation,
  ) async {
    // #***! имя расшифрованного берётся из билета, поэтому билет первым
    Uint8List? ticket;
    if (sealedTicket != null) {
      ticket = await E2eeService.instance.openBytes(
        accountId,
        chatId,
        sealedTicket,
      );
      if (generation != _generation) return const EncryptedPhotoView.locked();
      if (ticket == null) return const EncryptedPhotoView.locked();
      final ready = await DecryptedPhotoStore.existing(
        e2eeDecryptedCacheName(ticket),
      );
      if (ready != null) return EncryptedPhotoView.decrypted(ready);
    } else {
      if (await ChatEncryptionStore.instance.readKey(accountId, chatId) == null ||
          generation != _generation) {
        return const EncryptedPhotoView.locked();
      }
      final ready = await DecryptedPhotoStore.existing(
        decryptedCacheName(accountId, chatId, cacheName),
      );
      if (ready != null) return EncryptedPhotoView.decrypted(ready);
    }

    var encrypted = await MediaCache.existing(cacheName);
    if (encrypted == null) {
      if (autoSize != null && autoSize > _maxAutoBytes) {
        return const EncryptedPhotoView.locked();
      }
      // #***! потолок по объявленному размеру, но не выше нашего собственного
      final cap = autoSize == null || autoSize <= 0
          ? _maxAutoBytes
          : (autoSize < _maxAutoBytes ? autoSize : _maxAutoBytes);
      encrypted = await _download(cacheName, urlLoader, cap);
    }
    if (generation != _generation || encrypted == null) {
      return const EncryptedPhotoView.locked();
    }

    if (ticket != null) {
      final opened = await openE2eePhoto(encrypted: encrypted, ticket: ticket);
      if (opened.isOk) return EncryptedPhotoView.decrypted(opened.file!);
      return opened.failure == CryptoFailure.unavailable
          ? const EncryptedPhotoView.locked()
          : const EncryptedPhotoView.wrongKey();
    }

    final result = await openEncryptedPhoto(
      accountId: accountId,
      chatId: chatId,
      encrypted: encrypted,
      cacheName: cacheName,
    );
    if (result.isOk) return EncryptedPhotoView.decrypted(result.file!);
    if (result.failure == CryptoFailure.notEncrypted) {
      return const EncryptedPhotoView.plain();
    }
    return result.failure == CryptoFailure.unavailable
        ? const EncryptedPhotoView.locked()
        : const EncryptedPhotoView.wrongKey();
  }

  Future<File?> _download(
    String cacheName,
    EncryptedPhotoUrlLoader urlLoader,
    int maxBytes,
  ) async {
    final url = await urlLoader();
    if (url == null || url.isEmpty) return null;
    MediaDownloadProgress.set(cacheName, 0);
    try {
      return await MediaCache.getOrDownload(
        cacheName,
        url,
        onProgress: (p) => MediaDownloadProgress.set(cacheName, p),
        maxBytes: maxBytes,
      );
    } finally {
      MediaDownloadProgress.set(cacheName, null);
    }
  }
}
