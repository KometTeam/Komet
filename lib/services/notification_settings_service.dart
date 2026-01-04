import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Типы чатов для настроек уведомлений
enum ChatType { private, group, channel }

/// Режим вибрации
enum VibrationMode { none, short, long }

/// Сервис для управления настройками уведомлений
class NotificationSettingsService {
  static final NotificationSettingsService _instance =
      NotificationSettingsService._internal();
  factory NotificationSettingsService() => _instance;
  NotificationSettingsService._internal();

  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyPrivateChatsEnabled = 'notifications_private_chats';
  static const String _keyGroupsEnabled = 'notifications_groups';
  static const String _keyChannelsEnabled = 'notifications_channels';
  static const String _keyReactionsEnabled = 'notifications_reactions';
  static const String _keyVibrationMode = 'notifications_vibration_mode';
  static const String _keyChatExceptions = 'notifications_chat_exceptions';

  // Константы по умолчанию
  static const VibrationMode _defaultVibrationMode = VibrationMode.short;

  /// Включены ли уведомления глобально
  Future<bool> areNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  /// Установить глобальное включение/выключение уведомлений
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
  }

  /// Включены ли уведомления для приватных чатов
  Future<bool> arePrivateChatsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyPrivateChatsEnabled) ?? true;
  }

  /// Установить уведомления для приватных чатов
  Future<void> setPrivateChatsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPrivateChatsEnabled, enabled);
  }

  /// Включены ли уведомления для групп
  Future<bool> areGroupsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGroupsEnabled) ?? true;
  }

  /// Установить уведомления для групп
  Future<void> setGroupsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGroupsEnabled, enabled);
  }

  /// Включены ли уведомления для каналов
  Future<bool> areChannelsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyChannelsEnabled) ?? true;
  }

  /// Установить уведомления для каналов
  Future<void> setChannelsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyChannelsEnabled, enabled);
  }

  /// Включены ли уведомления о реакциях
  Future<bool> areReactionsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyReactionsEnabled) ?? true;
  }

  /// Установить уведомления о реакциях
  Future<void> setReactionsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReactionsEnabled, enabled);
  }

  /// Получить режим вибрации
  Future<VibrationMode> getVibrationMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString(_keyVibrationMode);
    if (modeString == null) return _defaultVibrationMode;

    switch (modeString) {
      case 'none':
        return VibrationMode.none;
      case 'short':
        return VibrationMode.short;
      case 'long':
        return VibrationMode.long;
      default:
        return _defaultVibrationMode;
    }
  }

  /// Установить режим вибрации
  Future<void> setVibrationMode(VibrationMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVibrationMode, mode.name);
  }

  /// Получить список исключений чатов (chatId -> настройки)
  /// Возвращает Map<int, Map<String, dynamic>> где значения содержат:
  /// - 'enabled': bool - включены ли уведомления для этого чата
  /// - 'vibration': String - режим вибрации ('none'/'short'/'long')
  Future<Map<int, Map<String, dynamic>>> getChatExceptions() async {
    final prefs = await SharedPreferences.getInstance();
    final exceptionsJson = prefs.getString(_keyChatExceptions);
    if (exceptionsJson == null) return {};

    try {
      final decoded = json.decode(exceptionsJson) as Map<String, dynamic>;

      // Преобразуем ключи из String в int
      final result = <int, Map<String, dynamic>>{};
      decoded.forEach((key, value) {
        final chatId = int.tryParse(key);
        if (chatId != null && value is Map) {
          result[chatId] = Map<String, dynamic>.from(value);
        }
      });
      return result;
    } catch (e) {
      print('Ошибка парсинга исключений чатов: $e');
      return {};
    }
  }

  /// Установить исключения для конкретного чата
  Future<void> setChatException({
    required int chatId,
    required bool enabled,
    VibrationMode? vibration,
  }) async {
    final exceptions = await getChatExceptions();
    exceptions[chatId] = {
      'enabled': enabled,
      'vibration': vibration?.name ?? _defaultVibrationMode.name,
    };
    await _saveChatExceptions(exceptions);
  }

  /// Удалить исключение для чата (вернуться к настройкам по умолчанию)
  Future<void> removeChatException(int chatId) async {
    final exceptions = await getChatExceptions();
    exceptions.remove(chatId);
    await _saveChatExceptions(exceptions);
  }

  /// Получить настройки для конкретного чата (с учетом исключений)
  Future<Map<String, dynamic>> getSettingsForChat({
    required int chatId,
    required bool isGroupChat,
    required bool isChannel,
  }) async {
    // Проверяем исключения для этого чата
    final exceptions = await getChatExceptions();
    if (exceptions.containsKey(chatId)) {
      return exceptions[chatId]!;
    }

    // Если исключений нет, используем глобальные настройки
    final globalEnabled = await areNotificationsEnabled();
    if (!globalEnabled) {
      return {'enabled': false, 'vibration': VibrationMode.none.name};
    }

    // Проверяем настройки для типа чата
    bool typeEnabled;
    if (isChannel) {
      typeEnabled = await areChannelsEnabled();
    } else if (isGroupChat) {
      typeEnabled = await areGroupsEnabled();
    } else {
      typeEnabled = await arePrivateChatsEnabled();
    }

    final vibrationMode = await getVibrationMode();

    return {'enabled': typeEnabled, 'vibration': vibrationMode.name};
  }

  /// Проверить, должны ли показываться уведомления для чата
  Future<bool> shouldShowNotification({
    required int chatId,
    required bool isGroupChat,
    required bool isChannel,
  }) async {
    final settings = await getSettingsForChat(
      chatId: chatId,
      isGroupChat: isGroupChat,
      isChannel: isChannel,
    );
    return settings['enabled'] ?? false;
  }

  /// Сохранить все исключения чатов
  Future<void> _saveChatExceptions(
    Map<int, Map<String, dynamic>> exceptions,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Преобразуем ключи int в String для JSON
    final Map<String, dynamic> toSave = {};
    exceptions.forEach((key, value) {
      toSave[key.toString()] = value;
    });

    await prefs.setString(_keyChatExceptions, json.encode(toSave));
  }
}
