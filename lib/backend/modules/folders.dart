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
    return t == 'все' ||
        t == 'все чаты' ||
        t == 'all' ||
        t == 'all chats';
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
    final orderedIds = foldersOrder.map((id) => id.toString()).toList();
    folders.sort((a, b) {
      final aIndex = orderedIds.indexOf(a.id);
      final bIndex = orderedIds.indexOf(b.id);
      if (aIndex == -1 && bIndex == -1) return 0;
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });
  }

  static bool chatMatchesFolder(CachedChat chat, ChatFolder folder) {
    if (folder.include != null && folder.include!.isNotEmpty) {
      return folder.include!.contains(chat.id);
    }
    if (folder.filters.isEmpty) return false;

    final hasContact = folder.filters.any(
      (f) => f == 9 || f == '9' || f == 'CONTACT',
    );
    final hasNotContact = folder.filters.any(
      (f) => f == 8 || f == '8' || f == 'NOT_CONTACT',
    );

    if (hasContact && hasNotContact) {
      if (chat.type != 'DIALOG') return false;
      return true;
    }

    for (final filter in folder.filters) {
      if (filter == 0 || filter == '0' || filter == 'UNREAD') {
        if (chat.unreadCount > 0) return true;
      } else if (filter == 9 || filter == '9' || filter == 'CONTACT') {
        if (chat.type == 'DIALOG') return true;
      } else if (filter == 8 || filter == '8' || filter == 'NOT_CONTACT') {
        if (chat.type == 'CHAT' || chat.type == 'CHANNEL') return true;
      }
    }
    return false;
  }

  static Future<List<ChatFolder>> loadFolders(int accountId) async {
    final raw = await AppDatabase.getSyncValue(accountId, _syncKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final folders = (map['folders'] as List<dynamic>?)
              ?.map((e) {
                final m = e is Map<String, dynamic>
                    ? e
                    : Map<String, dynamic>.from(e as Map);
                return ChatFolder.fromJson(m);
              })
              .toList() ??
          [];
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
      folders = foldersJson
          .map((json) {
            try {
              final m = json is Map<String, dynamic>
                  ? json
                  : Map<String, dynamic>.from(json as Map);
              return ChatFolder.fromJson(m);
            } catch (_) {
              return null;
            }
          })
          .whereType<ChatFolder>()
          .toList();
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
    final folders = foldersJson
        .map((json) {
          try {
            final m = json is Map<String, dynamic>
                ? json
                : Map<String, dynamic>.from(json as Map);
            return ChatFolder.fromJson(m);
          } catch (_) {
            return null;
          }
        })
        .whereType<ChatFolder>()
        .toList();
    sortFoldersInPlace(folders, order);
    await _persist(accountId, folders, order);
    await markFoldersListReady(accountId);
  }

  static Future<void> syncFromServer(Api api, int accountId) async {
    try {
      final packet = await api.sendRequest(Opcode.foldersGet, {
        'folderSync': 0,
      });
      if (packet.isError) {
        throw PacketError(messageFromErrorPayload(packet.payload));
      }
      final data = packet.payload;
      if (data is Map) {
        await applyPayload(accountId, data.cast<dynamic, dynamic>());
      }
    } finally {
      await markFoldersListReady(accountId);
    }
  }
}
