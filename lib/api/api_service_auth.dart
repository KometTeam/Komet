part of 'api_service.dart';

extension ApiServiceAuth on ApiService {
  Future<void> _clearAuthToken() async {
    print("Очищаем токен авторизации...");
    authToken = null;
    _lastChatsPayload = null;
    _lastChatsAt = null;
    _chatsFetchedInThisSession = false;

    if (!FreshModeHelper.shouldSkipSave()) {
      final prefs = await FreshModeHelper.getSharedPreferences();
      await prefs.remove('authToken');
    }

    clearAllCaches();
    _connectionStatusController.add("disconnected");
  }

  Future<void> requestOtp(String phoneNumber, {bool resend = false}) async {
    if (!_socketConnected || _socket == null) {
      await connect();
    }

    final payload = {
      "phone": phoneNumber,
      "type": resend ? "RESEND" : "START_AUTH",
    };
    await _sendMessage(17, payload);
  }

  void requestSessions() {
    _sendMessage(96, {});
  }

  void terminateAllSessions() {
    _isTerminatingOtherSessions = true;
    _sendMessage(97, {});
    Future.delayed(const Duration(seconds: 2), () {
      _isTerminatingOtherSessions = false;
    });
  }

  Future<void> verifyCode(String token, String code) async {
    _currentPasswordTrackId = null;
    _currentPasswordHint = null;
    _currentPasswordEmail = null;

    if (!_socketConnected || _socket == null) {
      await connect();
    }

    final payload = {
      "verifyCode": code,
      "token": token,
      "authTokenType": "CHECK_CODE",
    };
    await _sendMessage(18, payload);
  }

  Future<void> sendPassword(String trackId, String password) async {
    await waitUntilOnline();

    final payload = {'trackId': trackId, 'password': password};

    _sendMessage(115, payload);
    print(
      'Пароль отправлен с payload: ${truncatePayloadObjectForLog(payload)}',
    );
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
    print(
      'Запрос на установку пароля отправлен с payload: ${truncatePayloadObjectForLog(payload)}',
    );
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

    if (!FreshModeHelper.shouldSkipSave()) {
      final prefs = await FreshModeHelper.getSharedPreferences();
      await prefs.setString('authToken', token);
      if (userId != null) {
        await prefs.setString('userId', userId);
      }
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

    if (!_chatsFetchedInThisSession || _lastChatsPayload == null) {
      await getChatsAndContacts(force: true);
    }

    int attempts = 0;
    while ((!_chatsFetchedInThisSession || _lastChatsPayload == null) &&
        attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (_lastChatsPayload == null) {
      throw Exception('Не удалось загрузить данные после авторизации');
    }

    final profileJson = _lastChatsPayload?['profile'];
    if (profileJson != null) {
      final profileObj = Profile.fromJson(profileJson);
      await accountManager.updateAccountProfile(account.id, profileObj);
    }

    print("Токен и UserID успешно сохранены, сессия перезапущена");
  }

  Future<bool> hasToken() async {
    if (FreshModeHelper.isEnabled) return false;

    if (authToken == null) {
      final accountManager = AccountManager();
      await accountManager.initialize();
      await accountManager.migrateOldAccount();

      final currentAccount = accountManager.currentAccount;
      if (currentAccount != null) {
        authToken = currentAccount.token;
        userId = currentAccount.userId;
      } else {
        final prefs = await FreshModeHelper.getSharedPreferences();
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

    final accountManager = AccountManager();
    await accountManager.initialize();
    
    // Save the current account ID in case we need to rollback
    final previousAccountId = accountManager.currentAccount?.id;
    final previousToken = authToken;
    final previousUserId = userId;

    disconnect();

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

      // Listen for invalid_token messages during account switch
      bool invalidTokenDetected = false;
      StreamSubscription? tempSubscription;
      
      tempSubscription = messages.listen((message) {
        if (message['type'] == 'invalid_token') {
          invalidTokenDetected = true;
          tempSubscription?.cancel();
        }
      });

      try {
        await connect();

        await waitUntilOnline().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            if (invalidTokenDetected) {
              throw Exception('invalid_token: Аккаунт недействителен');
            }
            throw TimeoutException('Таймаут подключения');
          },
        );

        if (invalidTokenDetected) {
          throw Exception('invalid_token: Аккаунт недействителен');
        }

        await getChatsAndContacts(force: true);

        final profile = _lastChatsPayload?['profile'];
        if (profile != null) {
          final profileObj = Profile.fromJson(profile);
          await accountManager.updateAccountProfile(accountId, profileObj);
        }
      } catch (e) {
        // Clean up and restore previous account if switch failed
        tempSubscription?.cancel();
        
        print("Ошибка переключения аккаунта: $e");
        
        // Restore previous account
        if (previousAccountId != null) {
          print("Восстанавливаем предыдущий аккаунт: $previousAccountId");
          disconnect();
          await accountManager.switchAccount(previousAccountId);
          authToken = previousToken;
          userId = previousUserId;
          
          _messageQueue.clear();
          _lastChatsPayload = null;
          _chatsFetchedInThisSession = false;
          _isSessionOnline = false;
          _isSessionReady = false;
          _handshakeSent = false;
          
          // Try to reconnect to previous account
          try {
            await connect();
            await waitUntilOnline().timeout(const Duration(seconds: 10));
          } catch (reconnectError) {
            print("Ошибка восстановления предыдущего аккаунта: $reconnectError");
          }
        }
        
        rethrow;
      } finally {
        tempSubscription?.cancel();
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
      _analyticsTimer?.cancel();
      _socket?.close();
      _socket = null;
      _socketConnected = false;

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
      _analyticsTimer?.cancel();
      _socket?.close();
      _socket = null;
      _socketConnected = false;

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
    if (!_socketConnected || _socket == null) {
      await connect();
      await waitUntilOnline();
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
