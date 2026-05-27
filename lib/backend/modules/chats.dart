import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import '../api.dart';
import 'folders.dart';
import 'messages.dart' show ContactCache;

Map<int, int> _parseParticipants(dynamic raw) {
  try {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(
        k is int ? k : int.parse(k.toString()),
        v is int ? v : int.tryParse(v.toString()) ?? 0,
      ));
    }
  } catch (e) {
    logger.e('Failed to parse participants: $e');
  }
  return {};
}

class CachedChat {
  final int id;
  final int accountId;
  final String type;
  final String? title;
  final String? iconUrl;
  final int? lastMsgId;
  final int? lastMsgTime;
  final String? lastMsgText;
  final String? lastMsgTextOneLine;
  final int? lastMsgSenderId;
  final int unreadCount;
  final int lastEventTime;
  final int cachedAt;
  final int? favIndex;
  final int dontDisturbUntil;
  final bool isOnline;
  final int seenTime;
  final Map<int, int> participants;
  final Set<String> options;
  final int? owner;
  final Set<int> admins;

  CachedChat({
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
    required this.participants,
    this.options = const {},
    this.owner,
    this.admins = const {},
  }) : lastMsgTextOneLine = lastMsgText != null && lastMsgText.contains('\n')
            ? lastMsgText.replaceAll('\n', ' ')
            : lastMsgText;

  bool get isOfficial => options.contains('OFFICIAL');

  bool iAmAdmin(int myId) => owner == myId || admins.contains(myId);

  bool get isMuted {
    if (dontDisturbUntil == ChatsModule.muteOff) return false;
    if (dontDisturbUntil < 0) return true;
    return dontDisturbUntil > DateTime.now().millisecondsSinceEpoch;
  }

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
    participants: _parseParticipants(row['participants']),
    options: _decodeOptions(row['options']),
    owner: row['owner'] as int?,
    admins: _decodeAdmins(row['admins']),
  );

  static Set<String> _decodeOptions(dynamic raw) {
    if (raw is! String || raw.isEmpty) return const {};
    return raw.split(',').where((s) => s.isNotEmpty).toSet();
  }

  static Set<int> _decodeAdmins(dynamic raw) {
    if (raw is! String || raw.isEmpty) return const {};
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
  }

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
    'participants': jsonEncode(participants.map((k, v) => MapEntry(k.toString(), v))),
    'options': options.isEmpty ? null : options.join(','),
    'owner': owner,
    'admins': admins.isEmpty ? null : admins.join(','),
  };
}

class ChatsModule {
  static const int muteOff = 0;
  static const int muteForever = -1;

  static final ValueNotifier<int> chatsChanged = ValueNotifier(0);
  static void _bump() => chatsChanged.value = chatsChanged.value + 1;

  static StreamSubscription<Packet>? _globalPushSub;

  static void attachGlobalPushHandlers(Api api) {
    _globalPushSub?.cancel();
    _globalPushSub = api.pushStream.listen(_handleGlobalPush);
  }

  static Future<void> _handleGlobalPush(Packet packet) async {
    switch (packet.opcode) {
      case Opcode.notifMark:
        await _handleNotifMark(packet);
    }
  }

  static Future<void> _handleNotifMark(Packet packet) async {
    final payload = packet.payload;
    if (payload is! Map) return;
    final chatId = payload['chatId'];
    if (chatId is! int) return;
    final userId = payload['userId'];
    if (userId is! int) return;
    final mark = payload['mark'];
    if (mark is! int) return;
    if (payload['setAsUnread'] == true) return;

    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;

    final rows = await AppDatabase.loadChat(accountId, chatId);
    if (rows.isEmpty) return;
    final cached = CachedChat.fromDbRow(rows.first);
    if (cached.participants[userId] == mark) return;
    cached.participants[userId] = mark;
    await AppDatabase.saveChats([cached.toDbRow()]);
  }

  static final Set<int> _pendingContactUpdates = {};
  static Timer? _contactFlushTimer;
  static Future<void>? _contactFlushFuture;
  static const _contactFlushDelay = Duration(milliseconds: 250);

  static void applyContactUpdate(int contactId) {
    _pendingContactUpdates.add(contactId);
    if (_contactFlushTimer != null) return;
    if (_contactFlushFuture != null) return;
    _contactFlushTimer = Timer(_contactFlushDelay, _kickFlush);
  }

  static void _kickFlush() {
    _contactFlushTimer = null;
    if (_contactFlushFuture != null) return;
    _contactFlushFuture = _flushContactUpdates().whenComplete(() {
      _contactFlushFuture = null;
      if (_pendingContactUpdates.isNotEmpty) {
        _contactFlushTimer ??= Timer(_contactFlushDelay, _kickFlush);
      }
    });
  }

  static Future<void> _flushContactUpdates() async {
    if (_pendingContactUpdates.isEmpty) return;
    final ids = _pendingContactUpdates.toList();
    _pendingContactUpdates.clear();

    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;

    final dialogRows = await AppDatabase.loadDialogChats(accountId);
    final byParticipant = <int, List<Map<String, dynamic>>>{};
    for (final row in dialogRows) {
      final cached = CachedChat.fromDbRow(row);
      for (final pid in cached.participants.keys) {
        if (pid == accountId) continue;
        byParticipant.putIfAbsent(pid, () => []).add(row);
      }
    }

    final updates = <Map<String, dynamic>>[];
    for (final contactId in ids) {
      final name = ContactCache.get(contactId);
      if (name == null) continue;
      final avatar = ContactCache.getAvatar(contactId);
      final options = ContactCache.getOptions(contactId) ?? const <String>{};
      final affected = byParticipant[contactId];
      if (affected == null) continue;
      for (final row in affected) {
        final cached = CachedChat.fromDbRow(row);
        final sameTitle = cached.title == name;
        final sameAvatar = (cached.iconUrl ?? '') == (avatar ?? '');
        final sameOptions = cached.options.length == options.length &&
            cached.options.containsAll(options);
        if (sameTitle && sameAvatar && sameOptions) continue;
        final newRow = Map<String, dynamic>.from(row);
        newRow['title'] = name;
        newRow['icon_url'] = avatar;
        newRow['options'] = options.isEmpty ? null : options.join(',');
        updates.add(newRow);
      }
    }
    if (updates.isNotEmpty) {
      await AppDatabase.saveChats(updates);
      _bump();
    }
  }

  static Future<CachedChat?> cacheServerChat(
    Map<dynamic, dynamic> chat,
    int accountId, {
    Map<int, CachedChat>? preloadedExisting,
  }) async {
    final cachedAt = DateTime.now().millisecondsSinceEpoch;
    final id = chat['id'];
    Map<int, CachedChat> existing = const {};
    if (preloadedExisting != null) {
      existing = preloadedExisting;
    } else if (id is int) {
      final rows = await AppDatabase.loadChat(accountId, id);
      if (rows.isNotEmpty) {
        existing = {id: CachedChat.fromDbRow(rows.first)};
      }
    }
    final parsed = _parseChat(
      chat,
      accountId,
      accountId,
      const {},
      const {},
      const {},
      existing,
      cachedAt,
    );
    if (parsed == null) {
      logger.w('cacheServerChat: parse returned null for chat=${chat['id']}');
      return null;
    }
    final ex = existing[parsed.id];
    if (ex != null && _sameContent(ex, parsed)) {
      return parsed;
    }
    await AppDatabase.saveChats([parsed.toDbRow()]);
    _bump();
    return parsed;
  }

  static bool _sameContent(CachedChat a, CachedChat b) {
    if (a.title != b.title) return false;
    if (a.iconUrl != b.iconUrl) return false;
    if (a.owner != b.owner) return false;
    if (a.dontDisturbUntil != b.dontDisturbUntil) return false;
    if (a.favIndex != b.favIndex) return false;
    if (a.lastMsgId != b.lastMsgId) return false;
    if (a.lastMsgTime != b.lastMsgTime) return false;
    if (a.lastMsgText != b.lastMsgText) return false;
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
    try {
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
        _bump();
      }
    } catch (e) {
      logger.e("Ошибка при синке: $e");
    }
  }

  static Future<List<CachedChat>> getChats(int accountId) async {
    try {
      final rows = await AppDatabase.loadChats(accountId);
      return rows.map(CachedChat.fromDbRow).toList();
    } catch (e) {
      logger.e("Ошибка при получении чатов: $e");
      return [];
    }
  }
  static Future<List<CachedChat>> getChat(int accountId, int chatId) async {
    try {
      final rows = await AppDatabase.loadChat(accountId, chatId);
      
      return rows.map(CachedChat.fromDbRow).toList();
    } catch (e) {
      logger.e("Ошибка при получении чата: $e");

      return [];
    }
  }

  static Future<void> clearCache(int accountId) =>
      AppDatabase.clearChatsCache(accountId);

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
    try {
        final id = chat['id'];
        if (id is! int) return null;

        final type = (chat['type'] as String?) ?? 'DIALOG';
        int? otherId;

        String? title;
        String? iconUrl;
        Set<String> options = const {};

        if (type == 'DIALOG') {
          otherId = _otherParticipantId(chat['participants'], currentUserId);
          final contact = otherId != null ? contactsMap[otherId] : null;

          if (contact != null) {
            title = _nameFromContact(contact);
            iconUrl = contact['baseUrl'] as String?;
            final contactOpts = contact['options'];
            if (contactOpts is List) {
              options = contactOpts.whereType<String>().toSet();
            }
          } else {
            title = existing[id]?.title;
            iconUrl = existing[id]?.iconUrl;
            options = existing[id]?.options ?? const {};
          }
        } else {
          title = chat['title'] as String?;
          iconUrl = chat['baseIconUrl'] as String?;
          final chatOpts = chat['options'];
          if (chatOpts is Map) {
            options = {
              for (final entry in chatOpts.entries)
                if (entry.value == true && entry.key is String) entry.key as String,
            };
          }
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
        } else {
          final ex = existing[id];
          if (ex != null) {
            favIndex = ex.favIndex;
            dontDisturbUntil = ex.dontDisturbUntil;
          }
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
        Map<int, int> participants = _parseParticipants(chat['participants']);

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
          participants: participants,
          options: options,
          owner: owner,
          admins: admins,
        );
    } catch (e) {
      logger.e("Ошибка при парсинге чата: $e");

      return null;
    }
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
    final nameRaw = names.firstWhere(
      (n) => n is Map && n['type'] == 'ONEME',
      orElse: () => names.firstWhere((n) => n is Map, orElse: () => null),
    );
    if (nameRaw is! Map) return null;
    final name = nameRaw;
    return name['name'] as String?;
  }

  static Future<Map<String, dynamic>?> getChatInfo(Api api, int chatId) async {
    final packet = await api.sendRequest(Opcode.chatInfo, {
      'chatIds': [chatId],
    });
    if (packet.isError) return null;
    final payload = packet.payload as Map?;
    final chats = payload?['chats'] as List?;
    if (chats == null || chats.isEmpty) return null;
    return Map<String, dynamic>.from(chats.first as Map);
  }

  static Future<dynamic> searchById(Api api, int userId) async {
    final packet = await api.sendRequest(Opcode.publicSearch, {
      'query': userId.toString(),
      'from': 0,
      'count': 10,
    });
    return packet.payload;
  }

  static Future<CachedChat?> createGroupChat(
    Api api, {
    required String title,
    required List<int> userIds,
    bool notify = true,
  }) async {
    final payload = {
      'message': {
        'cid': DateTime.now().millisecondsSinceEpoch,
        'attaches': [
          {
            '_type': 'CONTROL',
            'event': 'new',
            'chatType': 'CHAT',
            'title': title,
            'userIds': userIds,
          },
        ],
      },
      'notify': notify,
    };
    final packet = await api.sendRequest(Opcode.msgSend, payload);
    if (!packet.isOk) {
      logger.w('createGroupChat: server error payload=${packet.payload}');
      return null;
    }
    final data = packet.payload;
    if (data is! Map) {
      logger.w('createGroupChat: payload is not a Map: $data');
      return null;
    }
    final chat = data['chat'];
    if (chat is! Map) {
      logger.w('createGroupChat: response has no chat field: $data');
      return null;
    }
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) {
      logger.w('createGroupChat: no active account id');
      return null;
    }
    return cacheServerChat(chat, accountId);
  }

  static Future<String?> requestChatPhotoUploadUrl(Api api) async {
    final packet = await api.sendRequest(Opcode.photoUpload, {'count': 1});
    if (!packet.isOk) return null;
    final data = packet.payload;
    if (data is! Map) return null;
    return data['url'] as String?;
  }

  static Future<bool> setChatPhoto(
    Api api, {
    required int chatId,
    required String photoToken,
  }) async {
    final packet = await api.sendRequest(Opcode.chatUpdate, {
      'chatId': chatId,
      'photoToken': photoToken,
    });
    return packet.isOk;
  }

  static Future<bool> setChatOptions(
    Api api, {
    required int chatId,
    required Map<String, dynamic> options,
  }) async {
    final packet = await api.sendRequest(Opcode.chatUpdate, {
      'chatId': chatId,
      'options': options,
    });
    return packet.isOk;
  }

  static Future<bool> setChatTitle(
    Api api, {
    required int chatId,
    required String title,
  }) async {
    final packet = await api.sendRequest(Opcode.chatUpdate, {
      'chatId': chatId,
      'theme': title,
    });
    if (!packet.isOk) return false;
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return true;
    final rows = await AppDatabase.loadChat(accountId, chatId);
    if (rows.isNotEmpty) {
      final updated = Map<String, dynamic>.from(rows.first);
      updated['title'] = title;
      await AppDatabase.saveChats([updated]);
      _bump();
    }
    return true;
  }

  static Future<String?> togglePin(
    Api api, {
    required List<int> chatIds,
    required bool pin,
  }) async {
    if (chatIds.isEmpty) return null;
    try {
      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId == null) return 'Нет активного аккаунта';
      final folders = await FoldersModule.loadFolders(accountId);
      final allFolder = folders.firstWhere(
        FoldersModule.isAllChatsFolder,
        orElse: () => folders.isEmpty
            ? throw StateError('Папка "Все" не найдена')
            : folders.first,
      );

      final favorites = List<int>.from(allFolder.favorites ?? const []);
      if (pin) {
        for (final id in chatIds) {
          if (!favorites.contains(id)) favorites.add(id);
        }
      } else {
        favorites.removeWhere((id) => chatIds.contains(id));
      }

      await FoldersModule.setFolderFavorites(api, accountId, allFolder, favorites);

      final existingRows = await AppDatabase.loadChatsByIds(accountId, chatIds);
      final updates = <Map<String, dynamic>>[];
      for (final row in existingRows) {
        final id = row['id'] as int;
        final isFav = favorites.contains(id);
        final currentFav = row['fav_index'] as int?;
        final newFav = isFav
            ? ((currentFav ?? 0) > 0 ? currentFav : favorites.indexOf(id) + 1)
            : 0;
        if (currentFav == newFav) continue;
        final newRow = Map<String, dynamic>.from(row);
        newRow['fav_index'] = newFav;
        updates.add(newRow);
      }
      if (updates.isNotEmpty) {
        await AppDatabase.saveChats(updates);
        _bump();
      }
      return null;
    } on PacketError catch (e) {
      logger.w('togglePin: ${e.message}');
      return e.message;
    } catch (e) {
      logger.w('togglePin: $e');
      return 'Не удалось изменить закрепление';
    }
  }

  static Future<String?> setChatMute(
    Api api, {
    required int chatId,
    required int dontDisturbUntil,
  }) async {
    try {
      await api.sendRequest(Opcode.config, {
        'settings': {
          'chats': {
            chatId: {'dontDisturbUntil': dontDisturbUntil},
          },
        },
      });
      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId != null) {
        final rows = await AppDatabase.loadChat(accountId, chatId);
        if (rows.isNotEmpty) {
          final row = Map<String, dynamic>.from(rows.first);
          row['dont_disturb_until'] = dontDisturbUntil;
          await AppDatabase.saveChats([row]);
          _bump();
        }
      }
      return null;
    } on PacketError catch (e) {
      logger.w('setChatMute $chatId: ${e.message}');
      return e.message;
    } catch (e) {
      logger.w('setChatMute $chatId: $e');
      return 'Не удалось изменить уведомления';
    }
  }

  static Future<String?> deleteChat(
    Api api, {
    required int chatId,
    required int lastEventTime,
    required bool forAll,
  }) async {
    try {
      await api.sendRequest(Opcode.chatDelete, {
        'chatId': chatId,
        'lastEventTime': lastEventTime,
        'forAll': forAll,
      });
      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId != null) {
        await AppDatabase.deleteChat(chatId, accountId);
        _bump();
      }
      return null;
    } on PacketError catch (e) {
      logger.w('deleteChat $chatId: ${e.message}');
      return e.message;
    } catch (e) {
      logger.w('deleteChat $chatId: $e');
      return 'Не удалось удалить чат';
    }
  }

  static Future<bool> leaveChat(Api api, {required int chatId}) async {
    try {
      await api.sendRequest(Opcode.chatLeave, {'chatId': chatId});
      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId != null) {
        await AppDatabase.deleteChat(chatId, accountId);
        _bump();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<CachedChat>> refreshChats(
    Api api,
    List<int> chatIds,
  ) async {
    if (chatIds.isEmpty) return const [];
    try {
      final packet = await api.sendRequest(Opcode.chatInfo, {
        'chatIds': chatIds,
      });
      final payload = packet.payload;
      if (payload is! Map) return const [];
      final list = payload['chats'];
      if (list is! List) return const [];
      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId == null) return const [];
      final existingRows = await AppDatabase.loadChatsByIds(accountId, chatIds);
      final preloadedExisting = {
        for (final row in existingRows)
          row['id'] as int: CachedChat.fromDbRow(row),
      };
      final out = <CachedChat>[];
      for (final c in list) {
        if (c is Map) {
          final cached = await cacheServerChat(
            c,
            accountId,
            preloadedExisting: preloadedExisting,
          );
          if (cached != null) out.add(cached);
        }
      }
      return out;
    } on PacketError catch (e) {
      logger.w('refreshChats: ${e.message}');
      return const [];
    } catch (e) {
      logger.w('refreshChats: $e');
      return const [];
    }
  }
}
