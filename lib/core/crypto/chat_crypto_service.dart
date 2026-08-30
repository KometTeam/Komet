import 'dart:async';
import 'dart:typed_data';

import 'package:komet_crypto/komet_crypto.dart' as kc;

import '../storage/chat_encryption_store.dart';
import '../utils/logger.dart';

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

// #***! шифрование сообщений и картинок, сама крипта в расте
class ChatCryptoService {
  ChatCryptoService._() {
    ChatEncryptionStore.instance.revision.addListener(clearKeys);
  }

  static final ChatCryptoService instance = ChatCryptoService._();

  // #***! ключи в памяти по аккаунт/чат, _pending схлопывает параллельный вывод
  final Map<String, Uint8List> _keys = {};
  final Map<String, Future<Uint8List?>> _pending = {};
  Future<void>? _init;
  bool _unavailable = false;

  String _cacheKey(int accountId, int chatId) => '$accountId/$chatId';

  void clearKeys() {
    _keys.clear();
    _pending.clear();
  }

  // #***! нативка может не собраться, тогда фича выключена
  Future<bool> _ensureInitialized() async {
    if (_unavailable) return false;
    try {
      await (_init ??= kc.RustLib.init());
      return true;
    } catch (e) {
      _init = null;
      _unavailable = true;
      logger.w('komet_crypto init failed: $e');
      return false;
    }
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
      if (!await _ensureInitialized()) return null;
      final password = await ChatEncryptionStore.instance.readKey(
        accountId,
        chatId,
      );
      if (password == null || password.isEmpty) return null;
      final key = await kc.deriveKey(password: password);
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

  // #***! шифрование и расшифровка текста
  Future<CryptoResult> encrypt(
    int accountId,
    int chatId,
    String plaintext,
  ) async {
    final key = await _keyFor(accountId, chatId);
    if (key == null) {
      return CryptoResult.failed(
        _unavailable ? CryptoFailure.unavailable : CryptoFailure.noKey,
      );
    }
    try {
      return CryptoResult.ok(
        await kc.encryptMessage(plaintext: plaintext, key: key),
      );
    } catch (e) {
      logger.w('encrypt for chat $chatId: $e');
      return const CryptoResult.failed(CryptoFailure.unavailable);
    }
  }

  Future<CryptoResult> decrypt(int accountId, int chatId, String text) async {
    final key = await _keyFor(accountId, chatId);
    if (key == null) {
      return CryptoResult.failed(
        _unavailable ? CryptoFailure.unavailable : CryptoFailure.noKey,
      );
    }
    try {
      return CryptoResult.ok(await kc.decryptMessage(text: text, key: key));
    } catch (e) {
      return CryptoResult.failed(_failureFromCode(e.toString()));
    }
  }

  // #***! картинки файл в файл, мимо памяти
  Future<CryptoFailure?> encryptImageFile(
    int accountId,
    int chatId,
    String sourcePath,
    String destPath,
  ) => _imageOp(
    accountId,
    chatId,
    () => kc.encryptImageFile(
      sourcePath: sourcePath,
      destPath: destPath,
      key: _keys[_cacheKey(accountId, chatId)]!,
    ),
  );

  Future<CryptoFailure?> decryptImageFile(
    int accountId,
    int chatId,
    String sourcePath,
    String destPath,
  ) => _imageOp(
    accountId,
    chatId,
    () => kc.decryptImageFile(
      sourcePath: sourcePath,
      destPath: destPath,
      key: _keys[_cacheKey(accountId, chatId)]!,
    ),
  );

  Future<CryptoFailure?> _imageOp(
    int accountId,
    int chatId,
    Future<void> Function() run,
  ) async {
    final key = await _keyFor(accountId, chatId);
    if (key == null) {
      return _unavailable ? CryptoFailure.unavailable : CryptoFailure.noKey;
    }
    try {
      await run();
      return null;
    } catch (e) {
      logger.w('image crypto for chat $chatId: $e');
      return _failureFromCode(e.toString());
    }
  }

  // #***! похоже ли это вообще на наш шифр, чтоб отличить чужой ключ от обычного текста
  Future<bool> looksEncryptedImage(String path) async {
    if (!await _ensureInitialized()) return false;
    try {
      return await kc.looksEncryptedImageFile(path: path);
    } catch (_) {
      return false;
    }
  }

  Future<bool> looksEncrypted(String text) async {
    if (!await _ensureInitialized()) return false;
    try {
      return await kc.looksEncrypted(text: text);
    } catch (_) {
      return false;
    }
  }

  CryptoFailure _failureFromCode(String message) {
    if (message.contains('wrong_key')) return CryptoFailure.wrongKey;
    if (message.contains('not_encrypted')) return CryptoFailure.notEncrypted;
    if (message.contains('malformed')) return CryptoFailure.malformed;
    return CryptoFailure.unavailable;
  }
}
