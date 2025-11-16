import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'connection/connection_manager.dart';
import 'connection/connection_logger.dart';
import 'connection/connection_state.dart';
import 'connection/health_monitor.dart';
import 'models/message.dart';
import 'models/contact.dart';
import 'image_cache_service.dart';
import 'services/cache_service.dart';
import 'services/avatar_cache_service.dart';
import 'services/chat_cache_service.dart';

class ApiServiceV2 {
  ApiServiceV2._privateConstructor();
  static final ApiServiceV2 instance = ApiServiceV2._privateConstructor();

  final ConnectionManager _connectionManager = ConnectionManager();

  final ConnectionLogger _logger = ConnectionLogger();

  String? _authToken;
  bool _isInitialized = false;
  bool _isAuthenticated = false;

  final Map<int, List<Message>> _messageCache = {};
  final Map<int, Contact> _contactCache = {};
  Map<String, dynamic>? _lastChatsPayload;
  DateTime? _lastChatsAt;
  final Duration _chatsCacheTtl = const Duration(seconds: 5);
  bool _chatsFetchedInThisSession = false;

  final Map<String, dynamic> _presenceData = {};

  final StreamController<Contact> _contactUpdatesController =
      StreamController<Contact>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Stream<Contact> get contactUpdates => _contactUpdatesController.stream;

  Stream<ConnectionInfo> get connectionState => _connectionManager.stateStream;

  Stream<LogEntry> get logs => _connectionManager.logStream;

  Stream<HealthMetrics> get healthMetrics =>
      _connectionManager.healthMetricsStream;

  ConnectionInfo get currentConnectionState => _connectionManager.currentState;

  bool get isOnline => _connectionManager.isConnected;

  bool get canSendMessages => _connectionManager.canSendMessages;

  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.logConnection('ApiServiceV2 уже инициализирован');
      return;
    }

    _logger.logConnection('Инициализация ApiServiceV2');

    try {
      await _connectionManager.initialize();
      _setupMessageHandlers();

      _isAuthenticated = false;

      _isInitialized = true;

      _logger.logConnection('ApiServiceV2 успешно инициализирован');
    } catch (e) {
      _logger.logError('Ошибка инициализации ApiServiceV2', error: e);
      rethrow;
    }
  }

  void _setupMessageHandlers() {
    _connectionManager.messageStream.listen((message) {
      _handleIncomingMessage(message);
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    try {
      _logger.logMessage('IN', message);

      if (message['opcode'] == 19 &&
          message['cmd'] == 1 &&
          message['payload'] != null) {
        _isAuthenticated = true;
        _logger.logConnection('Аутентификация успешна');
      }

      if (message['opcode'] == 128 && message['payload'] != null) {
        _handleContactUpdate(message['payload']);
      }

      if (message['opcode'] == 129 && message['payload'] != null) {
        _handlePresenceUpdate(message['payload']);
      }

      _messageController.add(message);
    } catch (e) {
      _logger.logError(
        'Ошибка обработки входящего сообщения',
        data: {'message': message, 'error': e.toString()},
      );
    }
  }

  void _handleContactUpdate(Map<String, dynamic> payload) {
    try {
      final contact = Contact.fromJson(payload);
      _contactCache[contact.id] = contact;
      _contactUpdatesController.add(contact);

      _logger.logConnection(
        'Контакт обновлен',
        data: {'contact_id': contact.id, 'contact_name': contact.name},
      );
    } catch (e) {
      _logger.logError(
        'Ошибка обработки обновления контакта',
        data: {'payload': payload, 'error': e.toString()},
      );
    }
  }

  void _handlePresenceUpdate(Map<String, dynamic> payload) {
    try {
      _presenceData.addAll(payload);
      _logger.logConnection(
        'Presence данные обновлены',
        data: {'keys': payload.keys.toList()},
      );
    } catch (e) {
      _logger.logError(
        'Ошибка обработки presence данных',
        data: {'payload': payload, 'error': e.toString()},
      );
    }
  }

  Future<void> connect() async {
    _logger.logConnection('Запрос подключения к серверу');

    try {
      await _connectionManager.connect(authToken: _authToken);
      _logger.logConnection('Подключение к серверу успешно');
    } catch (e) {
      _logger.logError('Ошибка подключения к серверу', error: e);
      rethrow;
    }
  }

  Future<void> reconnect() async {
    _logger.logConnection('Запрос переподключения');

    try {
      await _connectionManager.connect(authToken: _authToken);
      _logger.logConnection('Переподключение успешно');
    } catch (e) {
      _logger.logError('Ошибка переподключения', error: e);
      rethrow;
    }
  }

  Future<void> forceReconnect() async {
    _logger.logConnection('Принудительное переподключение');

    try {
      _isAuthenticated = false;

      await _connectionManager.forceReconnect();
      _logger.logConnection('Принудительное переподключение успешно');

      await _performFullAuthenticationSequence();
    } catch (e) {
      _logger.logError('Ошибка принудительного переподключения', error: e);
      rethrow;
    }
  }

  Future<void> _performFullAuthenticationSequence() async {
    _logger.logConnection(
      'Выполнение полной последовательности аутентификации',
    );

    try {
      await _waitForConnectionReady();

      await _sendAuthenticationToken();

      await _waitForAuthenticationConfirmation();

      await _sendPingToConfirmSession();

      await _requestChatsAndContacts();

      _logger.logConnection(
        'Полная последовательность аутентификации завершена',
      );
    } catch (e) {
      _logger.logError('Ошибка в последовательности аутентификации', error: e);
      rethrow;
    }
  }

  Future<void> _waitForConnectionReady() async {
    const maxWaitTime = Duration(seconds: 30);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      if (_connectionManager.currentState.isActive) {
        await Future.delayed(const Duration(milliseconds: 500));
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    throw Exception('Таймаут ожидания готовности соединения');
  }

  Future<void> _sendAuthenticationToken() async {
    if (_authToken == null) {
      _logger.logError('Токен аутентификации отсутствует');
      return;
    }

    _logger.logConnection('Отправка токена аутентификации');

    final payload = {
      "interactive": true,
      "token": _authToken,
      "chatsCount": 100,
      "userAgent": {
        "deviceType": "DESKTOP",
        "locale": "ru",
        "deviceLocale": "ru",
        "osVersion": "Windows",
        "deviceName": "Chrome",
        "headerUserAgent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "appVersion": "1.0.0",
        "screen": "2560x1440 1.0x",
        "timezone": "Europe/Moscow",
      },
    };

    _connectionManager.sendMessage(19, payload);

    await _waitForAuthenticationConfirmation();
  }

  Future<void> _waitForAuthenticationConfirmation() async {
    const maxWaitTime = Duration(seconds: 10);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      if (_connectionManager.currentState.isActive && _isAuthenticated) {
        _logger.logConnection('Аутентификация подтверждена');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    throw Exception('Таймаут ожидания подтверждения аутентификации');
  }

  Future<void> _sendPingToConfirmSession() async {
    _logger.logConnection('Отправка ping для подтверждения готовности сессии');

    final payload = {"interactive": true};
    _connectionManager.sendMessage(1, payload);

    await Future.delayed(const Duration(milliseconds: 500));

    _logger.logConnection('Ping отправлен, сессия готова');
  }

  Future<void> _waitForSessionReady() async {
    const maxWaitTime = Duration(seconds: 30);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < maxWaitTime) {
      if (canSendMessages && _isAuthenticated) {
        _logger.logConnection('Сессия готова для отправки сообщений');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    throw Exception('Таймаут ожидания готовности сессии');
  }

  Future<void> _requestChatsAndContacts() async {
    _logger.logConnection('Запрос чатов и контактов');

    final chatsPayload = {"chatsCount": 100};

    _connectionManager.sendMessage(48, chatsPayload);

    final contactsPayload = {"status": "BLOCKED", "count": 100, "from": 0};

    _connectionManager.sendMessage(36, contactsPayload);
  }

  Future<void> disconnect() async {
    _logger.logConnection('Отключение от сервера');

    try {
      await _connectionManager.disconnect();
      _logger.logConnection('Отключение от сервера успешно');
    } catch (e) {
      _logger.logError('Ошибка отключения', error: e);
    }
  }

  int _sendMessage(int opcode, Map<String, dynamic> payload) {
    if (!canSendMessages) {
      _logger.logConnection(
        'Сообщение не отправлено - соединение не готово',
        data: {'opcode': opcode, 'payload': payload},
      );
      return -1;
    }

    if (_requiresAuthentication(opcode) && !_isAuthenticated) {
      _logger.logConnection(
        'Сообщение не отправлено - требуется аутентификация',
        data: {'opcode': opcode, 'payload': payload},
      );
      return -1;
    }

    try {
      final seq = _connectionManager.sendMessage(opcode, payload);
      _logger.logConnection(
        'Сообщение отправлено',
        data: {'opcode': opcode, 'seq': seq, 'payload': payload},
      );
      return seq;
    } catch (e) {
      _logger.logError(
        'Ошибка отправки сообщения',
        data: {'opcode': opcode, 'payload': payload, 'error': e.toString()},
      );
      return -1;
    }
  }

  bool _requiresAuthentication(int opcode) {
    const authRequiredOpcodes = {
      19, // Аутентификация
      32, // Получение контактов
      36, // Получение заблокированных контактов
      48, // Получение чатов
      49, // Получение истории сообщений
      64, // Отправка сообщений
      65, // Статус набора
      66, // Удаление сообщений
      67, // Редактирование сообщений
      77, // Управление участниками группы
      78, // Управление участниками группы
      80, // Загрузка файлов
      178, // Отправка реакций
      179, // Удаление реакций
    };

    return authRequiredOpcodes.contains(opcode);
  }

  Future<void> sendHandshake() async {
    _logger.logConnection('Отправка handshake');

    final payload = {
      "userAgent": {
        "deviceType": "WEB",
        "locale": "ru",
        "deviceLocale": "ru",
        "osVersion": "Windows",
        "deviceName": "Chrome",
        "headerUserAgent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "appVersion": "25.9.15",
        "screen": "1920x1080 1.0x",
        "timezone": "Europe/Moscow",
      },
      "deviceId": _generateDeviceId(),
    };

    _sendMessage(6, payload);
  }

  void requestOtp(String phoneNumber) {
    _logger.logConnection('Запрос OTP', data: {'phone': phoneNumber});

    final payload = {
      "phone": phoneNumber,
      "type": "START_AUTH",
      "language": "ru",
    };
    _sendMessage(17, payload);
  }

  void verifyCode(String token, String code) {
    _logger.logConnection(
      'Проверка кода',
      data: {'token': token, 'code': code},
    );

    final payload = {
      "token": token,
      "verifyCode": code,
      "authTokenType": "CHECK_CODE",
    };
    _sendMessage(18, payload);
  }

  Future<Map<String, dynamic>> authenticateWithToken(String token) async {
    _logger.logConnection('Аутентификация с токеном');

    _authToken = token;
    await saveToken(token);

    final payload = {"interactive": true, "token": token, "chatsCount": 100};

    final seq = _sendMessage(19, payload);

    try {
      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 30));

      _logger.logConnection(
        'Аутентификация успешна',
        data: {'seq': seq, 'response_cmd': response['cmd']},
      );

      return response['payload'] ?? {};
    } catch (e) {
      _logger.logError(
        'Ошибка аутентификации',
        data: {'token': token, 'error': e.toString()},
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getChatsAndContacts({bool force = false}) async {
    _logger.logConnection('Запрос чатов и контактов', data: {'force': force});

    if (!force && _lastChatsPayload != null && _lastChatsAt != null) {
      if (DateTime.now().difference(_lastChatsAt!) < _chatsCacheTtl) {
        _logger.logConnection('Возвращаем данные из локального кэша');
        return _lastChatsPayload!;
      }
    }

    if (!force) {
      final chatService = ChatCacheService();
      final cachedChats = await chatService.getCachedChats();
      final cachedContacts = await chatService.getCachedContacts();

      if (cachedChats != null &&
          cachedContacts != null &&
          cachedChats.isNotEmpty) {
        _logger.logConnection('Возвращаем данные из сервиса кэша');
        final result = {
          'chats': cachedChats,
          'contacts': cachedContacts
              .map(
                (contact) => {
                  'id': contact.id,
                  'name': contact.name,
                  'firstName': contact.firstName,
                  'lastName': contact.lastName,
                  'photoBaseUrl': contact.photoBaseUrl,
                  'isBlocked': contact.isBlocked,
                  'isBlockedByMe': contact.isBlockedByMe,
                  'accountStatus': contact.accountStatus,
                  'status': contact.status,
                },
              )
              .toList(),
          'profile': null,
          'presence': null,
        };

        _lastChatsPayload = result;
        _lastChatsAt = DateTime.now();
        _chatsFetchedInThisSession = true;

        return result;
      }
    }

    await _waitForSessionReady();

    try {
      final payload = {"chatsCount": 100};
      final seq = _sendMessage(48, payload);

      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 30));

      final List<dynamic> chatListJson = response['payload']?['chats'] ?? [];

      if (chatListJson.isEmpty) {
        final result = {'chats': [], 'contacts': [], 'profile': null};
        _lastChatsPayload = result;
        _lastChatsAt = DateTime.now();
        return result;
      }

      final contactIds = <int>{};
      for (var chatJson in chatListJson) {
        final participants =
            chatJson['participants'] as Map<String, dynamic>? ?? {};
        contactIds.addAll(participants.keys.map((id) => int.parse(id)));
      }

      final contactSeq = _sendMessage(32, {"contactIds": contactIds.toList()});

      final contactResponse = await messages
          .firstWhere((msg) => msg['seq'] == contactSeq)
          .timeout(const Duration(seconds: 30));

      final List<dynamic> contactListJson =
          contactResponse['payload']?['contacts'] ?? [];

      final result = {
        'chats': chatListJson,
        'contacts': contactListJson,
        'profile': null,
        'presence': null,
      };

      _lastChatsPayload = result;
      _lastChatsAt = DateTime.now();
      _chatsFetchedInThisSession = true;

      final contacts = contactListJson
          .map((json) => Contact.fromJson(json))
          .toList();
      updateContactCache(contacts);

      final chatService = ChatCacheService();
      await chatService.cacheChats(chatListJson.cast<Map<String, dynamic>>());
      await chatService.cacheContacts(contacts);

      _preloadContactAvatars(contacts);

      _logger.logConnection(
        'Чаты и контакты получены',
        data: {
          'chats_count': chatListJson.length,
          'contacts_count': contactListJson.length,
        },
      );

      return result;
    } catch (e) {
      _logger.logError('Ошибка получения чатов и контактов', error: e);
      rethrow;
    }
  }

  Future<List<Message>> getMessageHistory(
    int chatId, {
    bool force = false,
  }) async {
    _logger.logConnection(
      'Запрос истории сообщений',
      data: {'chat_id': chatId, 'force': force},
    );

    if (!force && _messageCache.containsKey(chatId)) {
      _logger.logConnection('История сообщений загружена из локального кэша');
      return _messageCache[chatId]!;
    }

    if (!force) {
      final chatService = ChatCacheService();
      final cachedMessages = await chatService.getCachedChatMessages(chatId);

      if (cachedMessages != null && cachedMessages.isNotEmpty) {
        _logger.logConnection('История сообщений загружена из сервиса кэша');
        _messageCache[chatId] = cachedMessages;
        return cachedMessages;
      }
    }

    await _waitForSessionReady();

    try {
      final payload = {
        "chatId": chatId,
        "from": DateTime.now()
            .add(const Duration(days: 1))
            .millisecondsSinceEpoch,
        "forward": 0,
        "backward": 1000,
        "getMessages": true,
      };

      final seq = _sendMessage(49, payload);

      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 30));

      if (response['cmd'] == 3) {
        final error = response['payload'];
        _logger.logError(
          'Ошибка получения истории сообщений',
          data: {'chat_id': chatId, 'error': error},
        );
        throw Exception('Ошибка получения истории: ${error['message']}');
      }

      final List<dynamic> messagesJson = response['payload']?['messages'] ?? [];
      final messagesList =
          messagesJson.map((json) => Message.fromJson(json)).toList()
            ..sort((a, b) => a.time.compareTo(b.time));

      _messageCache[chatId] = messagesList;

      final chatService = ChatCacheService();
      await chatService.cacheChatMessages(chatId, messagesList);

      _preloadMessageImages(messagesList);

      _logger.logConnection(
        'История сообщений получена',
        data: {'chat_id': chatId, 'messages_count': messagesList.length},
      );

      return messagesList;
    } catch (e) {
      _logger.logError(
        'Ошибка получения истории сообщений',
        data: {'chat_id': chatId, 'error': e.toString()},
      );
      return [];
    }
  }

  void sendMessage(int chatId, String text, {String? replyToMessageId}) {
    _logger.logConnection(
      'Отправка сообщения',
      data: {
        'chat_id': chatId,
        'text_length': text.length,
        'reply_to': replyToMessageId,
      },
    );

    final int clientMessageId = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      "chatId": chatId,
      "message": {
        "text": text,
        "cid": clientMessageId,
        "elements": [],
        "attaches": [],
        if (replyToMessageId != null)
          "link": {"type": "REPLY", "messageId": replyToMessageId},
      },
      "notify": true,
    };

    clearChatsCache();
    _sendMessage(64, payload);
  }

  void forwardMessage(int targetChatId, String messageId, int sourceChatId) {
    _logger.logConnection(
      'Пересылка сообщения',
      data: {
        'target_chat_id': targetChatId,
        'message_id': messageId,
        'source_chat_id': sourceChatId,
      },
    );

    final int clientMessageId = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      "chatId": targetChatId,
      "message": {
        "cid": clientMessageId,
        "link": {
          "type": "FORWARD",
          "messageId": messageId,
          "chatId": sourceChatId,
        },
        "attaches": [],
      },
      "notify": true,
    };

    _sendMessage(64, payload);
  }

  Future<void> sendPhotoMessage(
    int chatId, {
    String? localPath,
    String? caption,
    int? cidOverride,
    int? senderId,
  }) async {
    _logger.logConnection(
      'Отправка фото',
      data: {'chat_id': chatId, 'local_path': localPath, 'caption': caption},
    );

    try {
      XFile? image;
      if (localPath != null) {
        image = XFile(localPath);
      } else {
        final picker = ImagePicker();
        image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
      }

      final seq80 = _sendMessage(80, {"count": 1});
      final resp80 = await messages
          .firstWhere((m) => m['seq'] == seq80)
          .timeout(const Duration(seconds: 30));

      final String uploadUrl = resp80['payload']['url'];

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var streamed = await request.send();
      var httpResp = await http.Response.fromStream(streamed);

      if (httpResp.statusCode != 200) {
        throw Exception(
          'Ошибка загрузки фото: ${httpResp.statusCode} ${httpResp.body}',
        );
      }

      final uploadJson = jsonDecode(httpResp.body) as Map<String, dynamic>;
      final Map photos = uploadJson['photos'] as Map;
      if (photos.isEmpty) throw Exception('Не получен токен фото');
      final String photoToken = (photos.values.first as Map)['token'];

      final int cid = cidOverride ?? DateTime.now().millisecondsSinceEpoch;
      final payload = {
        "chatId": chatId,
        "message": {
          "text": caption?.trim() ?? "",
          "cid": cid,
          "elements": [],
          "attaches": [
            {"_type": "PHOTO", "photoToken": photoToken},
          ],
        },
        "notify": true,
      };

      clearChatsCache();
      _sendMessage(64, payload);

      _logger.logConnection(
        'Фото отправлено',
        data: {'chat_id': chatId, 'photo_token': photoToken},
      );
    } catch (e) {
      _logger.logError(
        'Ошибка отправки фото',
        data: {'chat_id': chatId, 'error': e.toString()},
      );
    }
  }

  Future<void> blockContact(int contactId) async {
    _logger.logConnection(
      'Блокировка контакта',
      data: {'contact_id': contactId},
    );
    _sendMessage(34, {'contactId': contactId, 'action': 'BLOCK'});
  }

  Future<void> unblockContact(int contactId) async {
    _logger.logConnection(
      'Разблокировка контакта',
      data: {'contact_id': contactId},
    );
    _sendMessage(34, {'contactId': contactId, 'action': 'UNBLOCK'});
  }

  void getBlockedContacts() {
    _logger.logConnection('Запрос заблокированных контактов');
    _sendMessage(36, {'status': 'BLOCKED', 'count': 100, 'from': 0});
  }

  void createGroup(String name, List<int> participantIds) {
    _logger.logConnection(
      'Создание группы',
      data: {'name': name, 'participants': participantIds},
    );

    final payload = {"name": name, "participantIds": participantIds};
    _sendMessage(48, payload);
  }

  void addGroupMember(
    int chatId,
    List<int> userIds, {
    bool showHistory = true,
  }) {
    _logger.logConnection(
      'Добавление участника в группу',
      data: {'chat_id': chatId, 'user_ids': userIds},
    );

    final payload = {
      "chatId": chatId,
      "userIds": userIds,
      "showHistory": showHistory,
      "operation": "add",
    };
    _sendMessage(77, payload);
  }

  void removeGroupMember(
    int chatId,
    List<int> userIds, {
    int cleanMsgPeriod = 0,
  }) {
    _logger.logConnection(
      'Удаление участника из группы',
      data: {'chat_id': chatId, 'user_ids': userIds},
    );

    final payload = {
      "chatId": chatId,
      "userIds": userIds,
      "operation": "remove",
      "cleanMsgPeriod": cleanMsgPeriod,
    };
    _sendMessage(77, payload);
  }

  void leaveGroup(int chatId) {
    _logger.logConnection('Выход из группы', data: {'chat_id': chatId});
    _sendMessage(58, {"chatId": chatId});
  }

  void sendReaction(int chatId, String messageId, String emoji) {
    _logger.logConnection(
      'Отправка реакции',
      data: {'chat_id': chatId, 'message_id': messageId, 'emoji': emoji},
    );

    final payload = {
      "chatId": chatId,
      "messageId": messageId,
      "reaction": {"reactionType": "EMOJI", "id": emoji},
    };
    _sendMessage(178, payload);
  }

  void removeReaction(int chatId, String messageId) {
    _logger.logConnection(
      'Удаление реакции',
      data: {'chat_id': chatId, 'message_id': messageId},
    );

    final payload = {"chatId": chatId, "messageId": messageId};
    _sendMessage(179, payload);
  }

  void sendTyping(int chatId, {String type = "TEXT"}) {
    final payload = {"chatId": chatId, "type": type};
    _sendMessage(65, payload);
  }

  DateTime? getLastSeen(int userId) {
    final userPresence = _presenceData[userId.toString()];
    if (userPresence != null && userPresence['seen'] != null) {
      final seenTimestamp = userPresence['seen'] as int;
      return DateTime.fromMillisecondsSinceEpoch(seenTimestamp * 1000);
    }
    return null;
  }

  void updateContactCache(List<Contact> contacts) {
    _contactCache.clear();
    for (final contact in contacts) {
      _contactCache[contact.id] = contact;
    }
    _logger.logConnection(
      'Кэш контактов обновлен',
      data: {'contacts_count': contacts.length},
    );
  }

  Contact? getCachedContact(int contactId) {
    return _contactCache[contactId];
  }

  void clearChatsCache() {
    _lastChatsPayload = null;
    _lastChatsAt = null;
    _chatsFetchedInThisSession = false;
    _logger.logConnection('Кэш чатов очищен');
  }

  void clearMessageCache(int chatId) {
    _messageCache.remove(chatId);
    _logger.logConnection('Кэш сообщений очищен', data: {'chat_id': chatId});
  }

  Future<void> clearAllCaches() async {
    _messageCache.clear();
    _contactCache.clear();
    clearChatsCache();

    try {
      await CacheService().clear();
      await AvatarCacheService().clearAvatarCache();
      await ChatCacheService().clearAllChatCache();
    } catch (e) {
      _logger.logError('Ошибка очистки сервисов кеширования', error: e);
    }

    _logger.logConnection('Все кэши очищены');
  }

  Future<void> saveToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('authToken', token);

    _logger.logConnection('Токен сохранен');
  }

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('authToken');
    return _authToken != null;
  }

  Future<void> logout() async {
    _logger.logConnection('Выход из системы');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      _authToken = null;
      clearAllCaches();
      await disconnect();
      _logger.logConnection('Выход из системы выполнен');
    } catch (e) {
      _logger.logError('Ошибка при выходе из системы', error: e);
    }
  }

  Future<void> _preloadContactAvatars(List<Contact> contacts) async {
    try {
      final avatarUrls = contacts
          .map((contact) => contact.photoBaseUrl)
          .where((url) => url != null && url.isNotEmpty)
          .toList();

      if (avatarUrls.isNotEmpty) {
        _logger.logConnection(
          'Предзагрузка аватарок контактов',
          data: {'count': avatarUrls.length},
        );

        await ImageCacheService.instance.preloadContactAvatars(avatarUrls);
      }
    } catch (e) {
      _logger.logError('Ошибка предзагрузки аватарок контактов', error: e);
    }
  }

  Future<void> _preloadMessageImages(List<Message> messages) async {
    try {
      final imageUrls = <String>[];

      for (final message in messages) {
        for (final attach in message.attaches) {
          if (attach['_type'] == 'PHOTO' || attach['_type'] == 'SHARE') {
            final url = attach['url'] ?? attach['baseUrl'];
            if (url is String && url.isNotEmpty) {
              imageUrls.add(url);
            }
          }
        }
      }

      if (imageUrls.isNotEmpty) {
        _logger.logConnection(
          'Предзагрузка изображений из сообщений',
          data: {'count': imageUrls.length},
        );

        await ImageCacheService.instance.preloadContactAvatars(imageUrls);
      }
    } catch (e) {
      _logger.logError(
        'Ошибка предзагрузки изображений из сообщений',
        error: e,
      );
    }
  }

  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return "$timestamp$random";
  }

  Future<Map<String, dynamic>> getStatistics() async {
    final imageCacheStats = await ImageCacheService.instance.getCacheStats();
    final cacheServiceStats = await CacheService().getCacheStats();
    final avatarCacheStats = await AvatarCacheService().getAvatarCacheStats();
    final chatCacheStats = await ChatCacheService().getChatCacheStats();

    return {
      'api_service': {
        'is_initialized': _isInitialized,
        'has_auth_token': _authToken != null,
        'message_cache_size': _messageCache.length,
        'contact_cache_size': _contactCache.length,
        'chats_fetched_in_session': _chatsFetchedInThisSession,
      },
      'connection': _connectionManager.getStatistics(),
      'cache_service': cacheServiceStats,
      'avatar_cache': avatarCacheStats,
      'chat_cache': chatCacheStats,
      'image_cache': imageCacheStats,
    };
  }

  void dispose() {
    _logger.logConnection('Освобождение ресурсов ApiServiceV2');
    _connectionManager.dispose();
    _messageController.close();
    _contactUpdatesController.close();
  }
}
