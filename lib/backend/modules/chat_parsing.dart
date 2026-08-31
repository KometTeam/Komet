import '../../core/utils/logger.dart';
import 'chat_preview.dart';
import 'chats.dart';

// #***! контакты списком а нужны по id, раскладываем один раз
Map<int, Map<dynamic, dynamic>> buildContactsMap(dynamic contacts) {
  if (contacts is! List) return {};
  final result = <int, Map<dynamic, dynamic>>{};
  for (final c in contacts.whereType<Map>()) {
    final id = c['id'];
    if (id is int) result[id] = c.cast();
  }
  return result;
}

// #***! главный разбор, сырой чат в строку кэша
CachedChat? parseChatRow(
  Map<dynamic, dynamic> chat,
  int accountId,
  int currentUserId,
  Map<int, Map<dynamic, dynamic>> contactsMap,
  Map<dynamic, dynamic> chatsConfig,
  Map<dynamic, dynamic> presenceMap,
  Map<int, CachedChat> existing,
  int cachedAt,
) {
  // #***! битый чат не должен ронять весь список
  try {
    final id = chat['id'];
    if (id is! int) return null;

    final type = (chat['type'] as String?) ?? 'DIALOG';
    // #***! в диалоге имя и аватарка от собеседника
    final otherId = type == 'DIALOG'
        ? _otherParticipantId(chat['participants'], currentUserId)
        : null;

    final titleIcon = _resolveTitleAndIcon(
      chat,
      id,
      type,
      otherId,
      contactsMap,
      existing,
    );
    final lastMessage = _resolveLastMessage(chat['lastMessage']);
    final previous = existing[id];
    // #***! сообщение то же, держим свой статус доставки сервер его не шлёт
    final sameLastMessage =
        previous != null &&
        lastMessage.id != null &&
        previous.lastMsgId == lastMessage.id;
    final muteFav = _resolveMuteAndFavorite(chatsConfig, id, existing);
    final presence = _resolvePresence(type, otherId, presenceMap);
    final adminsOwner = _resolveAdmins(chat);
    final pinned = _resolvePinnedMessage(chat['pinnedMessage']);
    final mentionId = int.tryParse(
      chat['lastMentionMessageId']?.toString() ?? '',
    );

    return CachedChat(
      id: id,
      accountId: accountId,
      type: type,
      title: titleIcon.title,
      iconUrl: titleIcon.iconUrl,
      lastMsgId: lastMessage.id,
      lastMsgTime: lastMessage.time,
      lastMsgText: lastMessage.text,
      lastMsgElements: lastMessage.elements,
      lastMsgPreview: lastMessage.preview,
      lastMsgSenderId:
          lastMessage.senderId ??
          (sameLastMessage ? previous.lastMsgSenderId : null),
      lastMsgStatus: sameLastMessage ? previous.lastMsgStatus : null,
      unreadCount: (chat['newMessages'] as int?) ?? 0,
      lastEventTime: (chat['lastEventTime'] as int?) ?? 0,
      cachedAt: cachedAt,
      favIndex: muteFav.favIndex,
      dontDisturbUntil: muteFav.dontDisturbUntil,
      isOnline: presence.isOnline,
      seenTime: presence.seenTime,
      participants: parseParticipants(chat['participants']),
      options: titleIcon.options,
      owner: adminsOwner.owner,
      admins: adminsOwner.admins,
      pinnedMsgId: pinned.id,
      pinnedMsgText: pinned.text,
      pinnedMsgTime: pinned.time,
      pinnedMsgIsPreview: pinned.isPreview,
      lastMentionMsgId: mentionId ?? existing[id]?.lastMentionMsgId,
    );
  // #***! логируем и null, чат просто не попадёт в список
  } catch (e) {
    logger.e("Ошибка при парсинге чата: $e");
    return null;
  }
}

// #***! имя и иконка, у диалога от контакта у группы от чата
({String? title, String? iconUrl, Set<String> options}) _resolveTitleAndIcon(
  Map<dynamic, dynamic> chat,
  int id,
  String type,
  int? otherId,
  Map<int, Map<dynamic, dynamic>> contactsMap,
  Map<int, CachedChat> existing,
) {
  if (type == 'DIALOG') {
    final contact = otherId != null ? contactsMap[otherId] : null;
    if (contact != null) {
      Set<String> options = const {};
      final contactOpts = contact['options'];
      if (contactOpts is List) {
        options = contactOpts.whereType<String>().toSet();
      }
      return (
        title: _nameFromContact(contact),
        iconUrl: contact['baseUrl'] as String?,
        options: options,
      );
    }
    // #***! контакт не подъехал, держим старое чтоб строка не мигала
    return (
      title: existing[id]?.title,
      iconUrl: existing[id]?.iconUrl,
      options: existing[id]?.options ?? const {},
    );
  }
  Set<String> options = const {};
  final chatOpts = chat['options'];
  if (chatOpts is Map) {
    options = {
      for (final entry in chatOpts.entries)
        if (entry.value == true && entry.key is String) entry.key as String,
    };
  }
  return (
    title: chat['title'] as String?,
    iconUrl: chat['baseIconUrl'] as String?,
    options: options,
  );
}

// #***! последнее сообщение в плоские поля
({
  int? id,
  int? time,
  String? text,
  String? elements,
  String? preview,
  int? senderId,
})
_resolveLastMessage(dynamic lastMsg) {
  if (lastMsg is! Map) {
    return (
      id: null,
      time: null,
      text: null,
      elements: null,
      preview: null,
      senderId: null,
    );
  }
  return (
    id: _asIntOrNull(lastMsg['id']),
    time: _asIntOrNull(lastMsg['time']),
    text: messagePreviewText(lastMsg),
    elements: messagePreviewElements(lastMsg),
    preview: messagePreviewMedia(lastMsg),
    senderId: _asIntOrNull(lastMsg['sender']),
  );
}

// #***! числа то int то строка
int? _asIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

// #***! закреплённое, id текст и сгенерили ли мы его сами
({int? id, String? text, int? time, bool isPreview}) _resolvePinnedMessage(
  dynamic pinned,
) {
  if (pinned is! Map) {
    return (id: null, text: null, time: null, isPreview: false);
  }
  final rawId = pinned['id'];
  final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
  if (id == null) return (id: null, text: null, time: null, isPreview: false);
  final preview = pinnedMessagePreview(pinned);
  return (
    id: id,
    text: preview.text,
    time: pinned['time'] as int?,
    isPreview: preview.isPreview,
  );
}

// #***! мьют и избранное лежат в конфиге а не в чате
({int? favIndex, int dontDisturbUntil}) _resolveMuteAndFavorite(
  Map<dynamic, dynamic> chatsConfig,
  int id,
  Map<int, CachedChat> existing,
) {
  final config = chatsConfig[id.toString()] ?? chatsConfig[id];
  final ex = existing[id];
  if (config is Map) {
    final configFav = config['favIndex'] as int?;
    return (
      // #***! favIndex ноль значит не задан, держим своё
      favIndex: (configFav != null && configFav > 0) ? configFav : ex?.favIndex,
      dontDisturbUntil: (config['dontDisturbUntil'] as int?) ?? 0,
    );
  }
  if (ex != null) {
    return (favIndex: ex.favIndex, dontDisturbUntil: ex.dontDisturbUntil);
  }
  return (favIndex: null, dontDisturbUntil: 0);
}

// #***! онлайн только у диалогов
({int seenTime, bool isOnline}) _resolvePresence(
  String type,
  int? otherId,
  Map<dynamic, dynamic> presenceMap,
) {
  if (type != 'DIALOG' || otherId == null) {
    return (seenTime: 0, isOnline: false);
  }
  final presence = presenceMap[otherId.toString()] ?? presenceMap[otherId];
  if (presence is Map) {
    return (
      seenTime: (presence['seen'] as int?) ?? 0,
      isOnline: (presence['status'] as int?) == 1,
    );
  }
  return (seenTime: 0, isOnline: false);
}

// #***! владелец и админы то списком то картой
({int? owner, Set<int> admins}) _resolveAdmins(Map<dynamic, dynamic> chat) {
  int? owner;
  final ownerRaw = chat['owner'];
  if (ownerRaw is int) {
    owner = ownerRaw;
  } else if (ownerRaw is String) {
    owner = int.tryParse(ownerRaw);
  }

  Set<int> admins = const {};
  final adminsRaw = chat['admins'];
  if (adminsRaw is List) {
    admins = adminsRaw
        .map((e) => e is int ? e : int.tryParse(e.toString()))
        .whereType<int>()
        .toSet();
  } else {
    final adminParticipants = chat['adminParticipants'];
    if (adminParticipants is Map) {
      admins = adminParticipants.keys
          .map((k) => k is int ? k : int.tryParse(k.toString()))
          .whereType<int>()
          .toSet();
    }
  }
  return (owner: owner, admins: admins);
}

// #***! в диалоге собеседник это тот кто не мы
int? _otherParticipantId(dynamic participants, int currentUserId) {
  if (participants is! Map) return null;
  for (final key in participants.keys) {
    final id = key is int ? key : int.tryParse(key.toString());
    if (id != null && id != currentUserId) return id;
  }
  return null;
}

// #***! имя ONEME главнее, человек сам себя так назвал
String? _nameFromContact(Map<dynamic, dynamic> contact) {
  final names = contact['names'];
  if (names is! List || names.isEmpty) return null;
  final nameRaw = names.firstWhere(
    (n) => n is Map && n['type'] == 'ONEME',
    orElse: () => names.firstWhere((n) => n is Map, orElse: () => null),
  );
  if (nameRaw is! Map) return null;
  final name = nameRaw;
  return name['name'] as String?;
}

// #***! разбор поиска по чатам
List<ChatSearchHit> parseSearchResult(dynamic payload) {
  final result = (payload as Map?)?['result'];
  if (result is! List) return const [];
  final hits = <ChatSearchHit>[];
  for (final item in result) {
    if (item is! Map) continue;
    final chat = item['chat'];
    if (chat is! Map) continue;
    final id = chat['id'];
    if (id is! int) continue;
    final last = chat['lastMessage'];
    final link = chat['link'];
    hits.add(
      ChatSearchHit(
        id: id,
        type: (chat['type'] as String?) ?? 'CHAT',
        title: chat['title'] as String?,
        avatarUrl: chat['baseIconUrl'] as String?,
        subtitle: link is String && link.isNotEmpty
            ? '@$link'
            : (last is Map ? last['text'] as String? : null),
      ),
    );
  }
  return hits;
}

// #***! разбор поиска по сообщениям
List<MessageSearchHit> parseMessageResult(dynamic payload) {
  final result = (payload as Map?)?['result'];
  if (result is! List) return const [];
  final hits = <MessageSearchHit>[];
  for (final item in result) {
    if (item is! Map) continue;
    final message = item['message'];
    if (message is! Map) continue;
    final chatId = item['chatId'];
    if (chatId is! int || chatId == 0) continue;
    hits.add(
      MessageSearchHit(
        chatId: chatId,
        messageId: message['id']?.toString(),
        text: message['text'] as String?,
        time: (message['time'] as int?) ?? 0,
        senderId: (message['sender'] as int?) ?? 0,
      ),
    );
  }
  return hits;
}

// #***! ничего не изменилось значит базу не трогаем и список не перерисовываем
bool sameChatContent(CachedChat a, CachedChat b) {
  if (a.title != b.title) return false;
  if (a.iconUrl != b.iconUrl) return false;
  if (a.owner != b.owner) return false;
  if (a.pinnedMsgId != b.pinnedMsgId) return false;
  if (a.pinnedMsgText != b.pinnedMsgText) return false;
  if (a.pinnedMsgTime != b.pinnedMsgTime) return false;
  if (a.pinnedMsgIsPreview != b.pinnedMsgIsPreview) return false;
  if (a.dontDisturbUntil != b.dontDisturbUntil) return false;
  if (a.favIndex != b.favIndex) return false;
  if (a.lastMsgId != b.lastMsgId) return false;
  if (a.lastMsgTime != b.lastMsgTime) return false;
  if (a.lastMsgText != b.lastMsgText) return false;
  if (a.lastMsgElements != b.lastMsgElements) return false;
  if (a.lastMsgPreview != b.lastMsgPreview) return false;
  if (a.lastMsgSenderId != b.lastMsgSenderId) return false;
  if (a.unreadCount != b.unreadCount) return false;
  if (a.lastEventTime != b.lastEventTime) return false;
  if (a.isOnline != b.isOnline) return false;
  if (a.seenTime != b.seenTime) return false;
  if (a.admins.length != b.admins.length) return false;
  if (!a.admins.containsAll(b.admins)) return false;
  if (a.options.length != b.options.length) return false;
  if (!a.options.containsAll(b.options)) return false;
  if (a.participants.length != b.participants.length) return false;
  for (final e in a.participants.entries) {
    if (b.participants[e.key] != e.value) return false;
  }
  return true;
}

// #***! 0 это превью без членства, 1 обычный чат, 2 скрытый
abstract final class ChatListState {
  static const int notInList = 0;
  static const int visible = 1;
  static const int hidden = 2;
}

// #***! живым считаем только ACTIVE, закрытые и покинутые сервер удалять не даёт
int chatListStateForStatus(Object? status, {int? previous}) {
  if (status is String && status.isNotEmpty) {
    return status == 'ACTIVE' ? ChatListState.visible : ChatListState.hidden;
  }
  return previous == ChatListState.hidden
      ? ChatListState.hidden
      : ChatListState.visible;
}
