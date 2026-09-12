// #***! разбор жирного ответа login для отладки сессии
class LoginInfo {
  const LoginInfo._();

  // #***! профиль конфиг и сводка по чатам плоским мапом
  static Map<String, dynamic> fromPayload(Map<dynamic, dynamic> payload) {
    final profile = _asMap(payload['profile']);
    final contact = _asMap(profile?['contact']);
    final chats = _asList(payload['chats']);
    final config = _asMap(payload['config']);
    final server = _asMap(config?['server']);
    final user = _asMap(config?['user']);
    final experiments = _asMap(config?['experiments']);
    final chatSettings = _asMap(config?['chats']);

    return {
      'registrationTime': contact?['registrationTime'],
      'country': contact?['country'],
      'videoChatHistory': payload['videoChatHistory'],
      'updateTime': contact?['updateTime'],
      'id': contact?['id'],
      'phone': contact?['phone'],
      'photoId': contact?['photoId'],
      'accountStatus': contact?['accountStatus'],
      'contactOptions': _copyJsonValue(contact?['options']),
      'profileOptions': _copyJsonValue(profile?['profileOptions']),
      'names': _copyJsonValue(contact?['names']),
      'baseUrl': contact?['baseUrl'],
      'baseRawUrl': contact?['baseRawUrl'],
      'chatMarker': payload['chatMarker'] ?? _latestChatEventTime(chats),
      'time': payload['time'],
      'updates': payload['updates'],
      'messagesCount': _collectionLength(payload['messages']),
      'contactsCount': _collectionLength(payload['contacts']),
      'presenceCount': _collectionLength(payload['presence']),
      'configHash': config?['hash'],
      'chats': _buildChatsSummary(chats),
      'server': _copyMap(server),
      'user': _copyMap(user),
      'experiments': _copyMap(experiments),
      'chatSettings': _copyMap(chatSettings),
    };
  }

  // #***! по чатам только сводка, список огромный
  static Map<String, dynamic> _buildChatsSummary(List<dynamic> chats) {
    var active = 0;
    var hidden = 0;
    var dialogs = 0;
    var groups = 0;
    var channels = 0;
    var unread = 0;
    var newMessages = 0;
    var messages = 0;

    for (final rawChat in chats) {
      final chat = _asMap(rawChat);
      if (chat == null) continue;
      switch (chat['status']) {
        case 'ACTIVE':
          active++;
        case 'HIDDEN':
          hidden++;
      }
      switch (chat['type']) {
        case 'DIALOG':
          dialogs++;
        case 'CHAT':
          groups++;
        case 'CHANNEL':
          channels++;
      }
      final chatNewMessages = _asInt(chat['newMessages']) ?? 0;
      if (chatNewMessages > 0) unread++;
      newMessages += chatNewMessages;
      messages += _asInt(chat['messagesCount']) ?? 0;
    }

    return {
      'count': chats.length,
      'active': active,
      'hidden': hidden,
      'dialogs': dialogs,
      'groups': groups,
      'channels': channels,
      'unread': unread,
      'newMessages': newMessages,
      'messages': messages,
    };
  }

  // #***! нет chatMarker берём максимум lastEventTime
  static int? _latestChatEventTime(List<dynamic> chats) {
    int? latest;
    for (final rawChat in chats) {
      final chat = _asMap(rawChat);
      final value = _asInt(chat?['lastEventTime']);
      if (value != null && (latest == null || value > latest)) {
        latest = value;
      }
    }
    return latest;
  }

  // #***! дальше приведения типов, сервер шлёт разное
  static Map<dynamic, dynamic>? _asMap(dynamic value) {
    return value is Map ? value : null;
  }

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : const [];
  }

  static int? _asInt(dynamic value) {
    return switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text),
      _ => null,
    };
  }

  static int _collectionLength(dynamic value) {
    return switch (value) {
      Map items => items.length,
      List items => items.length,
      _ => 0,
    };
  }

  // #***! копируем в чистый json для jsonEncode
  static Map<String, dynamic>? _copyMap(Map<dynamic, dynamic>? value) {
    if (value == null) return null;
    return value.map(
      (key, item) => MapEntry(key.toString(), _copyJsonValue(item)),
    );
  }

  static dynamic _copyJsonValue(dynamic value) {
    if (value is Map) return _copyMap(value);
    if (value is List) return value.map(_copyJsonValue).toList();
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    return value.toString();
  }
}
