part of 'api_service.dart';

extension ApiServiceConnection on ApiService {
  Future<void> _connectWithFallback() async {
    _log('Начало подключения...');
    _updateConnectionState(
      conn_state.ConnectionState.connecting,
      message: 'Поиск доступного сервера',
    );

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
        _updateConnectionState(
          conn_state.ConnectionState.connecting,
          message: 'Соединение установлено, ожидание handshake',
          metadata: {'server': currentUrl},
        );
        if (_currentUrlIndex > 0) {
          _connectionStatusController.add('Подключено через резервный сервер');
        }
        return;
      } catch (e) {
        final errorMessage = '❌ Ошибка: ${e.toString().split(':').first}';
        print('Ошибка подключения к $currentUrl: $e');
        _connectionLogController.add(errorMessage);
        _healthMonitor.onError(errorMessage);
        _currentUrlIndex++;

        if (_currentUrlIndex < _wsUrls.length) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    _log('❌ Все серверы недоступны');
    _connectionStatusController.add('Все серверы недоступны');
    _updateConnectionState(
      conn_state.ConnectionState.error,
      message: 'Все серверы недоступны',
    );
    _stopHealthMonitoring();
    throw Exception('Не удалось подключиться ни к одному серверу');
  }

  Future<void> _connectToUrl(String url) async {
    _isSessionOnline = false;
    _onlineCompleter = Completer<void>();
    _currentServerUrl = url;
    final bool hadChatsFetched = _chatsFetchedInThisSession;
    final bool hasValidToken = authToken != null;

    if (!hasValidToken) {
      _chatsFetchedInThisSession = false;
    } else {
      _chatsFetchedInThisSession = hadChatsFetched;
    }

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
        'Используем ${proxySettings.protocol.name.toUpperCase()} прокси ${proxySettings.host}:${proxySettings.port}',
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

  void _handleSessionTerminated() {
    print("Сессия была завершена сервером");
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
    print("Обработка недействительного токена");
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

    _channel?.sink.close();
    _channel = null;
    _pingTimer?.cancel();

    _messageController.add({
      'type': 'invalid_token',
      'message': 'Токен недействителен, требуется повторная авторизация',
    });
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

  void _startPinging() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isSessionOnline && _isSessionReady && _isAppInForeground) {
        print("Отправляем Ping для поддержания сессии...");
        _sendMessage(1, {"interactive": true});
      } else {
        print("Сессия не готова, пропускаем ping");
      }
    });
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

  void sendFullJsonRequest(String jsonString) {
    if (_channel == null) {
      throw Exception('WebSocket is not connected. Connect first.');
    }
    try {
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final opcode = decoded['opcode'];
      final payload = decoded['payload'];
      _log('➡️ SEND: opcode=$opcode, payload=$payload');
    } catch (_) {
      _log('➡️ SEND (raw): $jsonString');
    }
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

    _log('➡️ SEND: opcode=${message['opcode']}, payload=${message['payload']}');
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
    } else {
      _log('➡️ SEND: opcode=$opcode, payload=$payload');
    }
    print('Отправляем сообщение (seq: $_seq): $encodedMessage');
    _channel!.sink.add(encodedMessage);
    return _seq++;
  }

  void _listen() async {
    if (_channel == null) {
      return;
    }

    
    if (_streamSubscription != null) {
      return;
    }

    _streamSubscription = _channel!.stream.listen(
      (message) {
        if (message == null) return;
        if (message is String && message.trim().isEmpty) {
          return;
        }

        try {
          final decoded = jsonDecode(message) as Map<String, dynamic>;
          final opcode = decoded['opcode'];
          if (opcode == 2) {
            _healthMonitor.onPongReceived();
            _log('⬅️ RECV (pong) seq: ${decoded['seq']}');
          } else {
            final payload = decoded['payload'];
            _log('⬅️ RECV: opcode=$opcode, payload=$payload');
          }
        } catch (_) {
          _log('⬅️ RECV (raw): $message');
        }

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
            _updateConnectionState(
              conn_state.ConnectionState.connected,
              message: 'Handshake успешен',
            );
            _startHealthMonitoring();

            _startPinging();
            _processMessageQueue();

            if (authToken != null && !_chatsFetchedInThisSession) {
              print(
                "Токен найден, автоматически запускаем авторизацию (opcode 19)...",
              );
              unawaited(_sendAuthRequestAfterHandshake());
            } else if (authToken == null) {
              print(
                "Токен не найден, завершаем ожидание для неавторизованной сессии",
              );
              _isSessionReady = true;
              if (_onlineCompleter != null && !_onlineCompleter!.isCompleted) {
                _onlineCompleter!.complete();
              }
            }
          }

          if (decodedMessage is Map && decodedMessage['cmd'] == 3) {
            final error = decodedMessage['payload'];
            print('Ошибка сервера: $error');
            _healthMonitor.onError(error?['message'] ?? 'server_error');
            _updateConnectionState(
              conn_state.ConnectionState.error,
              message: error?['message'],
            );

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
            final chat = payload['chat'] as Map<String, dynamic>?;
            
            if (chat != null) {
              final chatType = chat['type'] as String?;
              if (chatType == 'CHAT') {
                print('Успешно присоединились к группе (opcode 89): $payload');
                _messageController.add({
                  'type': 'group_join_success',
                  'payload': payload,
                });
              } else {
                print('Вход в канал успешен: $payload');
                _messageController.add({
                  'type': 'channel_entered',
                  'payload': payload,
                });
              }
            } else {
              print('Вход в канал успешен: $payload');
              _messageController.add({
                'type': 'channel_entered',
                'payload': payload,
              });
            }
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

          if (decodedMessage is Map &&
              decodedMessage['opcode'] == 162 &&
              decodedMessage['cmd'] == 1) {
            final payload = decodedMessage['payload'];
            print('Получены данные жалоб: $payload');

            try {
              final complaintData = ComplaintData.fromJson(payload);
              _messageController.add({
                'type': 'complaints_data',
                'complaintData': complaintData,
              });
            } catch (e) {
              print('Ошибка парсинга данных жалоб: $e');
            }
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
        _healthMonitor.onError(error.toString());
        _updateConnectionState(
          conn_state.ConnectionState.error,
          message: error.toString(),
        );
        _reconnect();
      },
      onDone: () {
        print('WebSocket соединение закрыто. Попытка переподключения...');
        _isSessionOnline = false;
        _isSessionReady = false;
        _stopHealthMonitoring();
        _updateConnectionState(
          conn_state.ConnectionState.disconnected,
          message: 'Соединение закрыто',
        );

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
    _healthMonitor.onReconnect();

    if (_reconnectAttempts > ApiService._maxReconnectAttempts) {
      print(
        "Превышено максимальное количество попыток переподключения (${ApiService._maxReconnectAttempts}). Останавливаем попытки.",
      );
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
    _streamSubscription?.cancel();

    if (_channel != null) {
      print("Закрываем старое WebSocket соединение перед переподключением...");
      try {
        _channel!.sink.close(status.goingAway);
      } catch (e) {
        print("Ошибка при закрытии старого соединения: $e");
      }
      _channel = null;
    }

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
      print(
        "Переподключаемся после ${delay.inSeconds}s... (попытка $_reconnectAttempts/${ApiService._maxReconnectAttempts})",
      );
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
    print("Отправка ${_messageQueue.length} сообщений из очереди...");
    for (var message in _messageQueue) {
      _sendMessage(message['opcode'], message['payload']);
    }
    _messageQueue.clear();
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
    _onlineCompleter = Completer<void>();

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
      _streamSubscription = null;

      if (_channel != null) {
        print("🔄 Закрываем старое WebSocket соединение...");
        try {
          _channel!.sink.close(status.goingAway);
        } catch (e) {
          print("Ошибка при закрытии старого соединения: $e");
        }
        _channel = null;
      }

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

      print(
        "🔄 Кэш чатов очищен: _lastChatsPayload = $_lastChatsPayload, _chatsFetchedInThisSession = $_chatsFetchedInThisSession",
      );

      _connectionStatusController.add("disconnected");

      await connect();

      print("✅ Полное переподключение завершено");

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!_reconnectionCompleteController.isClosed) {
        print("✅ Отправляем уведомление о завершении переподключения");
        _reconnectionCompleteController.add(null);
      }
    } catch (e) {
      print("❌ Ошибка полного переподключения: $e");
      rethrow;
    }
  }

  void disconnect() {
    print("Отключаем WebSocket...");
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _streamSubscription?.cancel();
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

    _channel?.sink.close(status.goingAway);
    _channel = null;
    _streamSubscription = null;

    _connectionStatusController.add("disconnected");
  }
}
