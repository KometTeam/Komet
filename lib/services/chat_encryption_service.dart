import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:gwid/services/encryption_char_mapping.dart';

class ChatEncryptionConfig {
  final String password;
  final bool sendEncrypted;

  ChatEncryptionConfig({required this.password, required this.sendEncrypted});

  Map<String, dynamic> toJson() => {
    'password': password,
    'sendEncrypted': sendEncrypted,
  };

  factory ChatEncryptionConfig.fromJson(Map<String, dynamic> json) {
    return ChatEncryptionConfig(
      password: (json['password'] as String?) ?? '',
      sendEncrypted: (json['sendEncrypted'] as bool?) ?? true,
    );
  }
}

class ChatEncryptionService {
  static const String _legacyPasswordKeyPrefix = 'encryption_pw_';
  static const String _configKeyPrefix = 'encryption_chat_';
  static const String encryptedPrefix = 'kometSM.';

  static final Random _rand = Random.secure();

  static int _sumOfDigits(String text) {
    int sum = 0;
    for (var char in text.runes) {
      final charStr = String.fromCharCode(char);
      final digit = int.tryParse(charStr);
      if (digit != null) {
        sum += digit;
      }
    }
    return sum;
  }

  static int _calculateNoise(String text) {
    final hash = text.hashCode;
    return (hash.abs() % 3);
  }

  static bool isEncryptedMessage(String text) {
    if (text.isEmpty) return false;
    if (text.startsWith(encryptedPrefix)) return true;

    int prefixLength = 0;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (int.tryParse(char) != null) {
        prefixLength++;
      } else {
        break;
      }
    }

    if (prefixLength == 0) return false;
    if (text.length <= prefixLength) return false;
    return true;
  }

  
  
  
  static Future<ChatEncryptionConfig?> getConfigForChat(int chatId) async {
    final prefs = await SharedPreferences.getInstance();

    final configJson = prefs.getString('$_configKeyPrefix$chatId');
    if (configJson != null) {
      try {
        final data = jsonDecode(configJson) as Map<String, dynamic>;
        return ChatEncryptionConfig.fromJson(data);
      } catch (_) {
        
      }
    }

    
    final legacyPassword = prefs.getString('$_legacyPasswordKeyPrefix$chatId');
    if (legacyPassword != null && legacyPassword.isNotEmpty) {
      final legacyConfig = ChatEncryptionConfig(
        password: legacyPassword,
        sendEncrypted: true,
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

  
  static Future<void> setPasswordForChat(int chatId, String password) async {
    final current = await getConfigForChat(chatId);
    final updated = ChatEncryptionConfig(
      password: password,
      sendEncrypted: current?.sendEncrypted ?? true,
    );
    await _saveConfig(chatId, updated);
  }

  
  static Future<void> setSendEncryptedForChat(int chatId, bool enabled) async {
    final current = await getConfigForChat(chatId);
    final updated = ChatEncryptionConfig(
      password: current?.password ?? '',
      sendEncrypted: enabled,
    );
    await _saveConfig(chatId, updated);
  }

  
  static Future<String?> getPasswordForChat(int chatId) async {
    final cfg = await getConfigForChat(chatId);
    return cfg?.password;
  }

  
  static Future<bool> isSendEncryptedEnabled(int chatId) async {
    final cfg = await getConfigForChat(chatId);
    return cfg?.sendEncrypted ?? true;
  }

  
  
  
  static String encryptWithPassword(String password, String plaintext) {
    print('Шифрование: начинаем, plaintext: $plaintext');
    final salt = _randomBytes(8);
    final key = Uint8List.fromList(utf8.encode(password) + salt);

    final plainBytes = utf8.encode(plaintext);
    final cipherBytes = _xorWithKey(plainBytes, key);

    final payload = {'s': base64Encode(salt), 'c': base64Encode(cipherBytes)};

    final payloadJson = jsonEncode(payload);
    var payloadB64 = base64Encode(utf8.encode(payloadJson));
    print('Шифрование: base64 до замены: $payloadB64');

    payloadB64 = EncryptionCharMapping.replaceEnglishWithRussian(payloadB64);
    print('Шифрование: base64 после замены английских на русские: $payloadB64');

    payloadB64 = EncryptionCharMapping.replaceBase64SpecialChars(payloadB64);
    print('Шифрование: base64 после замены специальных символов: $payloadB64');

    final digitSum = _sumOfDigits(payloadB64);
    final noise = _calculateNoise(payloadB64);
    final prefix = digitSum + noise;
    print(
      'Шифрование: сумма цифр: $digitSum, погрешность: $noise, префикс: $prefix',
    );

    final result = '$prefix$payloadB64';
    print('Шифрование: итоговый результат: $result');
    return result;
  }

  
  
  static String? decryptWithPassword(String password, String text) {
    if (text.isEmpty) return null;

    String payloadB64;

    if (text.startsWith(encryptedPrefix)) {
      payloadB64 = text.substring(encryptedPrefix.length);
      print('Расшифровка: старый формат, payloadB64 до замены: $payloadB64');
      payloadB64 = EncryptionCharMapping.restoreBase64SpecialChars(payloadB64);
      print(
        'Расшифровка: старый формат, payloadB64 после восстановления специальных символов: $payloadB64',
      );
    } else {
      int prefixLength = 0;
      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        if (int.tryParse(char) != null) {
          prefixLength++;
        } else {
          break;
        }
      }

      if (prefixLength == 0) {
        print(
          'Расшифровка: не начинается с цифры, первый символ: ${text.isNotEmpty ? text[0] : "пусто"}',
        );
        return null;
      }

      payloadB64 = text.substring(prefixLength);
      print(
        'Расшифровка: новый формат, префикс длина: $prefixLength, payloadB64 до замены: $payloadB64',
      );
      payloadB64 = EncryptionCharMapping.restoreBase64SpecialChars(payloadB64);
      print(
        'Расшифровка: payloadB64 после восстановления специальных символов: $payloadB64',
      );
      payloadB64 = EncryptionCharMapping.replaceRussianWithEnglish(payloadB64);
      print(
        'Расшифровка: payloadB64 после замены русских на английские: $payloadB64',
      );
    }

    try {
      print('Расшифровка: пытаемся декодировать base64...');
      print(
        'Расшифровка: payloadB64 длина: ${payloadB64.length}, первые 50 символов: ${payloadB64.length > 50 ? payloadB64.substring(0, 50) : payloadB64}',
      );

      final decodedBytes = base64Decode(payloadB64);
      print(
        'Расшифровка: base64 декодирован в байты, длина: ${decodedBytes.length}',
      );

      final payloadJson = utf8.decode(decodedBytes);
      print(
        'Расшифровка: байты декодированы в UTF-8, payloadJson: $payloadJson',
      );

      final data = jsonDecode(payloadJson) as Map<String, dynamic>;
      print('Расшифровка: JSON распарсен, data: $data');

      final salt = base64Decode(data['s'] as String);
      final cipherBytes = base64Decode(data['c'] as String);
      print('Расшифровка: salt и cipherBytes получены');

      final key = Uint8List.fromList(utf8.encode(password) + salt);
      final plainBytes = _xorWithKey(cipherBytes, key);
      print('Расшифровка: XOR выполнен');

      final result = utf8.decode(plainBytes);
      print('Расшифровка: успешно, результат: $result');
      return result;
    } catch (e, stackTrace) {
      print('Расшифровка: ошибка - $e');
      print('StackTrace: $stackTrace');
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
