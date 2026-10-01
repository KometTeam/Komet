import 'dart:async';
import 'dart:typed_data';

import 'package:komet_crypto/komet_crypto.dart' as kc;

import '../storage/chat_encryption_store.dart';
import '../utils/logger.dart';
import 'chat_crypto_key_cache.dart';

const int kMaxEncryptedMessageLength = 1000;

enum CryptoFailure { noKey, wrongKey, notEncrypted, malformed, unavailable }

class CryptoResult {
  final String? text;
  final CryptoFailure? failure;

  const CryptoResult.ok(String this.text) : failure = null;
  const CryptoResult.failed(CryptoFailure this.failure) : text = null;

  bool get isOk => text != null;
}

class ChatCryptoService {
  ChatCryptoService._() {
    ChatEncryptionStore.instance.revision.addListener(clearKeys);
  }

  static final ChatCryptoService instance = ChatCryptoService._();

  late final ChatCryptoKeyCache _keyCache = ChatCryptoKeyCache(_deriveKey);
  Future<void>? _init;
  bool _unavailable = false;

  void clearKeys() {
    _keyCache.clear();
  }

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

  Future<Uint8List?> _keyFor(int accountId, int chatId) {
    return _keyCache.keyFor(accountId, chatId);
  }

  Future<Uint8List?> _deriveKey(int accountId, int chatId) async {
    try {
      if (!await _ensureInitialized()) return null;
      final password = await ChatEncryptionStore.instance.readKey(
        accountId,
        chatId,
      );
      if (password == null || password.isEmpty) return null;
      return await kc.deriveKey(password: password);
    } catch (e) {
      logger.w('derive key for chat $chatId: $e');
      return null;
    }
  }

  bool isEnabled(int accountId, int chatId) =>
      ChatEncryptionStore.instance.isEnabled(accountId, chatId);

  Future<void> warmKey(int accountId, int chatId) => _keyFor(accountId, chatId);

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

  Future<CryptoFailure?> encryptImageFile(
    int accountId,
    int chatId,
    String sourcePath,
    String destPath,
  ) => _imageOp(
    accountId,
    chatId,
    (key) => kc.encryptImageFile(
      sourcePath: sourcePath,
      destPath: destPath,
      key: key,
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
    (key) => kc.decryptImageFile(
      sourcePath: sourcePath,
      destPath: destPath,
      key: key,
    ),
  );

  Future<CryptoFailure?> _imageOp(
    int accountId,
    int chatId,
    Future<void> Function(Uint8List key) run,
  ) async {
    final key = await _keyFor(accountId, chatId);
    if (key == null) {
      return _unavailable ? CryptoFailure.unavailable : CryptoFailure.noKey;
    }
    try {
      await run(key);
      return null;
    } catch (e) {
      logger.w('image crypto for chat $chatId: $e');
      return _failureFromCode(e.toString());
    }
  }

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
