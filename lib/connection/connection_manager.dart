import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:gwid/app_urls.dart';

import 'connection_logger.dart';
import 'connection_state.dart';
import 'retry_strategy.dart';
import 'health_monitor.dart';

class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  final ConnectionLogger _logger = ConnectionLogger();
  final ConnectionStateManager _stateManager = ConnectionStateManager();
  final RetryManager _retryManager = RetryManager();
  final HealthMonitor _healthMonitor = HealthMonitor();

  IOWebSocketChannel? _channel;
  StreamSubscription? _messageSubscription;

  final List<String> _serverUrls = AppUrls.websocketUrls;

  int _currentUrlIndex = 0;
  String? _currentServerUrl;

  bool _isConnecting = false;
  bool _isDisposed = false;
  int _sequenceNumber = 0;
  String? _authToken;

  final List<Map<String, dynamic>> _messageQueue = [];

  Timer? _pingTimer;
  Timer? _reconnectTimer;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;

  Stream<ConnectionInfo> get stateStream => _stateManager.stateStream;

  Stream<LogEntry> get logStream => _logger.logStream;

  Stream<HealthMetrics> get healthMetricsStream => _healthMonitor.metricsStream;

  ConnectionInfo get currentState => _stateManager.currentInfo;

  bool get isConnected => currentState.isActive;

  bool get canSendMessages => currentState.canSendMessages;

  Future<void> initialize() async {
    if (_isDisposed) {
      _logger.logError('Попытка инициализации после dispose');
      return;
    }

    _logger.logConnection('Инициализация ConnectionManager');
    _stateManager.setState(
      ConnectionState.disconnected,
      message: 'Инициализация',
    );
  }

  Future<void> _fullReconnect() async {
    _logger.logConnection('Начинаем полное переподключение');

    _cleanup();
    _stopMonitoring();

    _currentUrlIndex = 0;
    _sequenceNumber = 0;
    _messageQueue.clear();

    _stateManager.setState(
      ConnectionState.disconnected,
      message: 'Подготовка к переподключению',
    );

    await Future.delayed(const Duration(milliseconds: 250));

    await connect(authToken: _authToken);
  }

  Future<void> connect({String? authToken}) async {
    if (_isDisposed) {
      _logger.logError('Попытка подключения после dispose');
      return;
    }

    if (_isConnecting) {
      _logger.logConnection('Подключение уже в процессе');
      return;
    }

    _authToken = authToken;
    _isConnecting = true;

    _logger.logConnection(
      'Начало подключения',
      data: {
        'auth_token_present': authToken != null,
        'server_count': _serverUrls.length,
      },
    );

    _stateManager.setState(
      ConnectionState.connecting,
      message: 'Подключение к серверу',
      attemptNumber: 1,
    );

    try {
      await _connectWithFallback();
    } catch (e) {
      _logger.logError('Ошибка подключения', error: e);
      _stateManager.setState(
        ConnectionState.error,
        message: 'Ошибка подключения: ${e.toString()}',
      );
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _connectWithFallback() async {
    final sessionId = 'connect_${DateTime.now().millisecondsSinceEpoch}';
    final session = _retryManager.startSession(sessionId, ErrorType.network);

    while (_currentUrlIndex < _serverUrls.length) {
      final url = _serverUrls[_currentUrlIndex];
      _currentServerUrl = url;

      _logger.logConnection(
        'Попытка подключения',
        data: {
          'url': url,
          'attempt': _currentUrlIndex + 1,
          'total_servers': _serverUrls.length,
        },
      );

      try {
        await _connectToUrl(url);

        _logger.logConnection(
          'Успешное подключение',
          data: {'url': url, 'server_index': _currentUrlIndex},
        );

        _stateManager.setState(
          ConnectionState.connected,
          message: 'Подключен к серверу',
          serverUrl: url,
        );

        _healthMonitor.startMonitoring(serverUrl: url);
        _retryManager.endSession(sessionId);
        return;
      } catch (e) {
        final errorInfo = ErrorInfo(
          type: _getErrorType(e),
          message: e.toString(),
          timestamp: DateTime.now(),
        );

        session.addAttempt(errorInfo.type, message: e.toString());

        _logger.logError(
          'Ошибка подключения к серверу',
          data: {
            'url': url,
            'error': e.toString(),
            'error_type': errorInfo.type.name,
          },
        );

        _currentUrlIndex++;

        if (_currentUrlIndex < _serverUrls.length) {
          final delay = Duration(milliseconds: 500);
          _logger.logConnection(
            'Переход к следующему серверу через ${delay.inMilliseconds}ms',
          );
          await Future.delayed(delay);
        }
      }
    }

    _logger.logError(
      'Все серверы недоступны',
      data: {'total_servers': _serverUrls.length},
    );

    _stateManager.setState(
      ConnectionState.error,
      message: 'Все серверы недоступны',
    );

    throw Exception('Не удалось подключиться ни к одному серверу');
  }

  Future<void> _connectToUrl(String url) async {
    final uri = Uri.parse(url);

    _logger.logConnection(
      'Подключение к URL',
      data: {'host': uri.host, 'port': uri.port, 'scheme': uri.scheme},
    );

    final headers = <String, String>{
      'Origin': AppUrls.webOrigin,
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Sec-WebSocket-Extensions': 'permessage-deflate',
    };

    _channel = IOWebSocketChannel.connect(uri, headers: headers);
    await _channel!.ready;

    _logger.logConnection('WebSocket канал готов');

    _setupMessageListener();
    await _sendHandshake();
    _startPingTimer();
  }

  void _setupMessageListener() {
    _messageSubscription?.cancel();

    _messageSubscription = _channel!.stream.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDisconnection,
      cancelOnError: true,
    );

    _logger.logConnection('Слушатель сообщений настроен');
  }

  void _handleMessage(dynamic message) {
    if (message == null || (message is String && message.trim().isEmpty)) {
      return;
    }

    try {
      _logger.logMessage('IN', message);

      final decodedMessage = message is String ? jsonDecode(message) : message;

      if (decodedMessage is Map && decodedMessage['opcode'] == 1) {
        _healthMonitor.onPongReceived();
      }

      if (decodedMessage is Map &&
          decodedMessage['opcode'] == 6 &&
          decodedMessage['cmd'] == 1) {
        _handleHandshakeSuccess(Map<String, dynamic>.from(decodedMessage));
        return;
      }

      if (decodedMessage is Map && decodedMessage['cmd'] == 3) {
        _handleServerError(Map<String, dynamic>.from(decodedMessage));
        return;
      }

      if (decodedMessage is Map &&
          decodedMessage['opcode'] == 97 &&
          decodedMessage['cmd'] == 1) {
        _handleSessionTermination();
        return;
      }

      _messageController.add(decodedMessage);
    } catch (e) {
      _logger.logError(
        'Ошибка обработки сообщения',
        data: {'message': message.toString(), 'error': e.toString()},
      );
    }
  }

  void _handleHandshakeSuccess(Map<String, dynamic> message) {
    _logger.logConnection(
      'Handshake успешен',
      data: {'payload': message['payload']},
    );

    _stateManager.setState(
      ConnectionState.ready,
      message: 'Сессия готова к работе',
    );

    _processMessageQueue();
  }

  void _handleServerError(Map<String, dynamic> message) {
    final error = message['payload'];
    _logger.logError('Ошибка сервера', data: {'error': error});

    if (error != null) {
      if (error['error'] == 'proto.state') {
        _logger.logConnection('Ошибка состояния сессии, переподключаемся');
        _scheduleReconnect('Ошибка состояния сессии');
      } else if (error['error'] == 'login.token') {
        _logger.logConnection('Недействительный токен');
        _handleInvalidToken();
      }
    }
  }

  void _handleSessionTermination() {
    _logger.logConnection('Сессия завершена сервером');
    _stateManager.setState(
      ConnectionState.disconnected,
      message: 'Сессия завершена сервером',
    );
    _clearAuthData();
  }

  void _handleInvalidToken() {
    _logger.logConnection('Обработка недействительного токена');
    _clearAuthData();
    _stateManager.setState(
      ConnectionState.disconnected,
      message: 'Требуется повторная авторизация',
    );
  }

  void _clearAuthData() {
    _authToken = null;
    _logger.logConnection('Данные аутентификации очищены');
  }

  void _handleError(dynamic error) {
    _logger.logError('Ошибка WebSocket', error: error);
    _healthMonitor.onError(error.toString());
    _scheduleReconnect('Ошибка WebSocket: $error');
  }

  void _handleDisconnection() {
    _logger.logConnection('WebSocket соединение закрыто');
    _healthMonitor.onReconnect();
    _scheduleReconnect('Соединение закрыто');
  }

  void _scheduleReconnect(String reason) {
    if (_isDisposed) return;

    _reconnectTimer?.cancel();

    final sessionId = 'reconnect_${DateTime.now().millisecondsSinceEpoch}';
    final session = _retryManager.startSession(sessionId, ErrorType.network);

    if (!session.canRetry()) {
      _logger.logError(
        'Превышено максимальное количество попыток переподключения',
      );
      _stateManager.setState(
        ConnectionState.error,
        message: 'Не удалось переподключиться',
      );
      return;
    }

    final delay = session.getNextDelay();

    _logger.logReconnect(session.attemptCount + 1, reason, delay: delay);

    _stateManager.setState(
      ConnectionState.reconnecting,
      message: 'Переподключение через ${delay.inSeconds}с',
      reconnectDelay: delay,
    );

    _reconnectTimer = Timer(delay, () async {
      try {
        await _fullReconnect();
      } catch (e) {
        _logger.logError('Ошибка во время полного переподключения', error: e);

        _scheduleReconnect('Ошибка при попытке полного переподключения');
      }
    });
  }

  Future<void> _sendHandshake() async {
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

  int _sendMessage(int opcode, Map<String, dynamic> payload) {
    if (_channel == null) {
      _logger.logError('WebSocket не подключен');
      return -1;
    }

    final message = {
      "ver": 11,
      "cmd": 0,
      "seq": _sequenceNumber,
      "opcode": opcode,
      "payload": payload,
    };

    final encodedMessage = jsonEncode(message);
    _logger.logMessage('OUT', encodedMessage);

    _channel!.sink.add(encodedMessage);
    return _sequenceNumber++;
  }

  int sendMessage(int opcode, Map<String, dynamic> payload) {
    if (!canSendMessages) {
      _logger.logConnection(
        'Сообщение добавлено в очередь',
        data: {'opcode': opcode, 'reason': 'Соединение не готово'},
      );
      _messageQueue.add({'opcode': opcode, 'payload': payload});
      return -1;
    }

    return _sendMessage(opcode, payload);
  }

  void _processMessageQueue() {
    if (_messageQueue.isEmpty) return;

    _logger.logConnection(
      'Обработка очереди сообщений',
      data: {'count': _messageQueue.length},
    );

    for (final message in _messageQueue) {
      _sendMessage(message['opcode'], message['payload']);
    }

    _messageQueue.clear();
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (canSendMessages) {
        _logger.logConnection('Отправка ping');
        _sendMessage(1, {"interactive": true});
      }
    });
  }

  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 1000000).toString().padLeft(6, '0');
    return "$timestamp$random";
  }

  ErrorType _getErrorType(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('network')) {
      return ErrorType.network;
    }

    if (errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return ErrorType.authentication;
    }

    if (errorString.contains('server') || errorString.contains('internal')) {
      return ErrorType.server;
    }

    return ErrorType.unknown;
  }

  Future<void> disconnect() async {
    _logger.logConnection('Отключение');

    _stateManager.setState(
      ConnectionState.disconnected,
      message: 'Отключение по запросу',
    );

    _stopMonitoring();
    _cleanup();
  }

  Future<void> forceReconnect() async {
    if (_isDisposed) {
      _logger.logError('Попытка переподключения после dispose');
      return;
    }

    _logger.logConnection('Принудительное переподключение');

    _reconnectTimer?.cancel();
    _pingTimer?.cancel();

    _cleanup();
    _currentUrlIndex = 0;
    _sequenceNumber = 0;
    _messageQueue.clear();

    _stateManager.setState(
      ConnectionState.disconnected,
      message: 'Подготовка к переподключению',
    );

    await Future.delayed(const Duration(milliseconds: 500));

    await connect(authToken: _authToken);
  }

  void _stopMonitoring() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _messageSubscription?.cancel();
    _healthMonitor.stopMonitoring();
  }

  void _cleanup() {
    _channel?.sink.close(status.goingAway);
    _channel = null;
    _messageQueue.clear();
    _currentUrlIndex = 0;
    _sequenceNumber = 0;
  }

  Map<String, dynamic> getStatistics() {
    return {
      'connection_state': currentState.state.name,
      'health_metrics': _healthMonitor.getStatistics(),
      'retry_statistics': _retryManager.getStatistics(),
      'log_statistics': _logger.getLogStats(),
      'message_queue_size': _messageQueue.length,
      'current_server': _currentServerUrl,
      'server_index': _currentUrlIndex,
    };
  }

  void dispose() {
    if (_isDisposed) return;

    _logger.logConnection('Освобождение ресурсов ConnectionManager');

    _isDisposed = true;
    _stopMonitoring();
    _cleanup();

    _messageController.close();
    _connectionStatusController.close();
    _stateManager.dispose();
    _logger.dispose();
    _healthMonitor.dispose();
  }
}
