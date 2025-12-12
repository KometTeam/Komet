import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatReadSettings {
  final bool readOnAction; 
  final bool readOnEnter; 
  final bool disabled; 

  ChatReadSettings({
    this.readOnAction = true,
    this.readOnEnter = true,
    this.disabled = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'readOnAction': readOnAction,
      'readOnEnter': readOnEnter,
      'disabled': disabled,
    };
  }

  factory ChatReadSettings.fromJson(Map<String, dynamic> json) {
    return ChatReadSettings(
      readOnAction: json['readOnAction'] ?? true,
      readOnEnter: json['readOnEnter'] ?? true,
      disabled: json['disabled'] ?? false,
    );
  }

  ChatReadSettings copyWith({
    bool? readOnAction,
    bool? readOnEnter,
    bool? disabled,
  }) {
    return ChatReadSettings(
      readOnAction: readOnAction ?? this.readOnAction,
      readOnEnter: readOnEnter ?? this.readOnEnter,
      disabled: disabled ?? this.disabled,
    );
  }
}

class ChatReadSettingsService {
  static final ChatReadSettingsService instance = ChatReadSettingsService._();
  ChatReadSettingsService._();

  static const String _prefix = 'chat_read_settings_';

  Future<bool> hasCustomSettings(int chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$chatId';
      return prefs.containsKey(key);
    } catch (e) {
      return false;
    }
  }

  
  
  Future<ChatReadSettings?> getSettings(int chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$chatId';
      final jsonString = prefs.getString(key);

      if (jsonString == null) {
        return null;
      }

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ChatReadSettings.fromJson(json);
    } catch (e) {
      print('Ошибка загрузки настроек чтения для чата $chatId: $e');
      return null;
    }
  }

  
  Future<void> saveSettings(int chatId, ChatReadSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$chatId';
      final jsonString = jsonEncode(settings.toJson());
      await prefs.setString(key, jsonString);
    } catch (e) {
      print('Ошибка сохранения настроек чтения для чата $chatId: $e');
    }
  }

  
  Future<void> resetSettings(int chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefix$chatId';
      await prefs.remove(key);
    } catch (e) {
      print('Ошибка сброса настроек чтения для чата $chatId: $e');
    }
  }
}
