import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:komet_crypto/komet_crypto.dart';

import '../storage/chat_encryption_store.dart';
import '../utils/logger.dart';
import 'noise_png.dart';

const int kMaxEncryptedMessageLength = 1000;

// #***! почему не вышло
enum CryptoFailure { noKey, wrongKey, notEncrypted, malformed, unavailable }

// #***! текст либо причина неудачи
class CryptoResult {
  final String? text;
  final CryptoFailure? failure;

  const CryptoResult.ok(String this.text) : failure = null;
  const CryptoResult.failed(CryptoFailure this.failure) : text = null;

  bool get isOk => text != null;
}

// #***! байты либо причина неудачи
class CryptoBytesResult {
  final Uint8List? bytes;
  final CryptoFailure? failure;

  const CryptoBytesResult.ok(Uint8List this.bytes) : failure = null;
  const CryptoBytesResult.failed(CryptoFailure this.failure) : bytes = null;

  bool get isOk => bytes != null;
}

CryptoFailure cryptoFailureOf(Object error) {
  if (error is KometCryptoException) {
    switch (error.status) {
      case CryptoStatus.wrongKey:
        return CryptoFailure.wrongKey;
      case CryptoStatus.notEncrypted:
        return CryptoFailure.notEncrypted;
      case CryptoStatus.malformed:
        return CryptoFailure.malformed;
      default:
        return CryptoFailure.unavailable;
    }
  }
  return CryptoFailure.unavailable;
}

// #***! парольное шифрование групп и старой истории, сама крипта в C-ядре
class ChatCryptoService {
  ChatCryptoService._() {
    ChatEncryptionStore.instance.revision.addListener(clearKeys);
  }

  static final ChatCryptoService instance = ChatCryptoService._();

  // #***! ключи в памяти по аккаунт/чат, _pending схлопывает параллельный вывод
  final Map<String, Uint8List> _keys = {};
  final Map<String, Future<Uint8List?>> _pending = {};

  String _cacheKey(int accountId, int chatId) => '$accountId/$chatId';

  bool get _unavailable => !KometCrypto.isAvailable;

  void clearKeys() {
    for (final key in _keys.values) {
      KometCrypto.wipe(key);
    }
    _keys.clear();
    _pending.clear();
  }

  // #***! ключ выводится из парольной фразы и это дорого, отсюда кэш
  Future<Uint8List?> _keyFor(int accountId, int chatId) {
    final cacheKey = _cacheKey(accountId, chatId);
    final cached = _keys[cacheKey];
    if (cached != null) return Future.value(cached);
    return _pending[cacheKey] ??= _deriveKey(accountId, chatId, cacheKey);
  }

  Future<Uint8List?> _deriveKey(
    int accountId,
    int chatId,
    String cacheKey,
  ) async {
    try {
      if (_unavailable) return null;
      final password = await ChatEncryptionStore.instance.readKey(
        accountId,
        chatId,
      );
      if (password == null || password.isEmpty) return null;
      final key = await Isolate.run(() => KometCrypto.deriveKey(password));
      _keys[cacheKey] = key;
      return key;
    } catch (e) {
      logger.w('derive key for chat $chatId: $e');
      return null;
    } finally {
      _pending.remove(cacheKey);
    }
  }

  // #***! включено ли шифрование в чате
  bool isEnabled(int accountId, int chatId) =>
      ChatEncryptionStore.instance.isEnabled(accountId, chatId);

  Future<void> warmKey(int accountId, int chatId) => _keyFor(accountId, chatId);

  CryptoFailure _noKeyFailure() =>
      _unavailable ? CryptoFailure.unavailable : CryptoFailure.noKey;

  // #***! шифрование и расшифровка текста
  Future<CryptoResult> encrypt(
    int accountId,
    int chatId,
    String plaintext,
  ) async {
    final key = await _keyFor(accountId, chatId);
    if (key == null) return CryptoResult.failed(_noKeyFailure());
    try {
      return CryptoResult.ok(KometCrypto.encryptMessage(plaintext, key));
    } catch (e) {
      logger.w('encrypt for chat $chatId: $e');
      return const CryptoResult.failed(CryptoFailure.unavailable);
    }
  }

  Future<CryptoResult> decrypt(int accountId, int chatId, String text) async {
    final key = await _keyFor(accountId, chatId);
    if (key == null) return CryptoResult.failed(_noKeyFailure());
    try {
      return CryptoResult.ok(KometCrypto.decryptMessage(text, key));
    } catch (e) {
      return CryptoResult.failed(cryptoFailureOf(e));
    }
  }

  // #***! картинки байт в байт, шум заворачивается в PNG уже здесь
  Future<CryptoBytesResult> encryptImageBytes(
    int accountId,
    int chatId,
    Uint8List png,
  ) async {
    final key = await _keyFor(accountId, chatId);
    if (key == null) return CryptoBytesResult.failed(_noKeyFailure());
    try {
      final blob = KometCrypto.encryptImageBlob(png, key);
      final wrapped = wrapNoisePng(blob);
      if (wrapped == null) {
        return const CryptoBytesResult.failed(CryptoFailure.malformed);
      }
      return CryptoBytesResult.ok(wrapped);
    } catch (e) {
      logger.w('image encrypt for chat $chatId: $e');
      return CryptoBytesResult.failed(cryptoFailureOf(e));
    }
  }

  Future<CryptoBytesResult> decryptImageBytes(
    int accountId,
    int chatId,
    Uint8List noisePng,
  ) async {
    final key = await _keyFor(accountId, chatId);
    if (key == null) return CryptoBytesResult.failed(_noKeyFailure());
    final raw = unwrapNoisePng(noisePng);
    if (raw == null) {
      return const CryptoBytesResult.failed(CryptoFailure.notEncrypted);
    }
    try {
      return CryptoBytesResult.ok(KometCrypto.decryptImageBlob(raw, key));
    } catch (e) {
      logger.w('image decrypt for chat $chatId: $e');
      return CryptoBytesResult.failed(cryptoFailureOf(e));
    }
  }

  // #***! похоже ли это вообще на наш шифр, чтоб отличить чужой ключ от обычного текста
  bool looksEncryptedImage(Uint8List noisePng) {
    if (_unavailable) return false;
    final raw = unwrapNoisePng(noisePng);
    if (raw == null) return false;
    try {
      return KometCrypto.looksEncryptedImageBlob(raw);
    } catch (_) {
      return false;
    }
  }

  // #***! разовая расшифровка чужим паролем, ключ не кэшируем
  Future<String?> decryptWithPassword(String text, String password) async {
    if (_unavailable) return null;
    try {
      final key = await Isolate.run(() => KometCrypto.deriveKey(password));
      try {
        return KometCrypto.decryptMessage(text, key);
      } finally {
        KometCrypto.wipe(key);
      }
    } catch (_) {
      return null;
    }
  }

  bool looksEncrypted(String text) {
    if (_unavailable) return false;
    try {
      return KometCrypto.looksEncryptedMessage(text);
    } catch (_) {
      return false;
    }
  }
}
