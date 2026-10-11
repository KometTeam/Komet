import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:komet_crypto/komet_crypto.dart';

import '../../backend/modules/messages.dart';
import '../storage/app_database.dart';
import '../storage/chat_encryption_store.dart';
import '../utils/cache_notifier.dart';
import 'chat_crypto_service.dart';
import 'e2ee_service.dart';

enum MessageDecryptionState { decrypted, wrongKey, unavailable }

@immutable
class MessageDecryption {
  final String? plaintext;
  final MessageDecryptionState state;
  const MessageDecryption.decrypted(String this.plaintext)
    : state = MessageDecryptionState.decrypted;
  const MessageDecryption.wrongKey()
    : plaintext = null,
      state = MessageDecryptionState.wrongKey;
  const MessageDecryption.unavailable()
    : plaintext = null,
      state = MessageDecryptionState.unavailable;
  bool get isDecrypted => state == MessageDecryptionState.decrypted;
}

typedef MessageDecryptor =
    Future<MessageDecryption?> Function(
      int accountId,
      int chatId,
      String messageId,
      String cipherText,
    );
typedef _MessageKey = (int, int, String);

class MessageDecryptionCache {
  MessageDecryptionCache._() : _decryptor = null {
    ChatEncryptionStore.instance.revision.addListener(clear);
    E2eeService.instance.revision.addListener(clear);
  }
  @visibleForTesting
  MessageDecryptionCache.forTesting(MessageDecryptor decryptor)
    : _decryptor = decryptor;
  static final MessageDecryptionCache instance = MessageDecryptionCache._();
  static const int _maxEntries = 1000;
  final MessageDecryptor? _decryptor;
  final LinkedHashMap<_MessageKey, CacheNotifier<MessageDecryption?>> _entries =
      LinkedHashMap();
  final Map<_MessageKey, String> _cipherTexts = {};
  final Map<_MessageKey, Future<void>> _inFlight = {};
  final Map<_MessageKey, int> _versions = {};
  int _generation = 0;

  ValueListenable<MessageDecryption?> listenableFor(
    String messageId, {
    required int accountId,
    required int chatId,
  }) => _entryFor((accountId, chatId, messageId));
  CacheNotifier<MessageDecryption?> _entryFor(_MessageKey key) =>
      _entries[key] ??= CacheNotifier<MessageDecryption?>(null);

  void _evictStale(_MessageKey keep) {
    if (_entries.length <= _maxEntries) return;
    for (final key in _entries.keys.toList()) {
      if (_entries.length <= _maxEntries) break;
      if (key == keep ||
          _entries[key]!.isObserved ||
          _inFlight.containsKey(key)) {
        continue;
      }
      _entries.remove(key)!.dispose();
      _cipherTexts.remove(key);
      _versions.remove(key);
    }
  }

  void seed(
    String messageId,
    String plaintext, {
    required int accountId,
    required int chatId,
    String? cipherText,
  }) {
    final key = (accountId, chatId, messageId);
    _versions[key] = (_versions[key] ?? 0) + 1;
    if (cipherText == null) {
      _cipherTexts.remove(key);
    } else {
      _cipherTexts[key] = cipherText;
    }
    _entryFor(key).value = MessageDecryption.decrypted(plaintext);
    _evictStale(key);
  }

  void adopt(
    String fromMessageId,
    String toMessageId, {
    required int accountId,
    required int chatId,
  }) {
    final from = (accountId, chatId, fromMessageId);
    final value = _entries[from]?.value;
    if (value?.isDecrypted == true) {
      seed(
        toMessageId,
        value!.plaintext!,
        accountId: accountId,
        chatId: chatId,
        cipherText: _cipherTexts[from],
      );
    }
  }

  void request({
    required int accountId,
    required int chatId,
    required String messageId,
    required String cipherText,
  }) {
    final job = _begin(accountId, chatId, messageId, cipherText);
    if (job != null) unawaited(job);
  }

  Future<MessageDecryption?> resolve({
    required int accountId,
    required int chatId,
    required String messageId,
    required String cipherText,
  }) async {
    await _begin(accountId, chatId, messageId, cipherText);
    return _entries[(accountId, chatId, messageId)]?.value;
  }

  String? readableText(CachedMessage message) {
    final key = (message.accountId, message.chatId, message.id);
    if (_cipherTexts.containsKey(key) && _cipherTexts[key] != message.text) {
      return null;
    }
    final decryption = _entries[key]?.value;
    if (decryption == null) return message.selectableText;
    return decryption.isDecrypted ? decryption.plaintext : null;
  }

  Future<void>? _begin(
    int accountId,
    int chatId,
    String messageId,
    String cipherText,
  ) {
    if (cipherText.isEmpty) {
      final key = (accountId, chatId, messageId);
      _versions[key] = (_versions[key] ?? 0) + 1;
      _inFlight.remove(key);
      _cipherTexts[key] = cipherText;
      _entries[key]?.value = null;
      return null;
    }
    if (_decryptor == null &&
        !E2eeService.instance.isOn(accountId, chatId) &&
        !ChatCryptoService.instance.isEnabled(accountId, chatId)) {
      return null;
    }
    final key = (accountId, chatId, messageId);
    final entry = _entryFor(key);
    if (_cipherTexts.containsKey(key) && _cipherTexts[key] != cipherText) {
      _versions[key] = (_versions[key] ?? 0) + 1;
      _inFlight.remove(key);
      entry.value = null;
    }
    _cipherTexts[key] = cipherText;
    if (entry.value != null) return null;
    final running = _inFlight[key];
    if (running != null) return running;
    final generation = _generation;
    final version = _versions[key] ?? 0;
    late final Future<void> job;
    job =
        () async {
          MessageDecryption? result;
          try {
            result = await (_decryptor ?? _decryptMessage)(
              accountId,
              chatId,
              messageId,
              cipherText,
            );
          } catch (_) {
            result = const MessageDecryption.unavailable();
          }
          if (generation == _generation &&
              version == (_versions[key] ?? 0) &&
              identical(_entries[key], entry) &&
              _cipherTexts[key] == cipherText) {
            entry.value = result;
          }
        }().whenComplete(() {
          if (identical(_inFlight[key], job)) _inFlight.remove(key);
        });
    _inFlight[key] = job;
    _evictStale(key);
    return job;
  }

  Future<MessageDecryption?> _decryptMessage(
    int accountId,
    int chatId,
    String messageId,
    String cipherText,
  ) async {
    if (E2eeService.instance.isOn(accountId, chatId)) {
      final row = await AppDatabase.loadMessage(accountId, chatId, messageId);
      if (row == null) return null;
      final flag = row['e2ee'] as int? ?? 0;
      final sealed = row['text_sealed'];
      if (flag == CachedMessage.e2eeText && sealed is Uint8List) {
        final text = await E2eeService.instance.openText(
          accountId,
          chatId,
          sealed,
        );
        return text == null
            ? const MessageDecryption.unavailable()
            : MessageDecryption.decrypted(text);
      }
      if (flag == CachedMessage.e2eeFailed) {
        return const MessageDecryption.wrongKey();
      }
      if (flag == CachedMessage.e2eeFile) {
        return const MessageDecryption.decrypted('');
      }
      if (flag != CachedMessage.e2eeNone || !E2eeService.instance.available) {
        return null;
      }
      switch (KometCrypto.classifyText(cipherText)) {
        case TextClass.session:
          return const MessageDecryption.unavailable();
        case TextClass.offer:
        case TextClass.answer:
          return MessageDecryption.decrypted(cipherText.split('\n').first);
        case TextClass.legacy:
          break;
        case TextClass.none:
          return null;
      }
    }
    final crypto = ChatCryptoService.instance;
    if (!crypto.isEnabled(accountId, chatId)) return null;
    final result = await crypto.decrypt(accountId, chatId, cipherText);
    if (result.isOk) return MessageDecryption.decrypted(result.text!);
    if (result.failure == CryptoFailure.wrongKey ||
        (result.failure == CryptoFailure.noKey &&
            crypto.looksEncrypted(cipherText))) {
      return const MessageDecryption.wrongKey();
    }
    return null;
  }

  void clear() {
    _generation++;
    _cipherTexts.clear();
    _inFlight.clear();
    _versions.clear();
    for (final entry in _entries.values.toList()) {
      entry.value = null;
    }
  }
}
