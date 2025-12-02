import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class ChatEncryptionConfig {
  final String password;
  final bool sendEncrypted;

  ChatEncryptionConfig({
    required this.password,
    required this.sendEncrypted,
  });

  Map<String, dynamic> toJson() => {
        'password': password,
        'sendEncrypted': sendEncrypted,
      };

  factory ChatEncryptionConfig.fromJson(Map<String, dynamic> json) {
    return ChatEncryptionConfig(
      password: (json['password'] as String?) ?? '',
      sendEncrypted: (json['sendEncrypted'] as bool?) ?? false,
    );
  }
}

class ChatEncryptionService {
  static const String _legacyPasswordKeyPrefix = 'encryption_pw_';
  static const String _configKeyPrefix = 'encryption_chat_';
  static const String encryptedPrefix = 'kometSM.';

  static final Random _rand = Random.secure();

  /// Получить полную конфигурацию шифрования для чата.
  /// Если есть старый формат (только пароль), он будет автоматически
  /// сконвертирован в новый.
  static Future<ChatEncryptionConfig?> getConfigForChat(int chatId) async {
    final prefs = await SharedPreferences.getInstance();

    final configJson = prefs.getString('$_configKeyPrefix$chatId');
    if (configJson != null) {
      try {
        final data = jsonDecode(configJson) as Map<String, dynamic>;
        return ChatEncryptionConfig.fromJson(data);
      } catch (_) {
        // Если по какой-то причине json битый — игнорируем и продолжаем.
      }
    }

    // Поддержка старого формата только с паролем
    final legacyPassword = prefs.getString('$_legacyPasswordKeyPrefix$chatId');
    if (legacyPassword != null && legacyPassword.isNotEmpty) {
      final legacyConfig = ChatEncryptionConfig(
        password: legacyPassword,
        sendEncrypted: false,
      );
      await _saveConfig(chatId, legacyConfig);
      return legacyConfig;
    }

    return null;
  }

  static Future<void> _saveConfig(
    int chatId,
    ChatEncryptionConfig config,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_configKeyPrefix$chatId',
      jsonEncode(config.toJson()),
    );
  }

  /// Установить пароль, не трогая флаг sendEncrypted.
  static Future<void> setPasswordForChat(int chatId, String password) async {
    final current = await getConfigForChat(chatId);
    final updated = ChatEncryptionConfig(
      password: password,
      sendEncrypted: current?.sendEncrypted ?? false,
    );
    await _saveConfig(chatId, updated);
  }

  /// Установить флаг "отправлять зашифрованные сообщения" для чата.
  static Future<void> setSendEncryptedForChat(
    int chatId,
    bool enabled,
  ) async {
    final current = await getConfigForChat(chatId);
    final updated = ChatEncryptionConfig(
      password: current?.password ?? '',
      sendEncrypted: enabled,
    );
    await _saveConfig(chatId, updated);
  }

  /// Быстрый хелпер для получения только пароля (для совместимости со старым кодом).
  static Future<String?> getPasswordForChat(int chatId) async {
    final cfg = await getConfigForChat(chatId);
    return cfg?.password;
  }

  /// Быстрый хелпер для проверки, включена ли зашифрованная отправка для чата.
  static Future<bool> isSendEncryptedEnabled(int chatId) async {
    final cfg = await getConfigForChat(chatId);
    return cfg?.sendEncrypted ?? false;
  }

  /// Простейшее симметричное "шифрование" на базе XOR с ключом из пароля и соли.
  /// Это НЕ криптографически стойкая схема и при желании легко
  /// может быть заменена на AES/ChaCha, но для прототипа достаточно.
  static String encryptWithPassword(String password, String plaintext) {
    final salt = _randomBytes(8);
    final key = Uint8List.fromList(utf8.encode(password) + salt);

    final plainBytes = utf8.encode(plaintext);
    final cipherBytes = _xorWithKey(plainBytes, key);

    final payload = {
      's': base64Encode(salt),
      'c': base64Encode(cipherBytes),
    };

    final payloadJson = jsonEncode(payload);
    final payloadB64 = base64Encode(utf8.encode(payloadJson));

    return '$encryptedPrefix$payloadB64';
  }

  /// Попытаться расшифровать сообщение с использованием пароля.
  /// Если формат некорректный или пароль не подошёл — вернём null.
  static String? decryptWithPassword(String password, String text) {
    if (!text.startsWith(encryptedPrefix)) return null;

    final payloadB64 = text.substring(encryptedPrefix.length);
    try {
      final payloadJson = utf8.decode(base64Decode(payloadB64));
      final data = jsonDecode(payloadJson) as Map<String, dynamic>;

      final salt = base64Decode(data['s'] as String);
      final cipherBytes = base64Decode(data['c'] as String);

      final key = Uint8List.fromList(utf8.encode(password) + salt);
      final plainBytes = _xorWithKey(cipherBytes, key);

      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _rand.nextInt(256);
    }
    return bytes;
  }

  static Uint8List _xorWithKey(List<int> data, List<int> key) {
    final out = Uint8List(data.length);
    for (var i = 0; i < data.length; i++) {
      out[i] = data[i] ^ key[i % key.length];
    }
    return out;
  }
}

