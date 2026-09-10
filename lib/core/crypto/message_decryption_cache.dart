import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:komet_crypto/komet_crypto.dart';

import '../../backend/modules/messages.dart';
import '../storage/app_database.dart';
import '../storage/chat_encryption_store.dart';
import 'chat_crypto_service.dart';
import 'e2ee_service.dart';

// #***! расшифровалось, ключ не тот, либо копии текста на этом устройстве нет
enum MessageDecryptionState { decrypted, wrongKey, unavailable }

// #***! результат по одному сообщению
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

// #***! кэш расшифровок, при смене ключа сбрасывается целиком
class MessageDecryptionCache {
  MessageDecryptionCache._() {
    ChatEncryptionStore.instance.revision.addListener(clear);
    E2eeService.instance.revision.addListener(clear);
  }

  static final MessageDecryptionCache instance = MessageDecryptionCache._();

  // #***! тысяча последних, дальше вытесняем
  static const int _maxEntries = 1000;

  final LinkedHashMap<String, ValueNotifier<MessageDecryption?>> _entries =
      LinkedHashMap();
  final Set<String> _inFlight = {};

  // #***! пузырь подписывается сюда и перерисуется когда текст расшифруется
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

  // #***! известный текст кладём сразу, например своё только что отправленное
  void seed(String messageId, String plaintext) {
    _entryFor(messageId).value = MessageDecryption.decrypted(plaintext);
  }

  // #***! поменяли временный id на настоящий, переносим расшифровку
  void adopt(String fromMessageId, String toMessageId) {
    final value = _entries[fromMessageId]?.value;
    if (value != null) _entryFor(toMessageId).value = value;
  }

  // #***! _inFlight чтоб не расшифровывать одно сообщение дважды
  void request({
    required int accountId,
    required int chatId,
    required String messageId,
    required String cipherText,
  }) {
    if (cipherText.isEmpty) return;
    final e2ee = E2eeService.instance.isOn(accountId, chatId);
    if (!e2ee && !ChatCryptoService.instance.isEnabled(accountId, chatId)) {
      return;
    }
    if (_entryFor(messageId).value != null) return;
    if (!_inFlight.add(messageId)) return;
    _evictStale(messageId);
    unawaited(
      e2ee
          ? _resolveSealed(accountId, chatId, messageId, cipherText)
          : _resolve(accountId, chatId, messageId, cipherText),
    );
  }

  // #***! сквозное: открытый текст лежит в базе под локальным ключом
  Future<void> _resolveSealed(
    int accountId,
    int chatId,
    String messageId,
    String cipherText,
  ) async {
    try {
      final row = await AppDatabase.loadMessage(accountId, chatId, messageId);
      if (row == null) return;
      final flag = row['e2ee'] as int? ?? 0;
      final sealed = row['text_sealed'];
      if (flag == CachedMessage.e2eeText && sealed is Uint8List) {
        final text = await E2eeService.instance.openText(
          accountId,
          chatId,
          sealed,
        );
        _entryFor(messageId).value = text == null
            ? const MessageDecryption.unavailable()
            : MessageDecryption.decrypted(text);
        return;
      }
      if (flag == CachedMessage.e2eeFailed) {
        _entryFor(messageId).value = const MessageDecryption.wrongKey();
        return;
      }
      if (flag == CachedMessage.e2eeFile) {
        _entryFor(messageId).value = const MessageDecryption.decrypted('');
        return;
      }
      if (flag != CachedMessage.e2eeNone || !E2eeService.instance.available) {
        return;
      }
      switch (KometCrypto.classifyText(cipherText)) {
        case TextClass.session:
          _entryFor(messageId).value = const MessageDecryption.unavailable();
        case TextClass.offer:
        case TextClass.answer:
          _entryFor(messageId).value = MessageDecryption.decrypted(
            cipherText.split('\n').first,
          );
        case TextClass.legacy:
          if (ChatCryptoService.instance.isEnabled(accountId, chatId)) {
            _inFlight.remove(messageId);
            await _resolve(accountId, chatId, messageId, cipherText);
          }
        case TextClass.none:
          break;
      }
    } finally {
      _inFlight.remove(messageId);
    }
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
      // #***! ключа нет показываем как неверный ключ только если текст правда похож на шифр
      switch (result.failure) {
        case CryptoFailure.wrongKey:
          _entryFor(messageId).value = const MessageDecryption.wrongKey();
        case CryptoFailure.noKey:
          if (crypto.looksEncrypted(cipherText)) {
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
