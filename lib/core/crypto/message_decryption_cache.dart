import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../storage/chat_encryption_store.dart';
import 'chat_crypto_service.dart';

enum MessageDecryptionState { decrypted, wrongKey }

@immutable
class MessageDecryption {
  final String? plaintext;
  final MessageDecryptionState state;

  const MessageDecryption.decrypted(String this.plaintext)
    : state = MessageDecryptionState.decrypted;

  const MessageDecryption.wrongKey()
    : plaintext = null,
      state = MessageDecryptionState.wrongKey;

  bool get isDecrypted => state == MessageDecryptionState.decrypted;
}

class MessageDecryptionCache {
  MessageDecryptionCache._() {
    ChatEncryptionStore.instance.revision.addListener(clear);
  }

  static final MessageDecryptionCache instance = MessageDecryptionCache._();

  static const int _maxEntries = 1000;

  final LinkedHashMap<String, ValueNotifier<MessageDecryption?>> _entries =
      LinkedHashMap();
  final Set<String> _inFlight = {};

  ValueListenable<MessageDecryption?> listenableFor(String messageId) =>
      _entryFor(messageId);

  ValueNotifier<MessageDecryption?> _entryFor(String messageId) =>
      _entries[messageId] ??= ValueNotifier<MessageDecryption?>(null);

  void _evictStale(String keep) {
    while (_entries.length > _maxEntries) {
      final oldest = _entries.keys.first;
      if (oldest == keep) break;
      _entries.remove(oldest);
    }
  }

  void seed(String messageId, String plaintext) {
    _entryFor(messageId).value = MessageDecryption.decrypted(plaintext);
  }

  void adopt(String fromMessageId, String toMessageId) {
    final value = _entries[fromMessageId]?.value;
    if (value != null) _entryFor(toMessageId).value = value;
  }

  void request({
    required int accountId,
    required int chatId,
    required String messageId,
    required String cipherText,
  }) {
    if (cipherText.isEmpty) return;
    if (!ChatCryptoService.instance.isEnabled(accountId, chatId)) return;
    if (_entryFor(messageId).value != null) return;
    if (!_inFlight.add(messageId)) return;
    _evictStale(messageId);
    unawaited(_resolve(accountId, chatId, messageId, cipherText));
  }

  Future<void> _resolve(
    int accountId,
    int chatId,
    String messageId,
    String cipherText,
  ) async {
    try {
      final crypto = ChatCryptoService.instance;
      final result = await crypto.decrypt(accountId, chatId, cipherText);
      if (result.isOk) {
        _entryFor(messageId).value = MessageDecryption.decrypted(result.text!);
        return;
      }
      switch (result.failure) {
        case CryptoFailure.wrongKey:
          _entryFor(messageId).value = const MessageDecryption.wrongKey();
        case CryptoFailure.noKey:
          if (await crypto.looksEncrypted(cipherText)) {
            _entryFor(messageId).value = const MessageDecryption.wrongKey();
          }
        case CryptoFailure.notEncrypted:
        case CryptoFailure.malformed:
        case CryptoFailure.unavailable:
        case null:
          break;
      }
    } finally {
      _inFlight.remove(messageId);
    }
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }
}
