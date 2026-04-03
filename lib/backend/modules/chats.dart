import '../../core/storage/app_database.dart';

class CachedChat {
  final int id;
  final int accountId;
  final String type;
  final String? title;
  final String? iconUrl;
  final int? lastMsgId;
  final int? lastMsgTime;
  final String? lastMsgText;
  final int? lastMsgSenderId;
  final int unreadCount;
  final int lastEventTime;
  final int cachedAt;
  final int? favIndex;
  final int dontDisturbUntil;
  final bool isOnline;
  final int seenTime;

  const CachedChat({
    required this.id,
    required this.accountId,
    required this.type,
    this.title,
    this.iconUrl,
    this.lastMsgId,
    this.lastMsgTime,
    this.lastMsgText,
    this.lastMsgSenderId,
    required this.unreadCount,
    required this.lastEventTime,
    required this.cachedAt,
    this.favIndex,
    required this.dontDisturbUntil,
    required this.isOnline,
    required this.seenTime,
  });

  factory CachedChat.fromDbRow(Map<String, dynamic> row) => CachedChat(
    id: row['id'] as int,
    accountId: row['account_id'] as int,
    type: row['type'] as String,
    title: row['title'] as String?,
    iconUrl: row['icon_url'] as String?,
    lastMsgId: row['last_msg_id'] as int?,
    lastMsgTime: row['last_msg_time'] as int?,
    lastMsgText: row['last_msg_text'] as String?,
    lastMsgSenderId: row['last_msg_sender'] as int?,
    unreadCount: row['unread_count'] as int,
    lastEventTime: row['last_event_time'] as int,
    cachedAt: row['cached_at'] as int,
    favIndex: row['fav_index'] as int?,
    dontDisturbUntil: row['dont_disturb_until'] as int,
    isOnline: (row['is_online'] as int) == 1,
    seenTime: row['seen_time'] as int,
  );

  Map<String, dynamic> toDbRow() => {
    'id': id,
    'account_id': accountId,
    'type': type,
    'title': title,
    'icon_url': iconUrl,
    'last_msg_id': lastMsgId,
    'last_msg_time': lastMsgTime,
    'last_msg_text': lastMsgText,
    'last_msg_sender': lastMsgSenderId,
    'unread_count': unreadCount,
    'last_event_time': lastEventTime,
    'cached_at': cachedAt,
    'fav_index': favIndex,
    'dont_disturb_until': dontDisturbUntil,
    'is_online': isOnline ? 1 : 0,
    'seen_time': seenTime,
  };
}

class ChatsModule {
  /// Парсит и кэширует чаты из payload opcode 19.
  ///
  /// Для диалогов разрезолвит имя и аватар из списка [contacts] того же
  /// ответа. На warm start контакты не приходят — используется существующий
  /// кэш.
  static Future<void> syncFromLoginPayload(
    Map<dynamic, dynamic> data,
    int accountId,
    int currentUserId,
  ) async {
    final chats = data['chats'];
    if (chats is! List || chats.isEmpty) return;

    final contactsMap = _buildContactsMap(data['contacts']);
    // Config contains mute setup and fav indexes: config -> chats -> id
    final configMap = data['config'] is Map ? data['config'] as Map : {};
    final chatsConfig = configMap['chats'] is Map
        ? configMap['chats'] as Map
        : {};
    // Presence for online statuses
    final presenceMap = data['presence'] is Map ? data['presence'] as Map : {};
    final cachedAt = DateTime.now().millisecondsSinceEpoch;

    final existingRows = await AppDatabase.loadChats(accountId);
    final existing = {
      for (final row in existingRows)
        row['id'] as int: CachedChat.fromDbRow(row),
    };

    final rows = chats
        .whereType<Map>()
        .map(
          (c) => _parseChat(
            c.cast<dynamic, dynamic>(),
            accountId,
            currentUserId,
            contactsMap,
            chatsConfig,
            presenceMap,
            existing,
            cachedAt,
          ),
        )
        .whereType<CachedChat>()
        .map((c) => c.toDbRow())
        .toList();

    if (rows.isNotEmpty) {
      await AppDatabase.saveChats(rows);
    }
  }

  static Future<List<CachedChat>> getChats(int accountId) async {
    final rows = await AppDatabase.loadChats(accountId);
    return rows.map(CachedChat.fromDbRow).toList();
  }

  static Future<void> clearCache(int accountId) =>
      AppDatabase.clearChatsCache(accountId);

  // internal

  static Map<int, Map<dynamic, dynamic>> _buildContactsMap(dynamic contacts) {
    if (contacts is! List) return {};
    final result = <int, Map<dynamic, dynamic>>{};
    for (final c in contacts.whereType<Map>()) {
      final id = c['id'];
      if (id is int) result[id] = c.cast();
    }
    return result;
  }

  static CachedChat? _parseChat(
    Map<dynamic, dynamic> chat,
    int accountId,
    int currentUserId,
    Map<int, Map<dynamic, dynamic>> contactsMap,
    Map<dynamic, dynamic> chatsConfig,
    Map<dynamic, dynamic> presenceMap,
    Map<int, CachedChat> existing,
    int cachedAt,
  ) {
    final id = chat['id'];
    if (id is! int) return null;

    final type = (chat['type'] as String?) ?? 'DIALOG';
    int? otherId;

    String? title;
    String? iconUrl;

    if (type == 'DIALOG') {
      otherId = _otherParticipantId(chat['participants'], currentUserId);
      final contact = otherId != null ? contactsMap[otherId] : null;

      if (contact != null) {
        title = _nameFromContact(contact);
        iconUrl = contact['baseUrl'] as String?;
      } else {
        title = existing[id]?.title;
        iconUrl = existing[id]?.iconUrl;
      }
    } else {
      title = chat['title'] as String?;
      iconUrl = chat['baseIconUrl'] as String?;
    }

    final lastMsg = chat['lastMessage'];
    int? lastMsgId;
    int? lastMsgTime;
    String? lastMsgText;
    int? lastMsgSenderId;

    if (lastMsg is Map) {
      lastMsgId = lastMsg['id'] as int?;
      lastMsgTime = lastMsg['time'] as int?;
      lastMsgText = lastMsg['text'] as String?;
      lastMsgSenderId = lastMsg['sender'] as int?;
    }

    final config = chatsConfig[id.toString()] ?? chatsConfig[id];
    int? favIndex;
    int dontDisturbUntil = 0;
    if (config is Map) {
      favIndex = config['favIndex'] as int?;
      dontDisturbUntil = (config['dontDisturbUntil'] as int?) ?? 0;
    }

    int seenTime = 0;
    bool isOnline = false;
    if (type == 'DIALOG' && otherId != null) {
      final presence = presenceMap[otherId.toString()] ?? presenceMap[otherId];
      if (presence is Map) {
        seenTime = (presence['seen'] as int?) ?? 0;
        isOnline = (presence['status'] as int?) == 1;
      }
    }

    return CachedChat(
      id: id,
      accountId: accountId,
      type: type,
      title: title,
      iconUrl: iconUrl,
      lastMsgId: lastMsgId,
      lastMsgTime: lastMsgTime,
      lastMsgText: lastMsgText,
      lastMsgSenderId: lastMsgSenderId,
      unreadCount: (chat['newMessages'] as int?) ?? 0,
      lastEventTime: (chat['lastEventTime'] as int?) ?? 0,
      cachedAt: cachedAt,
      favIndex: favIndex,
      dontDisturbUntil: dontDisturbUntil,
      isOnline: isOnline,
      seenTime: seenTime,
    );
  }

  static int? _otherParticipantId(dynamic participants, int currentUserId) {
    if (participants is! Map) return null;
    for (final key in participants.keys) {
      final id = key is int ? key : int.tryParse(key.toString());
      if (id != null && id != currentUserId) return id;
    }
    return null;
  }

  static String? _nameFromContact(Map<dynamic, dynamic> contact) {
    final names = contact['names'];
    if (names is! List || names.isEmpty) return null;
    final name =
        names.firstWhere(
              (n) => n is Map && n['type'] == 'ONEME',
              orElse: () => names.first,
            )
            as Map;
    return name['name'] as String?;
  }
}
