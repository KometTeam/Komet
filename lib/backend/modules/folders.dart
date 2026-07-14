import 'dart:convert';

import '../api.dart';
import '../models/chat_folder.dart';
import 'chats.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';

class FoldersModule {
  static const _syncKey = 'chat_folders_snapshot';
  static const _listReadyKey = 'chat_folders_list_ready';

  static Future<void> markFoldersListReady(int accountId) async {
    await AppDatabase.setSyncValue(accountId, _listReadyKey, '1');
  }

  static Future<bool> hasReceivedFoldersList(int accountId) async {
    final ready = await AppDatabase.getSyncValue(accountId, _listReadyKey);
    if (ready == '1') return true;
    final snap = await AppDatabase.getSyncValue(accountId, _syncKey);
    return snap != null && snap.isNotEmpty;
  }

  static bool isAllChatsFolder(ChatFolder f) {
    if (f.id == 'all.chat.folder') return true;
    final t = f.title.trim().toLowerCase();
    return t == 'все' || t == 'все чаты' || t == 'all' || t == 'all chats';
  }

  static String? preferredInitialFolderId(List<ChatFolder> folders) {
    if (folders.isEmpty) return null;
    for (final f in folders) {
      if (isAllChatsFolder(f)) return f.id;
    }
    return folders.first.id;
  }

  static void sortFoldersInPlace(
    List<ChatFolder> folders,
    List<dynamic>? foldersOrder,
  ) {
    if (foldersOrder == null || foldersOrder.isEmpty) return;
    final orderIndex = <String, int>{};
    for (var i = 0; i < foldersOrder.length; i++) {
      orderIndex.putIfAbsent(foldersOrder[i].toString(), () => i);
    }
    folders.sort((a, b) {
      final aIndex = orderIndex[a.id] ?? -1;
      final bIndex = orderIndex[b.id] ?? -1;
      if (aIndex == -1 && bIndex == -1) return 0;
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });
  }

  static const int filterUnread = 0;
  static const int filterChannel = 2;
  static const int filterGroup = 3;
  static const int filterContact = 8;
  static const int filterNotContact = 9;
  static const int filterBot = 10;

  static int? _filterCode(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) {
      final n = int.tryParse(raw);
      if (n != null) return n;
      switch (raw) {
        case 'UNREAD':
          return filterUnread;
        case 'CHANNEL':
          return filterChannel;
        case 'GROUP':
        case 'CHAT':
          return filterGroup;
        case 'CONTACT':
          return filterContact;
        case 'NOT_CONTACT':
          return filterNotContact;
        case 'BOT':
          return filterBot;
      }
    }
    return null;
  }

  static bool chatMatchesFolder(
    CachedChat chat,
    ChatFolder folder, {
    required int myId,
    required Set<int> contactIds,
  }) {
    if (folder.include != null && folder.include!.contains(chat.id)) {
      return true;
    }
    if (folder.filters.isEmpty) return false;

    final isDialog = chat.type == 'DIALOG';
    final isBot = isDialog && chat.options.contains('BOT');
    final peerId = isDialog ? chat.id ^ myId : null;
    final isSelf = peerId != null && peerId == myId;
    final isContact =
        isDialog && !isSelf && peerId != null && contactIds.contains(peerId);

    for (final raw in folder.filters) {
      switch (_filterCode(raw)) {
        case filterUnread:
          if (chat.unreadCount > 0) return true;
        case filterChannel:
          if (chat.type == 'CHANNEL') return true;
        case filterGroup:
          if (chat.type == 'CHAT' || chat.type == 'GROUP') return true;
        case filterContact:
          if (isDialog && !isBot && isContact) return true;
        case filterNotContact:
          if (isDialog && !isBot && !isSelf && !isContact) return true;
        case filterBot:
          if (isBot) return true;
      }
    }
    return false;
  }

  static List<ChatFolder> _parseFolderList(
    List<dynamic> json, {
    bool lenient = true,
  }) {
    if (lenient) {
      return json
          .map((e) {
            try {
              final m = e is Map<String, dynamic>
                  ? e
                  : Map<String, dynamic>.from(e as Map);
              return ChatFolder.fromJson(m);
            } catch (_) {
              return null;
            }
          })
          .whereType<ChatFolder>()
          .toList();
    }
    return json.map((e) {
      final m = e is Map<String, dynamic>
          ? e
          : Map<String, dynamic>.from(e as Map);
      return ChatFolder.fromJson(m);
    }).toList();
  }

  static Future<List<ChatFolder>> loadFolders(int accountId) async {
    final raw = await AppDatabase.getSyncValue(accountId, _syncKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final foldersJson = map['folders'] as List<dynamic>?;
      final folders = foldersJson == null
          ? <ChatFolder>[]
          : _parseFolderList(foldersJson, lenient: false);
      final order = map['foldersOrder'] as List<dynamic>?;
      sortFoldersInPlace(folders, order);
      return folders;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _persist(
    int accountId,
    List<ChatFolder> folders,
    List<dynamic>? order,
  ) async {
    await AppDatabase.setSyncValue(
      accountId,
      _syncKey,
      jsonEncode({
        'folders': folders.map((f) => f.toJson()).toList(),
        'foldersOrder': order,
      }),
    );
  }

  static Future<void> applyPayload(
    int accountId,
    Map<dynamic, dynamic> payload,
  ) async {
    final foldersJson = payload['folders'] as List<dynamic>?;
    final order = payload['foldersOrder'] as List<dynamic>?;
    if (foldersJson == null && order == null) return;

    List<ChatFolder> folders;
    if (foldersJson != null) {
      folders = _parseFolderList(foldersJson);
    } else {
      folders = await loadFolders(accountId);
    }
    sortFoldersInPlace(folders, order);
    await _persist(accountId, folders, order);
  }

  static Future<void> applyFromLoginConfig(
    int accountId,
    Map<dynamic, dynamic> config,
  ) async {
    final chatFolders = config['chatFolders'];
    if (chatFolders is! Map) return;
    final foldersJson = chatFolders['FOLDERS'] as List<dynamic>?;
    if (foldersJson == null) return;
    final order = chatFolders['foldersOrder'] as List<dynamic>?;
    final folders = _parseFolderList(foldersJson);
    sortFoldersInPlace(folders, order);
    await _persist(accountId, folders, order);
    await markFoldersListReady(accountId);
  }

  static Future<ChatFolder?> setFolderFavorites(
    Api api,
    int accountId,
    ChatFolder folder,
    List<int> favorites,
  ) async {
    final packet = await api.sendRequest(Opcode.foldersUpdate, {
      'id': folder.id,
      'title': folder.title,
      'include': folder.include ?? const [],
      'favorites': favorites,
      'filters': folder.filters,
      'options': folder.options ?? const [],
    });
    throwIfPacketError(packet);
    final data = packet.payload;
    if (data is! Map) return null;
    final folderJson = data['folder'];
    if (folderJson is! Map) return null;
    final updated = ChatFolder.fromJson(
      folderJson is Map<String, dynamic>
          ? folderJson
          : Map<String, dynamic>.from(folderJson),
    );

    final currentRaw = await AppDatabase.getSyncValue(accountId, _syncKey);
    final snapshot = (currentRaw != null && currentRaw.isNotEmpty)
        ? jsonDecode(currentRaw) as Map<String, dynamic>
        : <String, dynamic>{};
    final existingRaw = snapshot['folders'] as List<dynamic>?;
    final existing = existingRaw == null
        ? <ChatFolder>[]
        : _parseFolderList(existingRaw, lenient: false);
    final idx = existing.indexWhere((f) => f.id == updated.id);
    if (idx >= 0) {
      existing[idx] = updated;
    } else {
      existing.add(updated);
    }
    final order = snapshot['foldersOrder'] as List<dynamic>?;
    await _persist(accountId, existing, order);
    return updated;
  }

  static Future<void> syncFromServer(Api api, int accountId) async {
    try {
      final packet = await api.sendRequest(Opcode.foldersGet, {
        'folderSync': 0,
      });
      throwIfPacketError(packet);
      final data = packet.payload;
      if (data is Map) {
        await applyPayload(accountId, data.cast<dynamic, dynamic>());
      }
    } finally {
      await markFoldersListReady(accountId);
    }
  }
}
