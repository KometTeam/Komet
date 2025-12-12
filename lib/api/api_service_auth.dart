part of 'api_service.dart';

extension ApiServiceAuth on ApiService {
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

  Future<void> saveToken(
    String token, {
    String? userId,
    Profile? profile,
  }) async {
    print("Сохраняем новый токен: ${token.substring(0, 20)}...");
    if (userId != null) {
      print("Сохраняем UserID: $userId");
    }

    final accountManager = AccountManager();
    await accountManager.initialize();
    final account = await accountManager.addAccount(
      token: token,
      userId: userId,
      profile: profile,
    );
    await accountManager.switchAccount(account.id);

    authToken = token;
    this.userId = userId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('authToken', token);
    if (userId != null) {
      await prefs.setString('userId', userId);
    }

    _messageQueue.clear();
    _lastChatsPayload = null;
    _chatsFetchedInThisSession = false;
    _isSessionOnline = false;
    _isSessionReady = false;
    _handshakeSent = false;

    disconnect();

    await connect();
    await waitUntilOnline();

    await getChatsAndContacts(force: true);

    
    final profileJson = _lastChatsPayload?['profile'];
    if (profileJson != null) {
      final profileObj = Profile.fromJson(profileJson);
      await accountManager.updateAccountProfile(account.id, profileObj);
    }

    print("Токен и UserID успешно сохранены, сессия перезапущена");
  }

  Future<bool> hasToken() async {
    if (authToken == null) {
      final accountManager = AccountManager();
      await accountManager.initialize();
      await accountManager.migrateOldAccount();

      final currentAccount = accountManager.currentAccount;
      if (currentAccount != null) {
        authToken = currentAccount.token;
        userId = currentAccount.userId;
        
        
        
      } else {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString('authToken');
        userId = prefs.getString('userId');
        
        
        
        
        
        
        
        
      }
    }
    return authToken != null;
  }

  Future<void> _loadTokenFromAccountManager() async {
    final accountManager = AccountManager();
    await accountManager.initialize();
    final currentAccount = accountManager.currentAccount;
    if (currentAccount != null) {
      authToken = currentAccount.token;
      userId = currentAccount.userId;
    }
  }

  Future<void> switchAccount(String accountId) async {
    print("Переключение на аккаунт: $accountId");

    disconnect();

    final accountManager = AccountManager();
    await accountManager.initialize();
    await accountManager.switchAccount(accountId);

    final currentAccount = accountManager.currentAccount;
    if (currentAccount != null) {
      authToken = currentAccount.token;
      userId = currentAccount.userId;

      _messageQueue.clear();
      _lastChatsPayload = null;
      _chatsFetchedInThisSession = false;
      _isSessionOnline = false;
      _isSessionReady = false;
      _handshakeSent = false;

      await connect();

      await waitUntilOnline();

      await getChatsAndContacts(force: true);

      final profile = _lastChatsPayload?['profile'];
      if (profile != null) {
        final profileObj = Profile.fromJson(profile);
        await accountManager.updateAccountProfile(accountId, profileObj);
      }
    }
  }

  Future<void> logout() async {
    try {
      
      final accountManager = AccountManager();
      await accountManager.initialize();
      final currentAccount = accountManager.currentAccount;

      if (currentAccount != null) {
        try {
          if (accountManager.accounts.length > 1) {
            await accountManager.removeAccount(currentAccount.id);
          } else {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('authToken');
            await prefs.remove('userId');
            await prefs.remove('multi_accounts');
            await prefs.remove('current_account_id');
          }
        } catch (e) {
          print('Ошибка при удалении аккаунта: $e');
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('authToken');
          await prefs.remove('userId');
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('authToken');
        await prefs.remove('userId');
        await prefs.remove('multi_accounts');
        await prefs.remove('current_account_id');
      }

      
      authToken = null;
      userId = null;
      _messageCache.clear();
      _lastChatsPayload = null;
      _chatsFetchedInThisSession = false;
      _pingTimer?.cancel();
      await _channel?.sink.close(status.goingAway);
      _channel = null;

      clearAllCaches();

      _isSessionOnline = false;
      _isSessionReady = false;
      _handshakeSent = false;
      _reconnectAttempts = 0;
      _currentUrlIndex = 0;

      _messageQueue.clear();
      _presenceData.clear();
    } catch (e) {
      print('Ошибка logout(): $e');
    }
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

  
  Future<String> startRegistration(String phoneNumber) async {
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

    
    final completer = Completer<Map<String, dynamic>>();
    final subscription = messages.listen((message) {
      if (message['opcode'] == 17 && !completer.isCompleted) {
        completer.complete(message);
      }
    });

    _sendMessage(17, payload);

    try {
      final response = await completer.future.timeout(
        const Duration(seconds: 30),
      );
      subscription.cancel();

      final payload = response['payload'];
      if (payload != null && payload['token'] != null) {
        return payload['token'];
      } else {
        throw Exception('No registration token received');
      }
    } catch (e) {
      subscription.cancel();
      rethrow;
    }
  }

  Future<String> verifyRegistrationCode(String token, String code) async {
    final payload = {
      'token': token,
      'verifyCode': code,
      'authTokenType': 'CHECK_CODE',
    };

    final completer = Completer<Map<String, dynamic>>();
    final subscription = messages.listen((message) {
      if (message['opcode'] == 18 && !completer.isCompleted) {
        completer.complete(message);
      }
    });

    _sendMessage(18, payload);

    try {
      final response = await completer.future.timeout(
        const Duration(seconds: 30),
      );
      subscription.cancel();

      final payload = response['payload'];
      if (payload != null) {
        final tokenAttrs = payload['tokenAttrs'];
        if (tokenAttrs != null && tokenAttrs['REGISTER'] != null) {
          final regToken = tokenAttrs['REGISTER']['token'];
          if (regToken != null) {
            return regToken;
          }
        }
      }
      throw Exception('Registration token not found in response');
    } catch (e) {
      subscription.cancel();
      rethrow;
    }
  }

  Future<void> completeRegistration(String regToken) async {
    final payload = {
      "lastName": "User",
      "token": regToken,
      "firstName": "Komet",
      "tokenType": "REGISTER",
    };

    final completer = Completer<Map<String, dynamic>>();
    final subscription = messages.listen((message) {
      if (message['opcode'] == 23 && !completer.isCompleted) {
        completer.complete(message);
      }
    });

    _sendMessage(23, payload);

    try {
      await completer.future.timeout(const Duration(seconds: 30));
      subscription.cancel();
      print('Registration completed successfully');
    } catch (e) {
      subscription.cancel();
      rethrow;
    }
  }
}
