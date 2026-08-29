import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api.dart';
import '../models/chat_folder.dart';
import 'chats.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';

class _FoldersSnapshot {
  final List<ChatFolder> folders;
  final List<String> order;
  final int folderSync;

  const _FoldersSnapshot({
    this.folders = const [],
    this.order = const [],
    this.folderSync = 0,
  });
}

class FoldersModule {
  static const _syncKey = 'chat_folders_snapshot';
  static const _listReadyKey = 'chat_folders_list_ready';

  static const String allChatsFolderId = 'all.chat.folder';
  static const int titleMaxLength = 20;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static StreamSubscription<Packet>? _pushSub;
  static Future<void> _pushQueue = Future.value();

  static void attachGlobalPushHandlers(Api api) {
    _pushSub?.cancel();
    _pushSub = api.pushStream
        .where((p) => p.opcode == Opcode.notifFolders)
        .listen(_enqueuePush);
  }

  static void _enqueuePush(Packet packet) {
    _pushQueue = _pushQueue
        .then((_) => _handleFoldersPush(packet))
        .catchError((Object _) {});
  }

  static Future<void> _handleFoldersPush(Packet packet) async {
    final payload = packet.payload;
    if (payload is! Map) return;
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;
    await applyPayload(accountId, payload.cast<dynamic, dynamic>());
    await chats.applyFavorites(accountId);
  }

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
    if (f.id == allChatsFolderId) return true;
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

  static String newFolderId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static void _sortInPlace(List<ChatFolder> folders, List<String> order) {
    if (order.isEmpty) return;
    final orderIndex = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      orderIndex.putIfAbsent(order[i], () => i);
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

  static bool _matchesType(
    int filter,
    CachedChat chat, {
    required int myId,
    required Set<int> contactIds,
  }) {
    final isDialog = chat.type == 'DIALOG';
    final isBot = isDialog && chat.options.contains('BOT');
    final peerId = isDialog ? chat.id ^ myId : null;
    final isSelf = peerId != null && peerId == myId;
    final isContact =
        isDialog && !isSelf && peerId != null && contactIds.contains(peerId);

    switch (filter) {
      case FolderFilter.channel:
        return chat.type == 'CHANNEL';
      case FolderFilter.chat:
        return chat.type == 'CHAT' || chat.type == 'GROUP';
      case FolderFilter.dialog:
        return isDialog;
      case FolderFilter.contact:
        return isDialog && !isBot && isContact;
      case FolderFilter.notContact:
        return isDialog && !isBot && !isSelf && !isContact;
      case FolderFilter.bot:
        return isBot;
    }
    return false;
  }

  static bool _matchesRole(int filter, CachedChat chat, int myId) {
    switch (filter) {
      case FolderFilter.owner:
        return chat.owner == myId;
      case FolderFilter.admin:
        return chat.owner == myId || chat.admins.contains(myId);
    }
    return false;
  }

  static bool _matchesRestriction(int filter, CachedChat chat) {
    switch (filter) {
      case FolderFilter.unread:
        return chat.unreadCount > 0;
      case FolderFilter.read:
        return chat.unreadCount == 0;
      case FolderFilter.muted:
        return chat.isMuted;
      case FolderFilter.notMuted:
        return !chat.isMuted;
    }
    return true;
  }

  static bool chatMatchesFolder(
    CachedChat chat,
    ChatFolder folder, {
    required int myId,
    required Set<int> contactIds,
  }) {
    if (!folder.include.contains(chat.id)) {
      final typeFilters = folder.filters
          .where(FolderFilter.chatTypes.contains)
          .toList();
      if (typeFilters.isEmpty) return false;
      final matchesType = typeFilters.any(
        (f) => _matchesType(f, chat, myId: myId, contactIds: contactIds),
      );
      if (!matchesType) return false;
    }

    final roleFilters = folder.filters.where(FolderFilter.roles.contains);
    if (roleFilters.isNotEmpty &&
        !roleFilters.any((f) => _matchesRole(f, chat, myId))) {
      return false;
    }

    for (final f in folder.filters.where(FolderFilter.showOnly.contains)) {
      if (!_matchesRestriction(f, chat)) return false;
    }
    return true;
  }

  /// Чаты папки с учётом архива: архивный чат остаётся в папке, только если
  /// добавлен в неё вручную. Правила по типу чата не должны вытаскивать его
  /// из архива обратно, а вручную добавленный чат не должен пропадать из
  /// папки только потому, что его убрали в архив.
  static List<CachedChat> chatsForFolder(
    Iterable<CachedChat> chats,
    ChatFolder folder, {
    required int myId,
    required Set<int> contactIds,
    required Set<int> archivedIds,
  }) => chats
      .where(
        (c) =>
            (!archivedIds.contains(c.id) || folder.include.contains(c.id)) &&
            chatMatchesFolder(c, folder, myId: myId, contactIds: contactIds),
      )
      .toList();

  static List<ChatFolder> _parseFolderList(dynamic raw) {
    if (raw is! List) return [];
    return raw
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

  static List<String>? _parseOrder(dynamic raw) {
    if (raw is! List) return null;
    return raw.map((e) => e.toString()).toList();
  }

  static int? _parseSync(dynamic raw) => raw is int ? raw : null;

  static Future<_FoldersSnapshot> _loadSnapshot(int accountId) async {
    final raw = await AppDatabase.getSyncValue(accountId, _syncKey);
    if (raw == null || raw.isEmpty) return const _FoldersSnapshot();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final folders = _parseFolderList(map['folders']);
      final order = _parseOrder(map['foldersOrder']) ?? const <String>[];
      _sortInPlace(folders, order);
      return _FoldersSnapshot(
        folders: folders,
        order: order,
        folderSync: _parseSync(map['folderSync']) ?? 0,
      );
    } catch (_) {
      return const _FoldersSnapshot();
    }
  }

  static Future<void> _saveSnapshot(
    int accountId,
    _FoldersSnapshot snapshot,
  ) async {
    final known = snapshot.folders.map((f) => f.id).toSet();
    final ordered = snapshot.order.where(known.contains).toList();
    final orderedSet = ordered.toSet();
    final order = [
      ...ordered,
      ...known.where((id) => !orderedSet.contains(id)),
    ];
    await AppDatabase.setSyncValue(
      accountId,
      _syncKey,
      jsonEncode({
        'folders': snapshot.folders.map((f) => f.toJson()).toList(),
        'foldersOrder': order,
        'folderSync': snapshot.folderSync,
      }),
    );
    revision.value++;
  }

  static Future<List<ChatFolder>> loadFolders(int accountId) async {
    return (await _loadSnapshot(accountId)).folders;
  }

  static Future<List<String>> loadFoldersOrder(int accountId) async {
    return (await _loadSnapshot(accountId)).order;
  }

  static Future<int> loadFolderSync(int accountId) async {
    return (await _loadSnapshot(accountId)).folderSync;
  }

  static Future<void> applyPayload(
    int accountId,
    Map<dynamic, dynamic> payload, {
    bool replace = false,
  }) async {
    final foldersRaw = payload['folders'];
    final folderRaw = payload['folder'];
    final orderRaw = payload['foldersOrder'];
    final syncRaw = payload['folderSync'];
    if (foldersRaw == null &&
        folderRaw == null &&
        orderRaw == null &&
        syncRaw == null) {
      return;
    }

    final incoming = <ChatFolder>[
      ..._parseFolderList(foldersRaw),
      if (folderRaw is Map)
        ChatFolder.fromJson(Map<String, dynamic>.from(folderRaw)),
    ];

    final current = await _loadSnapshot(accountId);
    var folders = replace && foldersRaw is List
        ? List<ChatFolder>.from(incoming)
        : _merge(current.folders, incoming);

    final order = _parseOrder(orderRaw) ?? current.order;
    if (orderRaw is List && order.isNotEmpty) {
      final known = order.toSet();
      final fresh = incoming.map((f) => f.id).toSet();
      folders = folders
          .where((f) => known.contains(f.id) || fresh.contains(f.id))
          .toList();
    }

    _sortInPlace(folders, order);
    await _saveSnapshot(
      accountId,
      _FoldersSnapshot(
        folders: folders,
        order: order,
        folderSync: _parseSync(syncRaw) ?? current.folderSync,
      ),
    );
  }

  static List<ChatFolder> _merge(
    List<ChatFolder> current,
    List<ChatFolder> incoming,
  ) {
    final merged = List<ChatFolder>.from(current);
    for (final folder in incoming) {
      final idx = merged.indexWhere((f) => f.id == folder.id);
      if (idx >= 0) {
        merged[idx] = folder;
      } else {
        merged.add(folder);
      }
    }
    return merged;
  }

  static Future<void> applyFromLoginConfig(
    int accountId,
    Map<dynamic, dynamic> config,
  ) async {
    final chatFolders = config['chatFolders'];
    if (chatFolders is! Map) return;
    if (chatFolders['FOLDERS'] == null) return;
    await applyPayload(accountId, {
      'folders': chatFolders['FOLDERS'],
      'foldersOrder': chatFolders['foldersOrder'],
      'folderSync': chatFolders['folderSync'],
    }, replace: true);
    await markFoldersListReady(accountId);
  }

  static Future<ChatFolder> createFolder(
    Api api,
    int accountId, {
    required String title,
    List<int> include = const [],
    List<int> filters = const [],
    List<int> options = const [],
    List<int> favorites = const [],
  }) {
    return _sendUpdate(
      api,
      accountId,
      id: newFolderId(),
      title: title,
      include: include,
      filters: filters,
      options: options,
      favorites: favorites,
    );
  }

  static Future<ChatFolder> updateFolder(
    Api api,
    int accountId,
    ChatFolder folder, {
    String? title,
    List<int>? include,
    List<int>? filters,
    List<int>? options,
    List<int>? favorites,
  }) {
    return _sendUpdate(
      api,
      accountId,
      id: folder.id,
      title: title ?? folder.title,
      include: include ?? folder.include,
      filters: filters ?? folder.filters,
      options: options ?? folder.options,
      favorites: favorites ?? folder.favorites,
    );
  }

  static Future<ChatFolder> _sendUpdate(
    Api api,
    int accountId, {
    required String id,
    required String title,
    required List<int> include,
    required List<int> filters,
    required List<int> options,
    required List<int> favorites,
  }) async {
    final packet = await api.sendRequest(Opcode.foldersUpdate, {
      'id': id,
      'title': title.trim(),
      'include': include,
      'filters': filters,
      'options': options,
      'favorites': favorites,
    });
    throwIfPacketError(packet);

    final data = packet.payload;
    final folderJson = data is Map ? data['folder'] : null;
    if (folderJson is! Map) {
      throw StateError('FOLDERS_UPDATE: сервер не вернул папку');
    }
    await applyPayload(accountId, data.cast<dynamic, dynamic>());
    return ChatFolder.fromJson(Map<String, dynamic>.from(folderJson));
  }

  static Future<ChatFolder> setFolderFavorites(
    Api api,
    int accountId,
    ChatFolder folder,
    List<int> favorites,
  ) {
    return updateFolder(api, accountId, folder, favorites: favorites);
  }

  static Future<void> deleteFolders(
    Api api,
    int accountId,
    List<String> folderIds,
  ) async {
    if (folderIds.isEmpty) return;
    final packet = await api.sendRequest(Opcode.foldersDelete, {
      'folderIds': folderIds,
    });
    throwIfPacketError(packet);

    final removed = folderIds.toSet();
    final current = await _loadSnapshot(accountId);
    await _saveSnapshot(
      accountId,
      _FoldersSnapshot(
        folders: current.folders.where((f) => !removed.contains(f.id)).toList(),
        order: current.order,
        folderSync: current.folderSync,
      ),
    );

    final data = packet.payload;
    if (data is Map) {
      await applyPayload(accountId, data.cast<dynamic, dynamic>());
    }
  }

  static Future<void> reorderFolders(
    Api api,
    int accountId,
    List<String> order,
  ) async {
    if (order.isEmpty) return;
    final packet = await api.sendRequest(Opcode.foldersReorder, {
      'foldersOrder': order,
    });
    throwIfPacketError(packet);

    final current = await _loadSnapshot(accountId);
    final folders = List<ChatFolder>.from(current.folders);
    _sortInPlace(folders, order);
    final data = packet.payload;
    await _saveSnapshot(
      accountId,
      _FoldersSnapshot(
        folders: folders,
        order: order,
        folderSync:
            (data is Map ? _parseSync(data['folderSync']) : null) ??
            current.folderSync,
      ),
    );
  }

  static Future<List<ChatFolder>> fetchFoldersByIds(
    Api api,
    int accountId,
    List<String> folderIds,
  ) async {
    if (folderIds.isEmpty) return const [];
    final packet = await api.sendRequest(Opcode.foldersGetById, {
      'folderIds': folderIds,
    });
    throwIfPacketError(packet);

    final data = packet.payload;
    if (data is! Map) return const [];
    final folders = _parseFolderList(data['folders']);

    final missing = folderIds.toSet()..removeAll(folders.map((f) => f.id));
    final current = await _loadSnapshot(accountId);
    await _saveSnapshot(
      accountId,
      _FoldersSnapshot(
        folders: _merge(
          current.folders.where((f) => !missing.contains(f.id)).toList(),
          folders,
        ),
        order: current.order,
        folderSync: _parseSync(data['folderSync']) ?? current.folderSync,
      ),
    );
    return folders;
  }

  static Future<void> syncFromServer(Api api, int accountId) async {
    try {
      final packet = await api.sendRequest(Opcode.foldersGet, {
        'folderSync': 0,
      });
      throwIfPacketError(packet);
      final data = packet.payload;
      if (data is Map) {
        await applyPayload(
          accountId,
          data.cast<dynamic, dynamic>(),
          replace: true,
        );
      }
    } finally {
      await markFoldersListReady(accountId);
    }
  }
}
