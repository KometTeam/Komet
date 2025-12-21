part of 'api_service.dart';

extension ApiServiceConnection on ApiService {
  Future<void> _resetSocket({bool close = true}) async {
    _socketConnected = false;
    _isSessionOnline = false;
    _isSessionReady = false;
    _handshakeSent = false;
    _onlineCompleter = Completer<void>();
    _buffer = Uint8List(0);

    _socketSubscription?.cancel();
    _socketSubscription = null;

    if (close && _socket != null) {
      try {
        await _socket!.close();
      } catch (_) {}
    }
    _socket = null;
  }

  Future<void> _connectWithFallback() async {
    if (_isConnecting) {
      print('⚠️ Подключение уже в процессе, пропускаем');
      return;
    }

    _isConnecting = true;
    _log('Начало подключения...');
    _updateConnectionState(
      conn_state.ConnectionState.connecting,
      message: 'Подключение к серверу',
    );

    try {
      await _connectToUrl('');
      _connectionLogController.add('✅ Подключено к серверу');
      _updateConnectionState(
        conn_state.ConnectionState.connecting,
        message: 'Соединение установлено, ожидание handshake',
      );
    } catch (e) {
      final errorMessage = '❌ Ошибка: ${e.toString().split(':').first}';
      _connectionLogController.add(errorMessage);
      _healthMonitor.onError(errorMessage);
      _updateConnectionState(
        conn_state.ConnectionState.error,
        message: 'Не удалось подключиться к серверу',
      );
      _stopHealthMonitoring();
      rethrow;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _connectToUrl(String url) async {
    await _resetSocket(close: true);
    _currentServerUrl = 'api.oneme.ru:443';
    final bool hadChatsFetched = _chatsFetchedInThisSession;
    final bool hasValidToken = authToken != null;

    if (!hasValidToken) {
      _chatsFetchedInThisSession = false;
    } else {
      _chatsFetchedInThisSession = hadChatsFetched;
    }

    _connectionStatusController.add('connecting');

    _initLz4BlockDecompress();

    try {
      final securityContext = SecurityContext.defaultContext;
      final rawSocket = await Socket.connect('api.oneme.ru', 443);
      _socket = await SecureSocket.secure(
        rawSocket,
        context: securityContext,
        host: 'api.oneme.ru',
        onBadCertificate: (certificate) => true,
      );

      _socketConnected = true;
      _buffer = Uint8List(0);
      _seq = 0;

      _listen();
      await _sendHandshake();
      _startPinging();
    } catch (e) {
      _socketConnected = false;
      rethrow;
    }
  }

  void _handleSessionTerminated() {
    _isSessionOnline = false;
    _isSessionReady = false;
    _stopHealthMonitoring();
    _updateConnectionState(
      conn_state.ConnectionState.disconnected,
      message: 'Сессия завершена сервером',
    );

    authToken = null;

    clearAllCaches();

    _messageController.add({
      'type': 'session_terminated',
      'message': 'Твоя сессия больше не активна, войди снова',
    });
  }

  void _handleInvalidToken() async {
    _isSessionOnline = false;
    _isSessionReady = false;
    _stopHealthMonitoring();
    _healthMonitor.onError('invalid_token');
    _updateConnectionState(
      conn_state.ConnectionState.error,
      message: 'Недействительный токен',
    );

    authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');

    clearAllCaches();

    _socket?.close();
    _socket = null;
    _socketConnected = false;
    _pingTimer?.cancel();

    _messageController.add({
      'type': 'invalid_token',
      'message': 'Токен недействителен, требуется повторная авторизация',
    });
  }

  Future<void> _sendHandshake() async {
    if (_handshakeSent) {
      return;
    }

    final userAgentPayload = await _buildUserAgentPayload();

    final prefs = await SharedPreferences.getInstance();
    final deviceId =
        prefs.getString('spoof_deviceid') ?? generateRandomDeviceId();

    if (prefs.getString('spoof_deviceid') == null) {
      await prefs.setString('spoof_deviceid', deviceId);
    }

    final payload = {'deviceId': deviceId, 'userAgent': userAgentPayload};

    await _sendMessage(6, payload);
    _handshakeSent = true;
  }

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) async {
      if (_isSessionOnline && _isSessionReady && _isAppInForeground) {
        try {
          await _sendMessage(1, {"interactive": true});
        } catch (e) {
          print('Ошибка отправки ping: $e');
        }
      }
    });
  }

  Future<void> connect() async {
    if (_socketConnected && _isSessionOnline) {
      return;
    }

    if (_isConnecting) {
      print('⚠️ Подключение уже в процессе, пропускаем');
      return;
    }

    _isSessionOnline = false;
    _isSessionReady = false;

    _connectionStatusController.add("connecting");
    _updateConnectionState(
      conn_state.ConnectionState.connecting,
      message: 'Инициализация подключения',
    );
    await _connectWithFallback();
  }

  Future<void> reconnect() async {
    _reconnectAttempts = 0;
    _currentUrlIndex = 0;

    _connectionStatusController.add("connecting");
    await _connectWithFallback();
  }

  Future<void> sendFullJsonRequest(String jsonString) async {
    if (!_socketConnected || _socket == null) {
      throw Exception('Socket is not connected. Connect first.');
    }
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final opcode = decoded['opcode'];
      final payload = decoded['payload'];
      _log('➡️ SEND: opcode=$opcode, payload=$payload');
      await _sendMessage(opcode, payload);
    } catch (_) {
      _log('➡️ SEND (raw): $jsonString');
    }
  }

  Future<int> sendRawRequest(int opcode, Map<String, dynamic> payload) async {
    if (!_socketConnected || _socket == null) {
      print('Socket не подключен!');
      throw Exception('Socket is not connected. Connect first.');
    }

    return await _sendMessage(opcode, payload);
  }

  Future<int> sendAndTrackFullJsonRequest(String jsonString) async {
    if (!_socketConnected || _socket == null) {
      throw Exception('Socket is not connected. Connect first.');
    }

    final message = jsonDecode(jsonString) as Map<String, dynamic>;
    final opcode = message['opcode'];
    final payload = message['payload'] as Map<String, dynamic>;

    return await _sendMessage(opcode, payload);
  }

  Future<int> _sendMessage(int opcode, Map<String, dynamic> payload) async {
    if (!_socketConnected || _socket == null) {
        print('⚠️ Сокет не подключен, пропускаем opcode=$opcode');
      _reconnect();
        return -1;
    }

    try {
      if (_socket == null) {
        print('⚠️ Сокет не инициализирован, пропускаем opcode=$opcode');
        return -1;
      }
      _socket!.remoteAddress;
    } catch (e) {
      print('⚠️ Сокет закрыт, пропускаем opcode=$opcode');
      _socketConnected = false;
      _socket = null;
      return -1;
    }

    _seq = (_seq + 1) % 256;
    final seq = _seq;
    final packet = _packPacket(10, 0, seq, opcode, payload);

    print('📤 ОТПРАВКА: ver=10, cmd=0, seq=$seq, opcode=$opcode');
    if (opcode != 19) {
      print('📤 PAYLOAD: $payload');
    }
    print('📤 Размер пакета: ${packet.length} байт');

    try {
      _socket!.add(packet);
    } catch (e) {
      print('❌ Ошибка отправки пакета: $e');
      await _resetSocket(close: true);
      return -1;
    }

    return seq;
  }

  void _listen() async {
    if (!_socketConnected || _socket == null) {
      return;
    }

    if (_socketSubscription != null) {
      return;
    }

    _socketSubscription = _socket!.listen(
      _handleSocketData,
      onError: (error) {
        print('← ERROR Socket: $error');
        _isSessionOnline = false;
        _isSessionReady = false;
        _socketConnected = false;
        _healthMonitor.onError(error.toString());
        _updateConnectionState(
          conn_state.ConnectionState.error,
          message: error.toString(),
        );
        _reconnect();
      },
      onDone: () {
        print('← Socket closed');
        _isSessionOnline = false;
        _isSessionReady = false;
        _socketConnected = false;
        _stopHealthMonitoring();
        _updateConnectionState(
          conn_state.ConnectionState.disconnected,
          message: 'Соединение закрыто',
        );
          _reconnect();
      },
      cancelOnError: true,
    );
  }

  void handleSocketMessage(Map<String, dynamic> decodedMessage) {
    try {
      final ver = decodedMessage['ver'] as int?;
      final opcode = decodedMessage['opcode'] as int?;
      final cmd = decodedMessage['cmd'] as int?;
      final seq = decodedMessage['seq'] as int?;
      final payload = decodedMessage['payload'];

      if (opcode == null || cmd == null || seq == null) {
        print('⚠️ Некорректное сообщение: ver=$ver, opcode=$opcode, cmd=$cmd, seq=$seq');
        return;
      }

      final cmdType = (cmd == 0x100 || cmd == 256) ? 'OK' : (cmd == 0x300 || cmd == 768) ? 'ERROR' : 'UNKNOWN($cmd)';
      print('📥 ПОЛУЧЕНО: ver=$ver, cmd=$cmd ($cmdType), seq=$seq, opcode=$opcode');
      if (opcode != 19) {
        print('📥 PAYLOAD: $payload');
      }

      if (opcode == 2) {
        _healthMonitor.onPongReceived();
      }

      if (cmd == 0x300 || cmd == 768) {
        print('❌ ОШИБКА СЕРВЕРА: opcode=$opcode, seq=$seq');
        print('❌ Детали ошибки: $payload');
      }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 97 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256) &&
              decodedMessage['payload'] != null &&
              decodedMessage['payload']['token'] != null) {
            _handleSessionTerminated();
            return;
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 6 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            _isSessionOnline = true;
            _isSessionReady = false;
            _reconnectDelaySeconds = 2;
            _connectionStatusController.add("authorizing");
            _updateConnectionState(
              conn_state.ConnectionState.connected,
              message: 'Handshake успешен',
            );
            _startHealthMonitoring();

            _startPinging();
            _processMessageQueue();

            if (authToken != null && !_chatsFetchedInThisSession) {
              unawaited(_sendAuthRequestAfterHandshake());
            } else if (authToken == null) {
              _isSessionReady = true;
              if (_onlineCompleter != null && !_onlineCompleter!.isCompleted) {
                _onlineCompleter!.complete();
              }
            }
          }

          if (decodedMessage is Map &&
              (decodedMessage['cmd'] == 0x300 || decodedMessage['cmd'] == 768)) {
            final error = decodedMessage['payload'];
            final errorMsg = error?['message'] ?? error?['error'] ?? 'server_error';
              print('← ERROR: $errorMsg');
              _healthMonitor.onError(errorMsg);

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
              print('⚠️ Ошибка proto.state: сессия не готова для этого запроса, игнорируем');
              return;
            }

            if (error != null && error['error'] == 'login.token') {
              _handleInvalidToken();
              return;
            }

            if (error != null && error['message'] == 'FAIL_WRONG_PASSWORD') {
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
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256) &&
              decodedMessage['payload'] != null) {
            final payload = decodedMessage['payload'];
            if (payload['passwordChallenge'] != null) {
              final challenge = payload['passwordChallenge'];
              _currentPasswordTrackId = challenge['trackId'];
              _currentPasswordHint = challenge['hint'];
              _currentPasswordEmail = challenge['email'];


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
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'privacy_settings_updated',
              'settings': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 116 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'password_set_success',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 57 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'group_join_success',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 46 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'contact_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 46 &&
              (decodedMessage['cmd'] == 0x300 || decodedMessage['cmd'] == 768)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'contact_not_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 32 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channels_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 32 &&
              (decodedMessage['cmd'] == 0x300 || decodedMessage['cmd'] == 768)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channels_not_found',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 89 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            final payload = decodedMessage['payload'];
            final chat = payload['chat'] as Map<String, dynamic>?;
            
            if (chat != null) {
              final chatType = chat['type'] as String?;
              if (chatType == 'CHAT') {
                _messageController.add({
                  'type': 'group_join_success',
                  'payload': payload,
                });
              } else {
                _messageController.add({
                  'type': 'channel_entered',
                  'payload': payload,
                });
              }
            } else {
              _messageController.add({
                'type': 'channel_entered',
                'payload': payload,
              });
            }
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 89 &&
              (decodedMessage['cmd'] == 0x300 || decodedMessage['cmd'] == 768)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channel_error',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 57 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channel_subscribed',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 57 &&
              (decodedMessage['cmd'] == 0x300 || decodedMessage['cmd'] == 768)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'channel_error',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 59 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            final payload = decodedMessage['payload'];
            _messageController.add({
              'type': 'group_members',
              'payload': payload,
            });
          }

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 162 &&
              (decodedMessage['cmd'] == 0x100 || decodedMessage['cmd'] == 256)) {
            final payload = decodedMessage['payload'];
            try {
              final complaintData = ComplaintData.fromJson(payload);
              _messageController.add({
                'type': 'complaints_data',
                'complaintData': complaintData,
              });
            } catch (e) {
              print('← ERROR parsing complaints: $e');
            }
          }

      if (decodedMessage is Map<String, dynamic>) {
        _messageController.add(decodedMessage);
      }
    } catch (e) {
      print('← ERROR invalid message: $e');
    }
  }

  void _reconnect() {
    if (_isReconnecting) return;

    _isReconnecting = true;
    _reconnectAttempts++;
    _healthMonitor.onReconnect();

    if (_reconnectAttempts > ApiService._maxReconnectAttempts) {
      print("← ERROR max reconnect attempts");
      _connectionStatusController.add("disconnected");
      _isReconnecting = false;
      _updateConnectionState(
        conn_state.ConnectionState.error,
        message: 'Превышено число попыток переподключения',
      );
      return;
    }

    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _socketSubscription = null;

    if (_socket != null) {
      try {
        _socket!.close();
      } catch (e) {}
      _socket = null;
    }
    _socketConnected = false;

    _isSessionOnline = false;
    _isSessionReady = false;
    _handshakeSent = false;
    _onlineCompleter = Completer<void>();
    _chatsFetchedInThisSession = false;

    _currentUrlIndex = 0;

    _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(1, 30);
    final jitter = (DateTime.now().millisecondsSinceEpoch % 1000) / 1000.0;
    final delay = Duration(seconds: _reconnectDelaySeconds + jitter.round());

    _reconnectTimer = Timer(delay, () {
      _isReconnecting = false;
      _updateConnectionState(
        conn_state.ConnectionState.reconnecting,
        attemptNumber: _reconnectAttempts,
        reconnectDelay: delay,
      );
      _connectWithFallback();
    });
  }

  void _processMessageQueue() {
    if (_messageQueue.isEmpty) return;
    for (var message in _messageQueue) {
      unawaited(_sendMessage(message['opcode'], message['payload']));
    }
    _messageQueue.clear();
  }

  void forceReconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    if (_socket != null) {
      _socket!.close();
      _socket = null;
    }
    _socketConnected = false;

    _isReconnecting = false;
    _reconnectAttempts = 0;
    _reconnectDelaySeconds = 2;
    _isSessionOnline = false;
    _isSessionReady = false;
    _chatsFetchedInThisSession = false;
    _currentUrlIndex = 0;
    _onlineCompleter = Completer<void>();

    _messageQueue.clear();
    _presenceData.clear();

    _connectionStatusController.add("connecting");
    _log("Запускаем новую сессию подключения...");

    _connectWithFallback();
  }

  Future<void> performFullReconnection() async {
    try {
      _pingTimer?.cancel();
      _reconnectTimer?.cancel();

      _socketSubscription?.cancel();
      _socketSubscription = null;

      if (_socket != null) {
        try {
          _socket!.close();
        } catch (e) {}
        _socket = null;
      }
      _socketConnected = false;

      _isReconnecting = false;
      _reconnectAttempts = 0;
      _reconnectDelaySeconds = 2;
      _isSessionOnline = false;
      _isSessionReady = false;
      _handshakeSent = false;
      _chatsFetchedInThisSession = false;
      _currentUrlIndex = 0;
      _onlineCompleter = Completer<void>();
      _seq = 0;

      _lastChatsPayload = null;
      _lastChatsAt = null;

      _connectionStatusController.add("disconnected");

      await connect();

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!_reconnectionCompleteController.isClosed) {
        _reconnectionCompleteController.add(null);
      }
    } catch (e) {
      print("← ERROR full reconnect: $e");
      rethrow;
    }
  }

  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _socketSubscription?.cancel();
    _isSessionOnline = false;
    _isSessionReady = false;
    _handshakeSent = false;
    _onlineCompleter = Completer<void>();
    _chatsFetchedInThisSession = false;
    _stopHealthMonitoring();
    _updateConnectionState(
      conn_state.ConnectionState.disconnected,
      message: 'Отключено пользователем',
    );

    _socket?.close();
    _socket = null;
    _socketConnected = false;
    _socketSubscription = null;

    _connectionStatusController.add("disconnected");
  }
}
