import 'dart:async';

import '../../core/cache/info_cache.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/storage/token_storage.dart';
import '../../models/admin_rights.dart';
import '../../models/chat_info.dart';
import '../../models/chat_reaction_settings.dart';
import '../api.dart';
import 'chats.dart';

class ChatAdminModule {
  final Api _api;

  ChatAdminModule(this._api);

  late final InfoCache<ChatReactionSettings> _reactionCache = InfoCache(
    ttl: const Duration(minutes: 5),
    fetcher: _fetchReactionSettings,
  );

  final StreamController<({int chatId, ChatReactionSettings settings})>
  _reactionUpdates = StreamController.broadcast();

  Stream<({int chatId, ChatReactionSettings settings})> get reactionUpdates =>
      _reactionUpdates.stream;

  Future<ChatReactionSettings?> reactionSettingsFor(
    int chatId, {
    bool forceRefresh = false,
  }) => _reactionCache.get(chatId, forceRefresh: forceRefresh);

  Future<ChatInfo> setAdmin(int chatId, int userId, AdminRights rights) =>
      _apply(chatId, Opcode.chatMembersUpdate, {
        'userIds': [userId],
        'type': 'ADMIN',
        'operation': 'add',
        'permissions': rights.bits,
      });

  Future<ChatInfo> removeAdmin(int chatId, int userId) =>
      _apply(chatId, Opcode.chatMembersUpdate, {
        'userIds': [userId],
        'type': 'ADMIN',
        'operation': 'remove',
      });

  Future<ChatInfo> transferOwnership(int chatId, int userId) =>
      _apply(chatId, Opcode.chatUpdate, {'changeOwnerId': userId});

  Future<ChatInfo> revokeInviteLink(int chatId) =>
      _apply(chatId, Opcode.chatUpdate, {'revokePrivateLink': true});

  Future<ChatInfo> setOptions(int chatId, Map<String, bool> options) =>
      _apply(chatId, Opcode.chatUpdate, {'options': options});

  Future<ChatInfo> updateInfo(
    int chatId, {
    required String title,
    required String description,
  }) => _apply(chatId, Opcode.chatUpdate, {
    'theme': title,
    'description': description,
  });

  Future<ChatInfo> setPhoto(int chatId, String photoToken) =>
      _apply(chatId, Opcode.chatUpdate, {'photoToken': photoToken});

  Future<ChatReactionSettings?> _fetchReactionSettings(int chatId) async {
    final packet = await _api.sendRequest(Opcode.reactionsSettingsGetByChatId, {
      'chatIds': [chatId],
    }, silent: true);
    final payload = packet.payload;
    final list = payload is Map ? payload['chatReactionsSettings'] : null;
    if (list is! List) return null;
    for (final entry in list) {
      if (entry is Map && entry['chatId'] == chatId) {
        return ChatReactionSettings.fromMap(entry);
      }
    }
    return null;
  }

  Future<ChatReactionSettings> disableReactions(int chatId) =>
      _applyReactions(chatId, {'chatId': chatId, 'value': false});

  Future<ChatReactionSettings> setReactions(
    int chatId, {
    required int count,
    required List<String> forbidden,
  }) => _applyReactions(chatId, {
    'chatId': chatId,
    'value': true,
    'count': count,
    'reactionIds': forbidden,
    'included': false,
  });

  Future<ChatReactionSettings> _applyReactions(
    int chatId,
    Map<String, dynamic> payload,
  ) async {
    final packet = await _api.sendRequest(
      Opcode.chatReactionsSettingsSet,
      payload,
      silent: true,
    );
    final data = packet.payload;
    final settings = ChatReactionSettings.fromMap(
      data is Map ? data['chatReactionsSettings'] : null,
    );
    if (settings == null) {
      throw StateError('reaction settings missing from the answer');
    }
    _reactionCache.putValue(chatId, settings);
    _reactionUpdates.add((chatId: chatId, settings: settings));
    return settings;
  }

  Future<ChatInfo> _apply(
    int chatId,
    int opcode,
    Map<String, dynamic> change,
  ) async {
    final packet = await _api.sendRequest(opcode, {
      'chatId': chatId,
      ...change,
    }, silent: true);
    final payload = packet.payload;
    final chat = payload is Map ? payload['chat'] : null;
    if (chat is! Map) {
      final refreshed = await ChatInfoFetch.get(chatId, forceRefresh: true);
      if (refreshed == null) throw StateError('chat $chatId not refreshed');
      return refreshed;
    }
    final info = ChatInfo.fromMap(Map<String, dynamic>.from(chat));
    ChatInfoFetch.put(chatId, info);
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId != null) await chats.cacheServerChat(chat, accountId);
    return info;
  }
}
