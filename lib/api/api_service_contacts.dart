part of 'api_service.dart';

extension ApiServiceContacts on ApiService {
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

  Future<void> requestContactsByIds(List<int> contactIds) async {
    await waitUntilOnline();
    _sendMessage(35, {'contactIds': contactIds});
    print('Отправлен запрос opcode=35 с contactIds: $contactIds');
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

    final int seq = await _sendMessage(89, payload);
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

  void markMessageAsRead(int chatId, dynamic messageId) {
    waitUntilOnline().then((_) {
      final int messageIdInt = messageId is String
          ? int.tryParse(messageId) ?? 0
          : (messageId as int);
      final payload = {
        "type": "READ_MESSAGE",
        "chatId": chatId,
        "messageId": messageIdInt,
        "mark": DateTime.now().millisecondsSinceEpoch,
      };
      _sendMessage(50, payload);
      print(
        'Отправляем отметку о прочтении для сообщения $messageIdInt в чате $chatId',
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

    if (!_isSessionOnline || !_isSessionReady) {
      print(
        'ApiService: сессия еще не готова для запроса заблокированных контактов, ждем...',
      );
      await waitUntilOnline();

      if (!_isSessionReady) {
        print(
          'ApiService: сессия все еще не готова после ожидания, отменяем запрос',
        );
        return;
      }
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

  Future<int> sendReaction(int chatId, String messageId, String emoji) async {
    final messageIdInt = int.tryParse(messageId) ?? 0;
    final payload = {
      "chatId": chatId,
      "messageId": messageIdInt,
      "reaction": {"reactionType": "EMOJI", "id": emoji},
    };
    final seq = await _sendMessage(178, payload);
    print('Отправляем реакцию: $emoji на сообщение $messageId в чате $chatId');
    return seq;
  }

  Future<int> removeReaction(int chatId, String messageId) async {
    final messageIdInt = int.tryParse(messageId) ?? 0;
    final payload = {"chatId": chatId, "messageId": messageIdInt};
    final seq = await _sendMessage(179, payload);
    print('Удаляем реакцию с сообщения $messageId в чате $chatId');
    return seq;
  }

  Future<Map<String, dynamic>> joinGroupByLink(String link) async {
    await waitUntilOnline();

    final payload = {'link': link};

    final int seq = await _sendMessage(57, payload);
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
        print(
          'Успешно присоединились: ${truncatePayloadObjectForLog(response['payload'])}',
        );
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
    print(
      'Запрос на поиск контакта отправлен с payload: ${truncatePayloadObjectForLog(payload)}',
    );
  }

  Future<void> searchChannels(String query) async {
    await waitUntilOnline();

    final payload = {'contactIds': []};

    _sendMessage(32, payload);
    print(
      'Запрос на поиск каналов отправлен с payload: ${truncatePayloadObjectForLog(payload)}',
    );
  }

  Future<void> enterChannel(String link) async {
    await waitUntilOnline();

    final payload = {'link': link};

    _sendMessage(89, payload);
    print(
      'Запрос на вход в канал отправлен с payload: ${truncatePayloadObjectForLog(payload)}',
    );
  }

  Future<void> subscribeToChannel(String link) async {
    await waitUntilOnline();

    final payload = {'link': link};

    _sendMessage(57, payload);
    print(
      'Запрос на подписку на канал отправлен с payload: ${truncatePayloadObjectForLog(payload)}',
    );
  }

  Future<int?> getChatIdByUserId(int userId) async {
    if (_userId == null) {
      return null;
    }

    final chatId = _userId! ^ userId;
    return chatId;
  }

  Future<List<Contact>> fetchContactsByIds(List<int> contactIds) async {
    if (contactIds.isEmpty) {
      return [];
    }

    try {
      final int contactSeq = await _sendMessage(32, {"contactIds": contactIds});

      final contactResponse = await messages
          .firstWhere((msg) => msg['seq'] == contactSeq)
          .timeout(const Duration(seconds: 10));

      if (contactResponse['cmd'] == 3) {
        return [];
      }

      final List<dynamic> contactListJson =
          contactResponse['payload']?['contacts'] ?? [];
      final contacts = contactListJson
          .map((json) => Contact.fromJson(json))
          .toList();

      if (contacts.length < contactIds.length) {
        final receivedIds = contacts.map((c) => c.id).toSet();
        final missingIds = contactIds
            .where((id) => !receivedIds.contains(id))
            .toList();
      }

      for (final contact in contacts) {
        _contactCache[contact.id] = contact;
      }
      return contacts;
    } catch (e) {
      return [];
    }
  }
}
