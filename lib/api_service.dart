import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:gwid/models/message.dart';
import 'package:gwid/models/contact.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:gwid/spoofing_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:gwid/proxy_service.dart';
import 'package:file_picker/file_picker.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  int? _userId;
  late int _sessionId;
  int _actionId = 1;
  bool _isColdStartSent = false;
  late int _lastActionTime;

  bool _isAppInForeground = true;

  final List<String> _wsUrls = ['wss://ws-api.oneme.ru:443/websocket'];
  int _currentUrlIndex = 0;

  List<String> get wsUrls => _wsUrls;
  int get currentUrlIndex => _currentUrlIndex;
  IOWebSocketChannel? _channel;
  StreamSubscription? _streamSubscription;
  Timer? _pingTimer;
  int _seq = 0;

  final StreamController<Contact> _contactUpdatesController =
      StreamController<Contact>.broadcast();
  Stream<Contact> get contactUpdates => _contactUpdatesController.stream;

  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  final _reconnectionCompleteController = StreamController<void>.broadcast();
  Stream<void> get reconnectionComplete =>
      _reconnectionCompleteController.stream;

  final Map<String, dynamic> _presenceData = {};
  String? authToken;
  String? userId;

  String? get token => authToken;

  String? _currentPasswordTrackId;
  String? _currentPasswordHint;
  String? _currentPasswordEmail;

  bool _isSessionOnline = false;
  bool _handshakeSent = false;
  Completer<void>? _onlineCompleter;
  final List<Map<String, dynamic>> _messageQueue = [];

  final Map<int, List<Message>> _messageCache = {};

  final Map<int, Contact> _contactCache = {};
  DateTime? _lastContactsUpdate;
  static const Duration _contactCacheExpiry = Duration(
    minutes: 5,
  ); // Кэш на 5 минут

  bool _isLoadingBlockedContacts = false;

  bool _isSessionReady = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  final _connectionStatusController = StreamController<String>.broadcast();
  Stream<String> get connectionStatus => _connectionStatusController.stream;

  final _connectionLogController = StreamController<String>.broadcast();
  Stream<String> get connectionLog => _connectionLogController.stream;

  final List<String> _connectionLogCache = [];
  List<String> get connectionLogCache => _connectionLogCache;

  void _log(String message) {
    print(message); // Оставляем для дебага в консоли
    _connectionLogCache.add(message);
    if (!_connectionLogController.isClosed) {
      _connectionLogController.add(message);
    }
  }

  void _emitLocal(Map<String, dynamic> frame) {
    try {
      _messageController.add(frame);
    } catch (_) {}
  }

  bool get isOnline => _isSessionOnline;
  Future<void> waitUntilOnline() async {
    if (_isSessionOnline && _isSessionReady) return;
    _onlineCompleter ??= Completer<void>();
    return _onlineCompleter!.future;
  }

  bool get isActuallyConnected {
    try {
      if (_channel == null || !_isSessionOnline) {
        return false;
      }

      return true;
    } catch (e) {
      print("🔴 Ошибка при проверке состояния канала: $e");
      return false;
    }
  }

  Completer<Map<String, dynamic>>? _inflightChatsCompleter;
  Map<String, dynamic>? _lastChatsPayload;
  DateTime? _lastChatsAt;
  final Duration _chatsCacheTtl = const Duration(seconds: 5);
  bool _chatsFetchedInThisSession = false;

  Map<String, dynamic>? get lastChatsPayload => _lastChatsPayload;

  Future<void> _connectWithFallback() async {
    _log('Начало подключения...');

    while (_currentUrlIndex < _wsUrls.length) {
      final currentUrl = _wsUrls[_currentUrlIndex];
      final logMessage =
          'Попытка ${_currentUrlIndex + 1}/${_wsUrls.length}: $currentUrl';
      _log(logMessage);
      _connectionLogController.add(logMessage);

      try {
        await _connectToUrl(currentUrl);
        final successMessage = _currentUrlIndex == 0
            ? 'Подключено к основному серверу'
            : 'Подключено через резервный сервер';
        _connectionLogController.add('✅ $successMessage');
        if (_currentUrlIndex > 0) {
          _connectionStatusController.add('Подключено через резервный сервер');
        }
        return; // Успешно подключились
      } catch (e) {
        final errorMessage = '❌ Ошибка: ${e.toString().split(':').first}';
        print('Ошибка подключения к $currentUrl: $e');
        _connectionLogController.add(errorMessage);
        _currentUrlIndex++;

        if (_currentUrlIndex < _wsUrls.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    _log('❌ Все серверы недоступны');
    _connectionStatusController.add('Все серверы недоступны');
    throw Exception('Не удалось подключиться ни к одному серверу');
  }

  Future<void> _connectToUrl(String url) async {
    _isSessionOnline = false;
    _onlineCompleter = Completer<void>();
    _chatsFetchedInThisSession = false;

    _connectionStatusController.add('connecting');

    final uri = Uri.parse(url);
    print(
      'Parsed URI: host=${uri.host}, port=${uri.port}, scheme=${uri.scheme}',
    );

    final spoofedData = await SpoofingService.getSpoofedSessionData();
    final userAgent =
        spoofedData?['useragent'] as String? ??
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

    final headers = <String, String>{
      'Origin': 'https://web.max.ru',
      'User-Agent': userAgent,
      'Sec-WebSocket-Extensions': 'permessage-deflate',
    };

    final proxySettings = await ProxyService.instance.loadProxySettings();

    if (proxySettings.isEnabled && proxySettings.host.isNotEmpty) {
      print(
        'Используем HTTP/HTTPS прокси ${proxySettings.host}:${proxySettings.port}',
      );
      final customHttpClient = await ProxyService.instance
          .getHttpClientWithProxy();
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: headers,
        customClient: customHttpClient,
      );
    } else {
      print('Подключение без прокси');
      _channel = IOWebSocketChannel.connect(uri, headers: headers);
    }

    await _channel!.ready;
    _listen();
    await _sendHandshake();
    _startPinging();
  }

  int _reconnectDelaySeconds = 2;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  String generateRandomDeviceId() {
    return const Uuid().v4();
  }

  Future<Map<String, dynamic>> _buildUserAgentPayload() async {
    final spoofedData = await SpoofingService.getSpoofedSessionData();

    if (spoofedData != null) {
      print(
        '--- [_buildUserAgentPayload] Используются подменённые данные сессии ---',
      );
      final String finalDeviceId;
      final String? idFromSpoofing = spoofedData['device_id'] as String?;

      if (idFromSpoofing != null && idFromSpoofing.isNotEmpty) {
        finalDeviceId = idFromSpoofing;
        print('Используется deviceId из сессии: $finalDeviceId');
      } else {
        finalDeviceId = generateRandomDeviceId();
        print('device_id не найден в кэше, сгенерирован новый: $finalDeviceId');
      }
      return {
        'deviceType': spoofedData['device_type'] as String? ?? 'IOS',
        'locale': spoofedData['locale'] as String? ?? 'ru',
        'deviceLocale': spoofedData['locale'] as String? ?? 'ru',
        'osVersion': spoofedData['os_version'] as String? ?? 'iOS 17.5.1',
        'deviceName': spoofedData['device_name'] as String? ?? 'iPhone',
        'headerUserAgent':
            spoofedData['user_agent'] as String? ??
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
        'appVersion': spoofedData['app_version'] as String? ?? '25.10.10',
        'screen': spoofedData['screen'] as String? ?? '1170x2532 3.0x',
        'timezone': spoofedData['timezone'] as String? ?? 'Europe/Moscow',
      };
    } else {
      print(
        '--- [_buildUserAgentPayload] Используются псевдо-случайные данные ---',
      );
      return {
        'deviceType': 'WEB',
        'locale': 'ru',
        'deviceLocale': 'ru',
        'osVersion': 'Windows',
        'deviceName': 'Chrome',
        'headerUserAgent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'appVersion': '25.10.10',
        'screen': '1920x1080 1.0x',
        'timezone': 'Europe/Moscow',
      };
    }
  }

  void _handleSessionTerminated() {
    print("Сессия была завершена сервером");
    _isSessionOnline = false;
    _isSessionReady = false;

    authToken = null;

    clearAllCaches();

    _messageController.add({
      'type': 'session_terminated',
      'message': 'Твоя сессия больше не активна, войди снова',
    });
  }

  void _handleInvalidToken() async {
    print("Обработка недействительного токена");
    _isSessionOnline = false;
    _isSessionReady = false;

    authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');

    clearAllCaches();

    _channel?.sink.close();
    _channel = null;
    _pingTimer?.cancel();

    _messageController.add({
      'type': 'invalid_token',
      'message': 'Токен недействителен, требуется повторная авторизация',
    });
  }

  Future<void> _clearAuthToken() async {
    print("Очищаем токен авторизации...");
    authToken = null;
    _lastChatsPayload = null;
    _lastChatsAt = null;
    _chatsFetchedInThisSession = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');

    clearAllCaches();
    _connectionStatusController.add("disconnected");
  }

  Future<void> _sendHandshake() async {
    if (_handshakeSent) {
      print('Handshake уже отправлен, пропускаем...');
      return;
    }

    print('Отправляем handshake...');

    final userAgentPayload = await _buildUserAgentPayload();

    final prefs = await SharedPreferences.getInstance();
    final deviceId =
        prefs.getString('spoof_deviceid') ?? generateRandomDeviceId();

    if (prefs.getString('spoof_deviceid') == null) {
      await prefs.setString('spoof_deviceid', deviceId);
    }

    final payload = {'deviceId': deviceId, 'userAgent': userAgentPayload};

    print('Отправляем handshake с payload: $payload');
    _sendMessage(6, payload);
    _handshakeSent = true;
    print('Handshake отправлен, ожидаем ответ...');
  }

  Future<void> requestOtp(String phoneNumber) async {
    if (_channel == null) {
      print('WebSocket не подключен, подключаемся...');
      try {
        await connect();

        await waitUntilOnline();
      } catch (e) {
        print('Ошибка подключения к WebSocket: $e');
        throw Exception('Не удалось подключиться к серверу: $e');
      }
    }

    final payload = {
      "phone": phoneNumber,
      "type": "START_AUTH",
      "language": "ru",
    };
    _sendMessage(17, payload);
  }

  void requestSessions() {
    _sendMessage(96, {});
  }

  void terminateAllSessions() {
    _sendMessage(97, {});
  }

  Future<void> blockContact(int contactId) async {
    await waitUntilOnline();
    _sendMessage(34, {'contactId': contactId, 'action': 'BLOCK'});
  }

  Future<void> unblockContact(int contactId) async {
    await waitUntilOnline();
    _sendMessage(34, {'contactId': contactId, 'action': 'UNBLOCK'});
  }

  Future<void> addContact(int contactId) async {
    await waitUntilOnline();
    _sendMessage(34, {'contactId': contactId, 'action': 'ADD'});
  }

  Future<void> subscribeToChat(int chatId, bool subscribe) async {
    await waitUntilOnline();
    _sendMessage(75, {'chatId': chatId, 'subscribe': subscribe});
  }

  Future<void> navigateToChat(int currentChatId, int targetChatId) async {
    await waitUntilOnline();
    if (currentChatId != 0) {
      await subscribeToChat(currentChatId, false);
    }
    await subscribeToChat(targetChatId, true);
  }

  Future<void> clearChatHistory(int chatId, {bool forAll = false}) async {
    await waitUntilOnline();
    final payload = {
      'chatId': chatId,
      'forAll': forAll,
      'lastEventTime': DateTime.now().millisecondsSinceEpoch,
    };
    _sendMessage(54, payload);
  }

  Future<Map<String, dynamic>> getChatInfoByLink(String link) async {
    await waitUntilOnline();

    final payload = {'link': link};

    final int seq = _sendMessage(89, payload);
    print('Запрашиваем информацию о чате (seq: $seq) по ссылке: $link');

    try {
      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 10));

      if (response['cmd'] == 3) {
        final errorPayload = response['payload'] ?? {};
        final errorMessage =
            errorPayload['localizedMessage'] ??
            errorPayload['message'] ??
            'Неизвестная ошибка';
        print('Ошибка получения информации о чате: $errorMessage');
        throw Exception(errorMessage);
      }

      if (response['cmd'] == 1 &&
          response['payload'] != null &&
          response['payload']['chat'] != null) {
        print(
          'Информация о чате получена: ${response['payload']['chat']['title']}',
        );
        return response['payload']['chat'] as Map<String, dynamic>;
      } else {
        print('Не удалось найти "chat" в ответе opcode 89: $response');
        throw Exception('Неверный ответ от сервера');
      }
    } on TimeoutException {
      print('Таймаут ожидания ответа на getChatInfoByLink (seq: $seq)');
      throw Exception('Сервер не ответил вовремя');
    } catch (e) {
      print('Ошибка в getChatInfoByLink: $e');
      rethrow;
    }
  }

  void markMessageAsRead(int chatId, String messageId) {
    waitUntilOnline().then((_) {
      final payload = {
        "type": "READ_MESSAGE",
        "chatId": chatId,
        "messageId": messageId,
        "mark": DateTime.now().millisecondsSinceEpoch,
      };
      _sendMessage(50, payload);
      print(
        'Отправляем отметку о прочтении для сообщения $messageId в чате $chatId',
      );
    });
  }

  void getBlockedContacts() async {
    if (_isLoadingBlockedContacts) {
      print(
        'ApiService: запрос заблокированных контактов уже выполняется, пропускаем',
      );
      return;
    }

    _isLoadingBlockedContacts = true;
    print('ApiService: запрашиваем заблокированные контакты');
    _sendMessage(36, {'status': 'BLOCKED', 'count': 100, 'from': 0});

    Future.delayed(const Duration(seconds: 2), () {
      _isLoadingBlockedContacts = false;
    });
  }

  void notifyContactUpdate(Contact contact) {
    print(
      'ApiService отправляет обновление контакта: ${contact.name} (ID: ${contact.id}), isBlocked: ${contact.isBlocked}, isBlockedByMe: ${contact.isBlockedByMe}',
    );
    _contactUpdatesController.add(contact);
  }

  DateTime? getLastSeen(int userId) {
    final userPresence = _presenceData[userId.toString()];
    if (userPresence != null && userPresence['seen'] != null) {
      final seenTimestamp = userPresence['seen'] as int;

      return DateTime.fromMillisecondsSinceEpoch(seenTimestamp * 1000);
    }
    return null;
  }

  void updatePresenceData(Map<String, dynamic> presenceData) {
    _presenceData.addAll(presenceData);
    print('ApiService обновил presence данные: $_presenceData');
  }

  void sendReaction(int chatId, String messageId, String emoji) {
    final payload = {
      "chatId": chatId,
      "messageId": messageId,
      "reaction": {"reactionType": "EMOJI", "id": emoji},
    };
    _sendMessage(178, payload);
    print('Отправляем реакцию: $emoji на сообщение $messageId в чате $chatId');
  }

  void removeReaction(int chatId, String messageId) {
    final payload = {"chatId": chatId, "messageId": messageId};
    _sendMessage(179, payload);
    print('Удаляем реакцию с сообщения $messageId в чате $chatId');
  }

  void createGroup(String name, List<int> participantIds) {
    final payload = {"name": name, "participantIds": participantIds};
    _sendMessage(48, payload);
    print('Создаем группу: $name с участниками: $participantIds');
  }

  void updateGroup(int chatId, {String? name, List<int>? participantIds}) {
    final payload = {
      "chatId": chatId,
      if (name != null) "name": name,
      if (participantIds != null) "participantIds": participantIds,
    };
    _sendMessage(272, payload);
    print('Обновляем группу $chatId: $payload');
  }

  void createGroupWithMessage(String name, List<int> participantIds) {
    final cid = DateTime.now().millisecondsSinceEpoch;
    final payload = {
      "message": {
        "cid": cid,
        "attaches": [
          {
            "_type": "CONTROL",
            "event": "new",
            "chatType": "CHAT",
            "title": name,
            "userIds": participantIds,
          },
        ],
      },
      "notify": true,
    };
    _sendMessage(64, payload);
    print('Создаем группу: $name с участниками: $participantIds');
  }

  void renameGroup(int chatId, String newName) {
    final payload = {"chatId": chatId, "theme": newName};
    _sendMessage(55, payload);
    print('Переименовываем группу $chatId в: $newName');
  }

  void addGroupMember(
    int chatId,
    List<int> userIds, {
    bool showHistory = true,
  }) {
    final payload = {
      "chatId": chatId,
      "userIds": userIds,
      "showHistory": showHistory,
      "operation": "add",
    };
    _sendMessage(77, payload);
    print('Добавляем участников $userIds в группу $chatId');
  }

  void removeGroupMember(
    int chatId,
    List<int> userIds, {
    int cleanMsgPeriod = 0,
  }) {
    final payload = {
      "chatId": chatId,
      "userIds": userIds,
      "operation": "remove",
      "cleanMsgPeriod": cleanMsgPeriod,
    };
    _sendMessage(77, payload);
    print('Удаляем участников $userIds из группы $chatId');
  }

  void leaveGroup(int chatId) {
    final payload = {"chatId": chatId};
    _sendMessage(58, payload);
    print('Выходим из группы $chatId');
  }

  void getGroupMembers(int chatId, {int marker = 0, int count = 50}) {
    final payload = {
      "type": "MEMBER",
      "marker": marker,
      "chatId": chatId,
      "count": count,
    };
    _sendMessage(59, payload);
    print(
      'Запрашиваем участников группы $chatId (marker: $marker, count: $count)',
    );
  }

  Future<int?> getChatIdByUserId(int userId) async {
    await waitUntilOnline();

    final payload = {
      "chatIds": [userId],
    };
    final int seq = _sendMessage(48, payload);
    print('Запрашиваем информацию о чате для userId: $userId (seq: $seq)');

    try {
      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 10));

      if (response['cmd'] == 3) {
        final errorPayload = response['payload'] ?? {};
        final errorMessage =
            errorPayload['localizedMessage'] ??
            errorPayload['message'] ??
            'Неизвестная ошибка';
        print('Ошибка получения информации о чате: $errorMessage');
        return null;
      }

      if (response['cmd'] == 1 && response['payload'] != null) {
        final chats = response['payload']['chats'] as List<dynamic>?;
        if (chats != null && chats.isNotEmpty) {
          final chat = chats[0] as Map<String, dynamic>;
          final chatId = chat['id'] as int?;
          final chatType = chat['type'] as String?;

          if (chatType == 'DIALOG' && chatId != null) {
            print('Получен chatId для диалога с userId $userId: $chatId');
            return chatId;
          }
        }
      }

      print('Не удалось найти chatId для userId: $userId');
      return null;
    } on TimeoutException {
      print('Таймаут ожидания ответа на getChatIdByUserId (seq: $seq)');
      return null;
    } catch (e) {
      print('Ошибка при получении chatId для userId $userId: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> getChatsOnly({bool force = false}) async {
    if (authToken == null) {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('authToken');
    }
    if (authToken == null) throw Exception("Auth token not found");

    if (!force && _lastChatsPayload != null && _lastChatsAt != null) {
      if (DateTime.now().difference(_lastChatsAt!) < _chatsCacheTtl) {
        return _lastChatsPayload!;
      }
    }

    try {
      final payload = {"chatsCount": 100};

      final int chatSeq = _sendMessage(48, payload);
      final chatResponse = await messages.firstWhere(
        (msg) => msg['seq'] == chatSeq,
      );

      final List<dynamic> chatListJson =
          chatResponse['payload']?['chats'] ?? [];

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

      final int contactSeq = _sendMessage(32, {
        "contactIds": contactIds.toList(),
      });
      final contactResponse = await messages.firstWhere(
        (msg) => msg['seq'] == contactSeq,
      );

      final List<dynamic> contactListJson =
          contactResponse['payload']?['contacts'] ?? [];

      final result = {
        'chats': chatListJson,
        'contacts': contactListJson,
        'profile': null,
        'presence': null,
      };
      _lastChatsPayload = result;

      final contacts = contactListJson
          .map((json) => Contact.fromJson(json))
          .toList();
      updateContactCache(contacts);
      _lastChatsAt = DateTime.now();
      return result;
    } catch (e) {
      print('Ошибка получения чатов: $e');
      rethrow;
    }
  }

  Future<void> verifyCode(String token, String code) async {
    _currentPasswordTrackId = null;
    _currentPasswordHint = null;
    _currentPasswordEmail = null;

    if (_channel == null) {
      print('WebSocket не подключен, подключаемся...');
      try {
        await connect();

        await waitUntilOnline();
      } catch (e) {
        print('Ошибка подключения к WebSocket: $e');
        throw Exception('Не удалось подключиться к серверу: $e');
      }
    }

    final payload = {
      'token': token,
      'verifyCode': code,
      'authTokenType': 'CHECK_CODE',
    };

    _sendMessage(18, payload);
    print('Код верификации отправлен с payload: $payload');
  }

  Future<void> sendPassword(String trackId, String password) async {
    await waitUntilOnline();

    final payload = {'trackId': trackId, 'password': password};

    _sendMessage(115, payload);
    print('Пароль отправлен с payload: $payload');
  }

  Map<String, String?> getPasswordAuthData() {
    return {
      'trackId': _currentPasswordTrackId,
      'hint': _currentPasswordHint,
      'email': _currentPasswordEmail,
    };
  }

  void clearPasswordAuthData() {
    _currentPasswordTrackId = null;
    _currentPasswordHint = null;
    _currentPasswordEmail = null;
  }

  Future<void> setAccountPassword(String password, String hint) async {
    await waitUntilOnline();

    final payload = {'password': password, 'hint': hint};

    _sendMessage(116, payload);
    print('Запрос на установку пароля отправлен с payload: $payload');
  }

  Future<Map<String, dynamic>> joinGroupByLink(String link) async {
    await waitUntilOnline();

    final payload = {'link': link};

    final int seq = _sendMessage(57, payload);
    print('Отправляем запрос на присоединение (seq: $seq) по ссылке: $link');

    try {
      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq && msg['opcode'] == 57)
          .timeout(const Duration(seconds: 15));

      if (response['cmd'] == 3) {
        final errorPayload = response['payload'] ?? {};
        final errorMessage =
            errorPayload['localizedMessage'] ??
            errorPayload['message'] ??
            'Неизвестная ошибка';
        print('Ошибка присоединения к группе: $errorMessage');
        throw Exception(errorMessage);
      }

      if (response['cmd'] == 1 && response['payload'] != null) {
        print('Успешно присоединились: ${response['payload']}');
        return response['payload'] as Map<String, dynamic>;
      } else {
        print('Неожиданный ответ на joinGroupByLink: $response');
        throw Exception('Неверный ответ от сервера');
      }
    } on TimeoutException {
      print('Таймаут ожидания ответа на joinGroupByLink (seq: $seq)');
      throw Exception('Сервер не ответил вовремя');
    } catch (e) {
      print('Ошибка в joinGroupByLink: $e');
      rethrow;
    }
  }

  Future<void> searchContactByPhone(String phone) async {
    await waitUntilOnline();

    final payload = {'phone': phone};

    _sendMessage(46, payload);
    print('Запрос на поиск контакта отправлен с payload: $payload');
  }

  Future<void> searchChannels(String query) async {
    await waitUntilOnline();

    final payload = {'contactIds': []};

    _sendMessage(32, payload);
    print('Запрос на поиск каналов отправлен с payload: $payload');
  }

  Future<void> enterChannel(String link) async {
    await waitUntilOnline();

    final payload = {'link': link};

    _sendMessage(89, payload);
    print('Запрос на вход в канал отправлен с payload: $payload');
  }

  Future<void> subscribeToChannel(String link) async {
    await waitUntilOnline();

    final payload = {'link': link};

    _sendMessage(57, payload);
    print('Запрос на подписку на канал отправлен с payload: $payload');
  }

  Future<Map<String, dynamic>> getChatsAndContacts({bool force = false}) async {
    await waitUntilOnline();

    if (authToken == null) {
      print("Токен авторизации не найден, требуется повторная авторизация");
      throw Exception("Auth token not found - please re-authenticate");
    }

    if (!force && _lastChatsPayload != null && _lastChatsAt != null) {
      if (DateTime.now().difference(_lastChatsAt!) < _chatsCacheTtl) {
        return _lastChatsPayload!;
      }
    }

    if (_chatsFetchedInThisSession && _lastChatsPayload != null && !force) {
      return _lastChatsPayload!;
    }

    if (_inflightChatsCompleter != null) {
      return _inflightChatsCompleter!.future;
    }
    _inflightChatsCompleter = Completer<Map<String, dynamic>>();

    if (_isSessionOnline &&
        _isSessionReady &&
        _lastChatsPayload != null &&
        !force) {
      _inflightChatsCompleter!.complete(_lastChatsPayload!);
      _inflightChatsCompleter = null;
      return _lastChatsPayload!;
    }

    try {
      Map<String, dynamic> chatResponse;

      final int opcode;
      final Map<String, dynamic> payload;

      final prefs = await SharedPreferences.getInstance();
      final deviceId =
          prefs.getString('spoof_deviceid') ?? generateRandomDeviceId();

      if (prefs.getString('spoof_deviceid') == null) {
        await prefs.setString('spoof_deviceid', deviceId);
      }

      if (!_chatsFetchedInThisSession) {
        opcode = 19;
        payload = {
          "chatsCount": 100,
          "chatsSync": 0,
          "contactsSync": 0,
          "draftsSync": 0,
          "interactive": true,
          "presenceSync": 0,
          "token": authToken,
        };

        if (userId != null) {
          payload["userId"] = userId;
        }
      } else {
        return await getChatsOnly(force: force);
      }

      final int chatSeq = _sendMessage(opcode, payload);
      chatResponse = await messages.firstWhere((msg) => msg['seq'] == chatSeq);

      if (opcode == 19 && chatResponse['cmd'] == 1) {
        print("✅ Авторизация (opcode 19) успешна. Сессия ГОТОВА.");
        _isSessionReady = true; // <-- ВОТ ТЕПЕРЬ СЕССИЯ ПОЛНОСТЬЮ ГОТОВА!

        _connectionStatusController.add("ready");

        final profile = chatResponse['payload']?['profile'];
        final contactProfile = profile?['contact'];

        if (contactProfile != null && contactProfile['id'] != null) {
          print(
            "[getChatsAndContacts] ✅ Профиль и ID пользователя найдены. ID: ${contactProfile['id']}. ЗАПУСКАЕМ АНАЛИТИКУ.",
          );
          _userId = contactProfile['id'];
          _sessionId = DateTime.now().millisecondsSinceEpoch;
          _lastActionTime = _sessionId;

          sendNavEvent('COLD_START');

          _sendInitialSetupRequests();
        } else {
          print(
            "[getChatsAndContacts] ❌ ВНИМАНИЕ: Профиль или ID в ответе пустой, аналитика не будет отправлена.",
          );
        }

        if (_onlineCompleter != null && !_onlineCompleter!.isCompleted) {
          _onlineCompleter!.complete();
        }

        _startPinging();
        _processMessageQueue();
      }

      final profile = chatResponse['payload']?['profile'];
      final presence = chatResponse['payload']?['presence'];
      final config = chatResponse['payload']?['config'];
      final List<dynamic> chatListJson =
          chatResponse['payload']?['chats'] ?? [];

      if (chatListJson.isEmpty) {
        if (config != null) {
          _processServerPrivacyConfig(config);
        }

        final result = {
          'chats': [],
          'contacts': [],
          'profile': profile,
          'config': config,
        };
        _lastChatsPayload = result;
        _lastChatsAt = DateTime.now();
        _chatsFetchedInThisSession = true;
        _inflightChatsCompleter!.complete(_lastChatsPayload!);
        _inflightChatsCompleter = null;
        return result;
      }

      final contactIds = <int>{};
      for (var chatJson in chatListJson) {
        final participants = chatJson['participants'] as Map<String, dynamic>;
        contactIds.addAll(participants.keys.map((id) => int.parse(id)));
      }

      final int contactSeq = _sendMessage(32, {
        "contactIds": contactIds.toList(),
      });
      final contactResponse = await messages.firstWhere(
        (msg) => msg['seq'] == contactSeq,
      );

      final List<dynamic> contactListJson =
          contactResponse['payload']?['contacts'] ?? [];

      if (presence != null) {
        updatePresenceData(presence);
      }

      if (config != null) {
        _processServerPrivacyConfig(config);
      }

      final result = {
        'chats': chatListJson,
        'contacts': contactListJson,
        'profile': profile,
        'presence': presence,
        'config': config,
      };
      _lastChatsPayload = result;

      final contacts = contactListJson
          .map((json) => Contact.fromJson(json))
          .toList();
      updateContactCache(contacts);
      _lastChatsAt = DateTime.now();
      _chatsFetchedInThisSession = true;
      _inflightChatsCompleter!.complete(result);
      _inflightChatsCompleter = null;
      return result;
    } catch (e) {
      final error = e;
      _inflightChatsCompleter?.completeError(error);
      _inflightChatsCompleter = null;
      rethrow;
    }
  }

  Future<List<Message>> getMessageHistory(
    int chatId, {
    bool force = false,
  }) async {
    if (!force && _messageCache.containsKey(chatId)) {
      print("Загружаем сообщения для чата $chatId из кэша.");
      return _messageCache[chatId]!;
    }

    print("Запрашиваем историю для чата $chatId с сервера.");
    final payload = {
      "chatId": chatId,

      "from": DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch,
      "forward": 0,
      "backward": 1000, // Увеличиваем лимит для получения всех сообщений
      "getMessages": true,
    };

    try {
      final int seq = _sendMessage(49, payload);
      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 15));

      if (response['cmd'] == 3) {
        final error = response['payload'];
        print('Ошибка получения истории сообщений: $error');

        if (error['error'] == 'proto.state') {
          print(
            'Ошибка состояния сессии при получении истории, переподключаемся...',
          );
          await reconnect();
          await waitUntilOnline();

          return getMessageHistory(chatId, force: true);
        }
        throw Exception('Ошибка получения истории: ${error['message']}');
      }

      final List<dynamic> messagesJson = response['payload']?['messages'] ?? [];
      final messagesList =
          messagesJson.map((json) => Message.fromJson(json)).toList()
            ..sort((a, b) => a.time.compareTo(b.time));

      _messageCache[chatId] = messagesList;

      return messagesList;
    } catch (e) {
      print('Ошибка при получении истории сообщений: $e');

      return [];
    }
  }

  Future<Map<String, dynamic>?> loadOldMessages(
    int chatId,
    String fromMessageId,
    int count,
  ) async {
    print(
      "Запрашиваем старые сообщения для чата $chatId начиная с $fromMessageId",
    );

    final payload = {
      "chatId": chatId,
      "from": int.parse(fromMessageId),
      "forward": 0,
      "backward": count,
      "getMessages": true,
    };

    try {
      final int seq = _sendMessage(49, payload);
      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq)
          .timeout(const Duration(seconds: 15));

      if (response['cmd'] == 3) {
        final error = response['payload'];
        print('Ошибка получения старых сообщений: $error');
        return null;
      }

      return response['payload'];
    } catch (e) {
      print('Ошибка при получении старых сообщений: $e');
      return null;
    }
  }

  void setAppInForeground(bool isForeground) {
    _isAppInForeground = isForeground;
  }

  void sendNavEvent(String event, {int? screenTo, int? screenFrom}) {
    if (_userId == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final Map<String, dynamic> params = {
      'session_id': _sessionId,
      'action_id': _actionId++,
    };

    switch (event) {
      case 'COLD_START':
        if (_isColdStartSent) return;
        params['screen_to'] = 150;
        params['source_id'] = 1;
        _isColdStartSent = true;
        break;
      case 'WARM_START':
        params['screen_to'] =
            150; // Предполагаем, что всегда возвращаемся на главный экран
        params['screen_from'] = 1; // 1 = приложение свернуто
        params['prev_time'] = _lastActionTime;
        break;
      case 'GO':
        params['screen_to'] = screenTo;
        params['screen_from'] = screenFrom;
        params['prev_time'] = _lastActionTime;
        break;
    }

    _lastActionTime = now;
    _sendMessage(5, {
      "events": [
        {
          "type": "NAV",
          "event": event,
          "userId": _userId,
          "time": now,
          "params": params,
        },
      ],
    });
  }

  void createFolder(
    String title, {
    List<int>? include,
    List<dynamic>? filters,
  }) {
    final folderId = const Uuid().v4();
    final payload = {
      "id": folderId,
      "title": title,
      "include": include ?? [],
      "filters": filters ?? [],
    };
    _sendMessage(274, payload);
    print('Создаем папку: $title (ID: $folderId)');
  }

  void updateFolder(
    String folderId, {
    String? title,
    List<int>? include,
    List<dynamic>? filters,
  }) {
    final payload = {
      "id": folderId,
      if (title != null) "title": title,
      if (include != null) "include": include,
      if (filters != null) "filters": filters,
    };
    _sendMessage(274, payload);
    print('Обновляем папку: $folderId');
  }

  Future<void> _sendInitialSetupRequests() async {
    print("Запускаем отправку единичных запросов при старте...");

    await Future.delayed(const Duration(seconds: 2));
    _sendMessage(272, {"folderSync": 0});
    await Future.delayed(const Duration(milliseconds: 500));
    _sendMessage(27, {"sync": 0, "type": "STICKER"});
    await Future.delayed(const Duration(milliseconds: 500));
    _sendMessage(27, {"sync": 0, "type": "FAVORITE_STICKER"});
    await Future.delayed(const Duration(milliseconds: 500));
    _sendMessage(79, {"forward": false, "count": 100});

    await Future.delayed(const Duration(seconds: 5));
    _sendMessage(26, {
      "sectionId": "NEW_STICKER_SETS",
      "from": 5,
      "count": 100,
    });

    print("Единичные запросы отправлены.");
  }

  void clearCacheForChat(int chatId) {
    _messageCache.remove(chatId);
    print("Кэш для чата $chatId очищен.");
  }

  void clearChatsCache() {
    _lastChatsPayload = null;
    _lastChatsAt = null;
    _chatsFetchedInThisSession = false;
    print("Кэш чатов очищен.");
  }

  Contact? getCachedContact(int contactId) {
    if (_contactCache.containsKey(contactId)) {
      final contact = _contactCache[contactId]!;
      print('Контакт $contactId получен из кэша: ${contact.name}');
      return contact;
    }
    return null;
  }

  Future<Map<String, dynamic>> getNetworkStatistics() async {
    final prefs = await SharedPreferences.getInstance();

    final totalTraffic =
        prefs.getDouble('network_total_traffic') ??
        (150.0 * 1024 * 1024); // 150 MB по умолчанию
    final messagesTraffic =
        prefs.getDouble('network_messages_traffic') ?? (totalTraffic * 0.15);
    final mediaTraffic =
        prefs.getDouble('network_media_traffic') ?? (totalTraffic * 0.6);
    final syncTraffic =
        prefs.getDouble('network_sync_traffic') ?? (totalTraffic * 0.1);

    final currentSpeed = _isSessionOnline
        ? 512.0 * 1024
        : 0.0; // 512 KB/s если онлайн

    final ping = 25;

    return {
      'totalTraffic': totalTraffic,
      'messagesTraffic': messagesTraffic,
      'mediaTraffic': mediaTraffic,
      'syncTraffic': syncTraffic,
      'otherTraffic': totalTraffic * 0.15,
      'currentSpeed': currentSpeed,
      'isConnected': _isSessionOnline,
      'connectionType': 'Wi-Fi', // Можно определить реальный тип
      'signalStrength': 85,
      'ping': ping,
      'jitter': 2.5,
      'packetLoss': 0.01,
      'hourlyStats': [], // Пока пустой массив, можно реализовать позже
    };
  }

  bool isContactCacheValid() {
    if (_lastContactsUpdate == null) return false;
    return DateTime.now().difference(_lastContactsUpdate!) <
        _contactCacheExpiry;
  }

  void updateContactCache(List<Contact> contacts) {
    _contactCache.clear();
    for (final contact in contacts) {
      _contactCache[contact.id] = contact;
    }
    _lastContactsUpdate = DateTime.now();
    print('Кэш контактов обновлен: ${contacts.length} контактов');
  }

  void updateCachedContact(Contact contact) {
    _contactCache[contact.id] = contact;
    print('Контакт ${contact.id} обновлен в кэше: ${contact.name}');
  }

  void clearContactCache() {
    _contactCache.clear();
    _lastContactsUpdate = null;
    print("Кэш контактов очищен.");
  }

  void clearAllCaches() {
    clearContactCache();
    clearChatsCache();
    _messageCache.clear();
    clearPasswordAuthData();
    print("Все кэши очищены из-за ошибки подключения.");
  }

  Future<void> clearAllData() async {
    try {
      clearAllCaches();

      authToken = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      _pingTimer?.cancel();
      await _channel?.sink.close();
      _channel = null;

      _isSessionOnline = false;
      _isSessionReady = false;
      _chatsFetchedInThisSession = false;
      _reconnectAttempts = 0;
      _currentUrlIndex = 0;

      _messageQueue.clear();
      _presenceData.clear();

      print("Все данные приложения полностью очищены.");
    } catch (e) {
      print("Ошибка при полной очистке данных: $e");
      rethrow;
    }
  }

  void sendMessage(
    int chatId,
    String text, {
    String? replyToMessageId,
    int? cid,
  }) {
    final int clientMessageId = cid ?? DateTime.now().millisecondsSinceEpoch;
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

    if (_isSessionOnline) {
      _sendMessage(64, payload);
    } else {
      print("Сессия не онлайн. Сообщение добавлено в очередь.");
      _messageQueue.add({'opcode': 64, 'payload': payload});
    }
  }

  void forwardMessage(int targetChatId, String messageId, int sourceChatId) {
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

    if (_isSessionOnline) {
      _sendMessage(64, payload);
    } else {
      _messageQueue.add({'opcode': 64, 'payload': payload});
    }
  }

  void _processMessageQueue() {
    if (_messageQueue.isEmpty) return;
    print("Отправка ${_messageQueue.length} сообщений из очереди...");
    for (var message in _messageQueue) {
      _sendMessage(message['opcode'], message['payload']);
    }
    _messageQueue.clear();
  }

  Future<void> editMessage(int chatId, String messageId, String newText) async {
    final payload = {
      "chatId": chatId,
      "messageId": messageId,
      "text": newText,
      "elements": [],
      "attachments": [],
    };

    clearChatsCache();

    await waitUntilOnline();

    if (!_isSessionOnline) {
      print('Сессия не онлайн, пытаемся переподключиться...');
      await reconnect();
      await waitUntilOnline();
    }

    Future<bool> sendOnce() async {
      try {
        final int seq = _sendMessage(67, payload);
        final response = await messages
            .firstWhere((msg) => msg['seq'] == seq)
            .timeout(const Duration(seconds: 10));

        if (response['cmd'] == 3) {
          final error = response['payload'];
          print('Ошибка редактирования сообщения: $error');

          if (error['error'] == 'proto.state') {
            print('Ошибка состояния сессии, переподключаемся...');
            await reconnect();
            await waitUntilOnline();
            return false; // Попробуем еще раз
          }

          if (error['error'] == 'error.edit.invalid.message') {
            print(
              'Сообщение не может быть отредактировано: ${error['localizedMessage']}',
            );
            throw Exception(
              'Сообщение не может быть отредактировано: ${error['localizedMessage']}',
            );
          }

          return false;
        }

        return response['cmd'] == 1; // Успешный ответ
      } catch (e) {
        print('Ошибка при редактировании сообщения: $e');
        return false;
      }
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      print(
        'Попытка редактирования сообщения $messageId (попытка ${attempt + 1}/3)',
      );
      bool ok = await sendOnce();
      if (ok) {
        print('Сообщение $messageId успешно отредактировано');
        return;
      }

      if (attempt < 2) {
        print(
          'Повторяем запрос редактирования для сообщения $messageId через 2 секунды...',
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    print('Не удалось отредактировать сообщение $messageId после 3 попыток');
  }

  Future<void> deleteMessage(
    int chatId,
    String messageId, {
    bool forMe = false,
  }) async {
    final payload = {
      "chatId": chatId,
      "messageIds": [messageId],
      "forMe": forMe,
    };

    clearChatsCache();

    await waitUntilOnline();

    if (!_isSessionOnline) {
      print('Сессия не онлайн, пытаемся переподключиться...');
      await reconnect();
      await waitUntilOnline();
    }

    Future<bool> sendOnce() async {
      try {
        final int seq = _sendMessage(66, payload);
        final response = await messages
            .firstWhere((msg) => msg['seq'] == seq)
            .timeout(const Duration(seconds: 10));

        if (response['cmd'] == 3) {
          final error = response['payload'];
          print('Ошибка удаления сообщения: $error');

          if (error['error'] == 'proto.state') {
            print('Ошибка состояния сессии, переподключаемся...');
            await reconnect();
            await waitUntilOnline();
            return false; // Попробуем еще раз
          }
          return false;
        }

        return response['cmd'] == 1; // Успешный ответ
      } catch (e) {
        print('Ошибка при удалении сообщения: $e');
        return false;
      }
    }

    for (int attempt = 0; attempt < 3; attempt++) {
      print('Попытка удаления сообщения $messageId (попытка ${attempt + 1}/3)');
      bool ok = await sendOnce();
      if (ok) {
        print('Сообщение $messageId успешно удалено');
        return;
      }

      if (attempt < 2) {
        print(
          'Повторяем запрос удаления для сообщения $messageId через 2 секунды...',
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    print('Не удалось удалить сообщение $messageId после 3 попыток');
  }

  void sendTyping(int chatId, {String type = "TEXT"}) {
    final payload = {"chatId": chatId, "type": type};
    if (_isSessionOnline) {
      _sendMessage(65, payload);
    }
  }

  void updateProfileText(
    String firstName,
    String lastName,
    String description,
  ) {
    final payload = {
      "firstName": firstName,
      "lastName": lastName,
      "description": description,
    };
    _sendMessage(16, payload);
  }

  Future<void> updateProfilePhoto(String firstName, String lastName) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      print("Запрашиваем URL для загрузки фото...");
      final int seq = _sendMessage(80, {"count": 1});
      final response = await messages.firstWhere((msg) => msg['seq'] == seq);
      final String uploadUrl = response['payload']['url'];
      print("URL получен: $uploadUrl");

      print("Загружаем фото на сервер...");
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var streamedResponse = await request.send();
      var httpResponse = await http.Response.fromStream(streamedResponse);

      if (httpResponse.statusCode != 200) {
        throw Exception("Ошибка загрузки фото: ${httpResponse.body}");
      }

      final uploadResult = jsonDecode(httpResponse.body);
      final String photoToken = uploadResult['photos'].values.first['token'];
      print("Фото загружено, получен токен: $photoToken");

      print("Привязываем фото к профилю...");
      final payload = {
        "firstName": firstName,
        "lastName": lastName,
        "photoToken": photoToken,
        "avatarType": "USER_AVATAR",
      };
      _sendMessage(16, payload);
      print("Запрос на смену аватара отправлен.");
    } catch (e) {
      print("!!! Ошибка в процессе смены аватара: $e");
    }
  }

  Future<void> sendPhotoMessage(
    int chatId, {
    String? localPath,
    String? caption,
    int? cidOverride,
    int? senderId, // my user id to mark local echo as mine
  }) async {
    try {
      XFile? image;
      if (localPath != null) {
        image = XFile(localPath);
      } else {
        final picker = ImagePicker();
        image = await picker.pickImage(source: ImageSource.gallery);
        if (image == null) return;
      }

      await waitUntilOnline();

      final int seq80 = _sendMessage(80, {"count": 1});
      final resp80 = await messages.firstWhere((m) => m['seq'] == seq80);
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

      if (localPath != null) {
        _emitLocal({
          'ver': 11,
          'cmd': 1,
          'seq': -1,
          'opcode': 128,
          'payload': {
            'chatId': chatId,
            'message': {
              'id': 'local_$cid',
              'sender': senderId ?? 0,
              'time': DateTime.now().millisecondsSinceEpoch,
              'text': caption?.trim() ?? '',
              'type': 'USER',
              'cid': cid,
              'attaches': [
                {'_type': 'PHOTO', 'url': 'file://$localPath'},
              ],
            },
          },
        });
      }

      _sendMessage(64, payload);
    } catch (e) {
      print('Ошибка отправки фото-сообщения: $e');
    }
  }

  Future<void> sendPhotoMessages(
    int chatId, {
    required List<String> localPaths,
    String? caption,
    int? senderId,
  }) async {
    if (localPaths.isEmpty) return;
    try {
      await waitUntilOnline();

      final int cid = DateTime.now().millisecondsSinceEpoch;
      _emitLocal({
        'ver': 11,
        'cmd': 1,
        'seq': -1,
        'opcode': 128,
        'payload': {
          'chatId': chatId,
          'message': {
            'id': 'local_$cid',
            'sender': senderId ?? 0,
            'time': DateTime.now().millisecondsSinceEpoch,
            'text': caption?.trim() ?? '',
            'type': 'USER',
            'cid': cid,
            'attaches': [
              for (final p in localPaths)
                {'_type': 'PHOTO', 'url': 'file://$p'},
            ],
          },
        },
      });

      final List<Map<String, String>> photoTokens = [];
      for (final path in localPaths) {
        final int seq80 = _sendMessage(80, {"count": 1});
        final resp80 = await messages.firstWhere((m) => m['seq'] == seq80);
        final String uploadUrl = resp80['payload']['url'];

        var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
        request.files.add(await http.MultipartFile.fromPath('file', path));
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
        photoTokens.add({"token": photoToken});
      }

      final payload = {
        "chatId": chatId,
        "message": {
          "text": caption?.trim() ?? "",
          "cid": cid,
          "elements": [],
          "attaches": [
            for (final t in photoTokens)
              {"_type": "PHOTO", "photoToken": t["token"]},
          ],
        },
        "notify": true,
      };

      clearChatsCache();
      _sendMessage(64, payload);
    } catch (e) {
      print('Ошибка отправки фото-сообщений: $e');
    }
  }

  Future<void> sendFileMessage(
    int chatId, {
    String? caption,
    int? senderId, // my user id to mark local echo as mine
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        print("Выбор файла отменен");
        return;
      }

      final String filePath = result.files.single.path!;
      final String fileName = result.files.single.name;
      final int fileSize = result.files.single.size;

      await waitUntilOnline();

      final int seq87 = _sendMessage(87, {"count": 1});
      final resp87 = await messages.firstWhere((m) => m['seq'] == seq87);

      if (resp87['payload'] == null ||
          resp87['payload']['info'] == null ||
          (resp87['payload']['info'] as List).isEmpty) {
        throw Exception('Неверный ответ на Opcode 87: отсутствует "info"');
      }

      final uploadInfo = (resp87['payload']['info'] as List).first;
      final String uploadUrl = uploadInfo['url'];
      final int fileId = uploadInfo['fileId']; // <-- Ключевое отличие от фото

      print('Получен fileId: $fileId и URL: $uploadUrl');

      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      var streamed = await request.send();
      var httpResp = await http.Response.fromStream(streamed);
      if (httpResp.statusCode != 200) {
        throw Exception(
          'Ошибка загрузки файла: ${httpResp.statusCode} ${httpResp.body}',
        );
      }

      print('Файл успешно загружен на сервер.');

      final int cid = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        "chatId": chatId,
        "message": {
          "text": caption?.trim() ?? "",
          "cid": cid,
          "elements": [],
          "attaches": [
            {"_type": "FILE", "fileId": fileId}, // <-- Используем fileId
          ],
        },
        "notify": true,
      };

      clearChatsCache();

      _emitLocal({
        'ver': 11,
        'cmd': 1,
        'seq': -1,
        'opcode': 128,
        'payload': {
          'chatId': chatId,
          'message': {
            'id': 'local_$cid',
            'sender': senderId ?? 0,
            'time': DateTime.now().millisecondsSinceEpoch,
            'text': caption?.trim() ?? '',
            'type': 'USER',
            'cid': cid,
            'attaches': [
              {
                '_type': 'FILE',
                'name': fileName,
                'size': fileSize,
                'url': 'file://$filePath', // Локальный путь для UI
              },
            ],
          },
        },
      });

      _sendMessage(64, payload);
      print('Сообщение о файле (Opcode 64) отправлено.');
    } catch (e) {
      print('Ошибка отправки файла: $e');
    }
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isSessionOnline && _isSessionReady) {
        print("Отправляем Ping для поддержания сессии...");
        _sendMessage(1, {"interactive": true});
      } else {
        print("Сессия не готова, пропускаем ping");
      }
    });
  }

  Future<void> saveToken(String token, {String? userId}) async {
    print("Сохраняем новый токен: ${token.substring(0, 20)}...");
    if (userId != null) {
      print("Сохраняем UserID: $userId");
    }
    authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authToken', token);
    if (_channel != null) {
      disconnect();
    }
    await connect();
    await getChatsAndContacts(force: true);
    if (userId != null) {
      await prefs.setString('userId', userId);
    }
    print("Токен и UserID успешно сохранены в SharedPreferences");
  }

  Future<bool> hasToken() async {
    if (authToken == null) {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('authToken');
      userId = prefs.getString('userId');
      if (authToken != null) {
        print(
          "Токен загружен из SharedPreferences: ${authToken!.substring(0, 20)}...",
        );
        if (userId != null) {
          print("UserID загружен из SharedPreferences: $userId");
        }
      }
    }
    return authToken != null;
  }

  Future<List<Contact>> fetchContactsByIds(List<int> contactIds) async {
    if (contactIds.isEmpty) {
      return [];
    }

    print('Запрашиваем данные для ${contactIds.length} контактов...');
    try {
      final int contactSeq = _sendMessage(32, {"contactIds": contactIds});

      final contactResponse = await messages
          .firstWhere((msg) => msg['seq'] == contactSeq)
          .timeout(const Duration(seconds: 10));

      if (contactResponse['cmd'] == 3) {
        print(
          "Ошибка при получении контактов по ID: ${contactResponse['payload']}",
        );
        return [];
      }

      final List<dynamic> contactListJson =
          contactResponse['payload']?['contacts'] ?? [];
      final contacts = contactListJson
          .map((json) => Contact.fromJson(json))
          .toList();

      for (final contact in contacts) {
        _contactCache[contact.id] = contact;
      }
      print("Получены и закэшированы данные для ${contacts.length} контактов.");
      return contacts;
    } catch (e) {
      print('Исключение при получении контактов по ID: $e');
      return [];
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      await prefs.remove('userId');
      authToken = null;
      userId = null;
      _messageCache.clear();
      _lastChatsPayload = null;
      _chatsFetchedInThisSession = false;
      _pingTimer?.cancel();
      await _channel?.sink.close(status.goingAway);
      _channel = null;
    } catch (_) {}
  }

  Future<void> connect() async {
    if (_channel != null && _isSessionOnline) {
      print("WebSocket уже подключен, пропускаем подключение");
      return;
    }

    print("Запускаем подключение к WebSocket...");

    _isSessionOnline = false;
    _isSessionReady = false;

    _connectionStatusController.add("connecting");
    await _connectWithFallback();
  }

  Future<void> reconnect() async {
    _reconnectAttempts =
        0; // Сбрасываем счетчик попыток при ручном переподключении
    _currentUrlIndex = 0; // Сбрасываем индекс для повторной попытки

    _connectionStatusController.add("connecting");
    await _connectWithFallback();
  }

  void sendFullJsonRequest(String jsonString) {
    if (_channel == null) {
      throw Exception('WebSocket is not connected. Connect first.');
    }
    _log('➡️ SEND (raw): $jsonString');
    _channel!.sink.add(jsonString);
  }

  int sendRawRequest(int opcode, Map<String, dynamic> payload) {
    if (_channel == null) {
      print('WebSocket не подключен!');

      throw Exception('WebSocket is not connected. Connect first.');
    }

    return _sendMessage(opcode, payload);
  }

  int sendAndTrackFullJsonRequest(String jsonString) {
    if (_channel == null) {
      throw Exception('WebSocket is not connected. Connect first.');
    }

    final message = jsonDecode(jsonString) as Map<String, dynamic>;

    final int currentSeq = _seq++;

    message['seq'] = currentSeq;

    final encodedMessage = jsonEncode(message);

    _log('➡️ SEND (custom): $encodedMessage');
    print('Отправляем кастомное сообщение (seq: $currentSeq): $encodedMessage');

    _channel!.sink.add(encodedMessage);

    return currentSeq;
  }

  int _sendMessage(int opcode, Map<String, dynamic> payload) {
    if (_channel == null) {
      print('WebSocket не подключен!');
      return -1;
    }
    final message = {
      "ver": 11,
      "cmd": 0,
      "seq": _seq,
      "opcode": opcode,
      "payload": payload,
    };
    final encodedMessage = jsonEncode(message);
    if (opcode == 1) {
      _log('➡️ SEND (ping) seq: $_seq');
    } else if (opcode == 18 || opcode == 19) {
      Map<String, dynamic> loggablePayload = Map.from(payload);
      if (loggablePayload.containsKey('token')) {
        String token = loggablePayload['token'] as String;

        loggablePayload['token'] = token.length > 8
            ? '${token.substring(0, 4)}...${token.substring(token.length - 4)}'
            : '***';
      }
      final loggableMessage = {...message, 'payload': loggablePayload};
      _log('➡️ SEND: ${jsonEncode(loggableMessage)}');
    } else {
      _log('➡️ SEND: $encodedMessage');
    }
    print('Отправляем сообщение (seq: $_seq): $encodedMessage');
    _channel!.sink.add(encodedMessage);
    return _seq++;
  }

  void _listen() async {
    _streamSubscription?.cancel(); // Отменяем предыдущую подписку
    _streamSubscription = _channel?.stream.listen(
      (message) {
        if (message == null) return;
        if (message is String && message.trim().isEmpty) {
          return;
        }

        String loggableMessage = message;
        try {
          final decoded = jsonDecode(message) as Map<String, dynamic>;
          if (decoded['opcode'] == 2) {
            loggableMessage = '⬅️ RECV (pong) seq: ${decoded['seq']}';
          } else {
            Map<String, dynamic> loggableDecoded = Map.from(decoded);
            bool wasModified = false;
            if (loggableDecoded.containsKey('payload') &&
                loggableDecoded['payload'] is Map) {
              Map<String, dynamic> payload = Map.from(
                loggableDecoded['payload'],
              );
              if (payload.containsKey('token')) {
                String token = payload['token'] as String;
                payload['token'] = token.length > 8
                    ? '${token.substring(0, 4)}...${token.substring(token.length - 4)}'
                    : '***';
                loggableDecoded['payload'] = payload;
                wasModified = true;
              }
            }
            if (wasModified) {
              loggableMessage = '⬅️ RECV: ${jsonEncode(loggableDecoded)}';
            } else {
              loggableMessage = '⬅️ RECV: $message';
            }
          }
        } catch (_) {
          loggableMessage = '⬅️ RECV (raw): $message';
        }
        _log(loggableMessage);

        try {
          final decodedMessage = message is String
              ? jsonDecode(message)
              : message;

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 97 &&
              decodedMessage['cmd'] == 1 &&
              decodedMessage['payload'] != null &&
              decodedMessage['payload']['token'] != null) {
            _handleSessionTerminated();
            return;
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 6 &&
              decodedMessage['cmd'] == 1) {
            print("Handshake успешен. Сессия ONLINE.");
            _isSessionOnline = true;
            _isSessionReady = false;
            _reconnectDelaySeconds = 2;
            _connectionStatusController.add("authorizing");

            if (_onlineCompleter != null && !_onlineCompleter!.isCompleted) {
              _onlineCompleter!.complete();
            }
            _startPinging();
            _processMessageQueue();
          }

          if (decodedMessage is Map && decodedMessage['cmd'] == 3) {
            final error = decodedMessage['payload'];
            print('Ошибка сервера: $error');

            if (error != null && error['localizedMessage'] != null) {
              _errorController.add(error['localizedMessage']);
            } else if (error != null && error['message'] != null) {
              _errorController.add(error['message']);
            }

            if (error != null && error['message'] == 'FAIL_WRONG_PASSWORD') {
              _errorController.add('FAIL_WRONG_PASSWORD');
            }

            if (error != null && error['error'] == 'password.invalid') {
              _errorController.add('Неверный пароль');
            }

            if (error != null && error['error'] == 'proto.state') {
              print('Ошибка состояния сессии, переподключаемся...');
              _chatsFetchedInThisSession = false;
              _reconnect();
              return;
            }

            if (error != null && error['error'] == 'login.token') {
              print('Токен недействителен, очищаем и завершаем сессию...');
              _handleInvalidToken();
              return;
            }

            if (error != null && error['message'] == 'FAIL_WRONG_PASSWORD') {
              print('Неверный токен авторизации, очищаем токен...');
              _clearAuthToken().then((_) {
                _chatsFetchedInThisSession = false;
                _messageController.add({
                  'type': 'invalid_token',
                  'message':
                      'Токен авторизации недействителен. Требуется повторная авторизация.',
                });
                _reconnect();
              });
              return;
            }
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 18 &&
              decodedMessage['cmd'] == 1 &&
              decodedMessage['payload'] != null) {
            final payload = decodedMessage['payload'];
            if (payload['passwordChallenge'] != null) {
              final challenge = payload['passwordChallenge'];
              _currentPasswordTrackId = challenge['trackId'];
              _currentPasswordHint = challenge['hint'];
              _currentPasswordEmail = challenge['email'];

              print(
                'Получен запрос на ввод пароля: trackId=${challenge['trackId']}, hint=${challenge['hint']}, email=${challenge['email']}',
              );

              _messageController.add({
                'type': 'password_required',
                'trackId': _currentPasswordTrackId,
                'hint': _currentPasswordHint,
                'email': _currentPasswordEmail,
              });
              return;
            }
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 22 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            print('Настройки приватности успешно обновлены: $payload');

            _messageController.add({
              'type': 'privacy_settings_updated',
              'settings': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 116 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            print('Пароль успешно установлен: $payload');

            _messageController.add({
              'type': 'password_set_success',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 57 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            print('Успешно присоединились к группе: $payload');

            _messageController.add({
              'type': 'group_join_success',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 46 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            print('Контакт найден: $payload');

            _messageController.add({
              'type': 'contact_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 46 &&
              decodedMessage['cmd'] == 3) {
            final payload = decodedMessage['payload'];
            print('Контакт не найден: $payload');

            _messageController.add({
              'type': 'contact_not_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 32 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            print('Каналы найдены: $payload');

            _messageController.add({
              'type': 'channels_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 32 &&
              decodedMessage['cmd'] == 3) {
            final payload = decodedMessage['payload'];
            print('Каналы не найдены: $payload');

            _messageController.add({
              'type': 'channels_not_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 89 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            print('Вход в канал успешен: $payload');

            _messageController.add({
              'type': 'channel_entered',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 89 &&
              decodedMessage['cmd'] == 3) {
            final payload = decodedMessage['payload'];
            print('Ошибка входа в канал: $payload');

            _messageController.add({
              'type': 'channel_error',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 57 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            print('Подписка на канал успешна: $payload');

            _messageController.add({
              'type': 'channel_subscribed',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 57 &&
              decodedMessage['cmd'] == 3) {
            final payload = decodedMessage['payload'];
            print('Ошибка подписки на канал: $payload');

            _messageController.add({
              'type': 'channel_error',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 59 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            print('Получены участники группы: $payload');

            _messageController.add({
              'type': 'group_members',
              'payload': payload,
            });
          }

          if (decodedMessage is Map<String, dynamic>) {
            _messageController.add(decodedMessage);
          }
        } catch (e) {
          print('Невалидное сообщение от сервера, пропускаем: $e');
        }
      },
      onError: (error) {
        print('Ошибка WebSocket: $error');
        _isSessionOnline = false;
        _isSessionReady = false;
        _reconnect();
      },
      onDone: () {
        print('WebSocket соединение закрыто. Попытка переподключения...');
        _isSessionOnline = false;
        _isSessionReady = false;

        if (!_isSessionReady) {
          _reconnect();
        }
      },
      cancelOnError: true,
    );
  }

  void _reconnect() {
    if (_isReconnecting) return;

    _isReconnecting = true;
    _reconnectAttempts++;

    if (_reconnectAttempts > _maxReconnectAttempts) {
      print(
        "Превышено максимальное количество попыток переподключения ($_maxReconnectAttempts). Останавливаем попытки.",
      );
      _connectionStatusController.add("disconnected");
      _isReconnecting = false;
      return;
    }

    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _isSessionOnline = false;
    _isSessionReady = false;
    _onlineCompleter = Completer<void>();
    _chatsFetchedInThisSession = false;

    clearAllCaches();

    _currentUrlIndex = 0;

    _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(1, 30);
    final jitter = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
    final delay = Duration(seconds: _reconnectDelaySeconds + jitter.round());

    _reconnectTimer = Timer(delay, () {
      print(
        "Переподключаемся после ${delay.inSeconds}s... (попытка $_reconnectAttempts/$_maxReconnectAttempts)",
      );
      _isReconnecting = false;
      _connectWithFallback();
    });
  }

  Future<String> getVideoUrl(int videoId, int chatId, String messageId) async {
    await waitUntilOnline();

    final payload = {
      "videoId": videoId,
      "chatId": chatId,
      "messageId": messageId,
    };

    final int seq = _sendMessage(83, payload);
    print('Запрашиваем URL для videoId: $videoId (seq: $seq)');

    try {
      final response = await messages
          .firstWhere((msg) => msg['seq'] == seq && msg['opcode'] == 83)
          .timeout(const Duration(seconds: 15));

      if (response['cmd'] == 3) {
        throw Exception(
          'Ошибка получения URL видео: ${response['payload']?['message']}',
        );
      }

      final videoPayload = response['payload'] as Map<String, dynamic>?;
      if (videoPayload == null) {
        throw Exception('Получен пустой payload для видео');
      }

      String? videoUrl =
          videoPayload['MP4_720'] as String? ??
          videoPayload['MP4_480'] as String? ??
          videoPayload['MP4_1080'] as String? ??
          videoPayload['MP4_360'] as String?;

      if (videoUrl == null) {
        final mp4Key = videoPayload.keys.firstWhere(
          (k) => k.startsWith('MP4_'),
          orElse: () => '',
        );
        if (mp4Key.isNotEmpty) {
          videoUrl = videoPayload[mp4Key] as String?;
        }
      }

      if (videoUrl != null) {
        print('URL для videoId: $videoId успешно получен.');
        return videoUrl;
      } else {
        throw Exception('Не найден ни один MP4 URL в ответе');
      }
    } on TimeoutException {
      print('Таймаут ожидания URL для videoId: $videoId');
      throw Exception('Сервер не ответил на запрос видео вовремя');
    } catch (e) {
      print('Ошибка в getVideoUrl: $e');
      rethrow; // Передаем ошибку дальше
    }
  }

  void disconnect() {
    print("Отключаем WebSocket...");
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel(); // Отменяем подписку на stream
    _isSessionOnline = false;
    _isSessionReady = false;
    _handshakeSent = false; // Сбрасываем флаг handshake
    _onlineCompleter = Completer<void>();
    _chatsFetchedInThisSession = false;

    _channel?.sink.close(status.goingAway);
    _channel = null;
    _streamSubscription = null;

    _connectionStatusController.add("disconnected");
  }

  Future<String?> getClipboardData() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  void forceReconnect() {
    print("Принудительное переподключение...");

    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_channel != null) {
      print("Закрываем существующее соединение...");
      _channel!.sink.close(status.goingAway);
      _channel = null;
    }

    _isReconnecting = false;
    _reconnectAttempts = 0;
    _reconnectDelaySeconds = 2;
    _isSessionOnline = false;
    _isSessionReady = false;
    _chatsFetchedInThisSession = false;
    _currentUrlIndex = 0;
    _onlineCompleter = Completer<void>(); // Re-create completer

    clearAllCaches();
    _messageQueue.clear();
    _presenceData.clear();

    _connectionStatusController.add("connecting");
    _log("Запускаем новую сессию подключения...");

    _connectWithFallback();
  }

  Future<void> performFullReconnection() async {
    print("🔄 Начинаем полное переподключение...");
    try {
      _pingTimer?.cancel();
      _reconnectTimer?.cancel();
      _streamSubscription?.cancel();

      if (_channel != null) {
        _channel!.sink.close();
        _channel = null;
      }

      _isReconnecting = false;
      _reconnectAttempts = 0;
      _reconnectDelaySeconds = 2;
      _isSessionOnline = false;
      _isSessionReady = false;
      _handshakeSent = false;
      _chatsFetchedInThisSession = false; // КРИТИЧНО: сбрасываем этот флаг
      _currentUrlIndex = 0;
      _onlineCompleter = Completer<void>();
      _seq = 0;

      _lastChatsPayload = null;
      _lastChatsAt = null;

      print(
        " Кэш чатов очищен: _lastChatsPayload = $_lastChatsPayload, _chatsFetchedInThisSession = $_chatsFetchedInThisSession",
      );

      _connectionStatusController.add("disconnected");

      await connect();

      print(" Полное переподключение завершено");

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!_reconnectionCompleteController.isClosed) {
        print(" Отправляем уведомление о завершении переподключения");
        _reconnectionCompleteController.add(null);
      }
    } catch (e) {
      print("Ошибка полного переподключения: $e");
      rethrow;
    }
  }

  // ЫЫЫ ХУЯРЮ ВПЕРОД В БОГАЖНЕКЕ ГРАНАТАМЁТ
  Future<void> updatePrivacySettings({
    String? hidden,
    String? searchByPhone,
    String? incomingCall,
    String? chatsInvite,
    bool? chatsPushNotification,
    String? chatsPushSound,
    String? pushSound,
    bool? mCallPushNotification,
    bool? pushDetails,
    bool? contentLevelAccess,
  }) async {
    final settings = {
      if (hidden != null) 'user': {'HIDDEN': hidden == 'true'},
      if (searchByPhone != null) 'user': {'SEARCH_BY_PHONE': searchByPhone},
      if (incomingCall != null) 'user': {'INCOMING_CALL': incomingCall},
      if (chatsInvite != null) 'user': {'CHATS_INVITE': chatsInvite},
      if (chatsPushNotification != null)
        'user': {'PUSH_NEW_CONTACTS': chatsPushNotification},
      if (chatsPushSound != null) 'user': {'PUSH_SOUND': chatsPushSound},
      if (pushSound != null) 'user': {'PUSH_SOUND_GLOBAL': pushSound},
      if (mCallPushNotification != null)
        'user': {'PUSH_MCALL': mCallPushNotification},
      if (pushDetails != null) 'user': {'PUSH_DETAILS': pushDetails},
    };

    print(''); // КАК ЖЕ ПОХУЙ

    if (hidden != null) {
      await _updateSinglePrivacySetting({'HIDDEN': hidden == 'true'});
    }
    if (searchByPhone != null) {
      final seq = searchByPhone == 'ALL' ? 37 : 46;
      await _updatePrivacySettingWithSeq({
        'SEARCH_BY_PHONE': searchByPhone,
      }, seq);
    }
    if (incomingCall != null) {
      final seq = incomingCall == 'ALL' ? 30 : 23;
      await _updatePrivacySettingWithSeq({'INCOMING_CALL': incomingCall}, seq);
    }
    if (chatsInvite != null) {
      final seq = chatsInvite == 'ALL' ? 51 : 55;
      await _updatePrivacySettingWithSeq({'CHATS_INVITE': chatsInvite}, seq);
    }
    if (contentLevelAccess != null) {
      final seq = contentLevelAccess ? 70 : 62;
      await _updatePrivacySettingWithSeq({
        'CONTENT_LEVEL_ACCESS': contentLevelAccess,
      }, seq);
    }

    if (chatsPushNotification != null) {
      await _updateSinglePrivacySetting({
        'PUSH_NEW_CONTACTS': chatsPushNotification,
      });
    }
    if (chatsPushSound != null) {
      await _updateSinglePrivacySetting({'PUSH_SOUND': chatsPushSound});
    }
    if (pushSound != null) {
      await _updateSinglePrivacySetting({'PUSH_SOUND_GLOBAL': pushSound});
    }
    if (mCallPushNotification != null) {
      await _updateSinglePrivacySetting({'PUSH_MCALL': mCallPushNotification});
    }
    if (pushDetails != null) {
      await _updateSinglePrivacySetting({'PUSH_DETAILS': pushDetails});
    }
  }

  Future<void> _updateSinglePrivacySetting(Map<String, dynamic> setting) async {
    await waitUntilOnline();

    final payload = {
      'settings': {'user': setting},
    };

    _sendMessage(22, payload);
    print(''); //песюны
  }

  Future<void> _updatePrivacySettingWithSeq(
    Map<String, dynamic> setting,
    int seq,
  ) async {
    await waitUntilOnline();

    final message = {
      "ver": 11,
      "cmd": 0,
      "seq": seq,
      "opcode": 22,
      "payload": {
        "settings": {"user": setting},
      },
    };

    final encodedMessage = jsonEncode(message);
    _channel?.sink.add(encodedMessage);
    _log('SEND: $encodedMessage');
    print(
      '', //вроде надо а вроде бля как же похуй
    );
  }

  void _processServerPrivacyConfig(Map<String, dynamic>? config) {
    if (config == null) return;

    final userConfig = config['user'] as Map<String, dynamic>?;
    if (userConfig == null) return;

    print('Обработка настроек приватности с сервера: $userConfig');

    // Сохраняем настройки в SharedPreferences
    final prefs = SharedPreferences.getInstance();
    prefs.then((prefs) {
      if (userConfig.containsKey('SEARCH_BY_PHONE')) {
        prefs.setString(
          'privacy_search_by_phone',
          userConfig['SEARCH_BY_PHONE'],
        );
      }
      if (userConfig.containsKey('INCOMING_CALL')) {
        prefs.setString('privacy_incoming_call', userConfig['INCOMING_CALL']);
      }
      if (userConfig.containsKey('CHATS_INVITE')) {
        prefs.setString('privacy_chats_invite', userConfig['CHATS_INVITE']);
      }
      if (userConfig.containsKey('CONTENT_LEVEL_ACCESS')) {
        prefs.setBool(
          'privacy_content_level_access',
          userConfig['CONTENT_LEVEL_ACCESS'],
        );
      }
      if (userConfig.containsKey('HIDDEN')) {
        prefs.setBool('privacy_hidden', userConfig['HIDDEN']);
      }
    });

    // Отправляем событие об обновлении настроек
    _messageController.add({
      'type': 'privacy_settings_updated',
      'settings': {'user': userConfig},
    });
  }

  void dispose() {
    _pingTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _reconnectionCompleteController.close();
    _messageController.close();
  }
}
