import 'package:shared_preferences/shared_preferences.dart';

import '../../models/attachment.dart';
import '../../core/protocol/opcode_map.dart';
import '../api.dart';
import 'chats.dart';
import 'messages.dart';

class CloudFile {
  final String name;
  final int? size;
  final int time;
  final int? fileId;
  final String messageId;
  final int chatId;
  final int accountId;

  const CloudFile({
    required this.name,
    this.size,
    required this.time,
    this.fileId,
    required this.messageId,
    required this.chatId,
    required this.accountId,
  });
}

class CloudStorageModule {
  static const _prefix = 'CLST';
  static const _tempName = 'Облачное хранилище';

  // Key: "$accountId:$fileId" — scoped per account
  static final Map<String, ({String url, int expires})> _linkCache = {};

  static int _computeSpecialNumber(int groupId) {
    final s = groupId.abs().toString();
    final len = s.length;
    if (len < 4) {
      final n = int.parse(s);
      return n + n;
    }
    final first = int.parse(s.substring(0, 4));
    final last = int.parse(s.substring(len - 4));
    return first + last;
  }

  static bool isCloudStorageGroup(CachedChat chat) {
    if (chat.type != 'CHAT') return false;
    final title = chat.title;
    if (title == null || !title.startsWith(_prefix)) return false;
    final numStr = title.substring(_prefix.length);
    final provided = int.tryParse(numStr);
    if (provided == null) return false;
    return provided == _computeSpecialNumber(chat.id);
  }

  static CachedChat? findEnvGroup(List<CachedChat> chats) {
    for (final c in chats) {
      if (isCloudStorageGroup(c)) return c;
    }
    return null;
  }

  static List<CachedChat> findOrphanGroups(List<CachedChat> chats) =>
      chats.where((c) => c.type == 'CHAT' && c.title == _tempName).toList();

  // Env group ID cache — avoids scanning all chats on every screen open
  static Future<void> cacheEnvGroupId(int accountId, int groupId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cloud_storage_env_$accountId', groupId);
  }

  static Future<int?> getCachedEnvGroupId(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('cloud_storage_env_$accountId');
  }

  static Future<void> clearEnvGroupCache(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cloud_storage_env_$accountId');
  }

  static Future<void> _configurePrivacy(Api api, int chatId) async {
    await chats.setChatOptions(
      api,
      chatId: chatId,
      options: {
        'ONLY_OWNER_CAN_CHANGE_ICON_TITLE': true,
        'ONLY_ADMIN_CAN_ADD_MEMBER': true,
        'ALL_CAN_PIN_MESSAGE': false,
        'ONLY_ADMIN_CAN_CALL': true,
      },
    );
  }

  static Future<CachedChat?> setupEnv(Api api) async {
    final temp = await chats.createGroupChat(
      api,
      title: _tempName,
      userIds: [],
    );
    if (temp == null) return null;
    final name = '$_prefix${_computeSpecialNumber(temp.id)}';
    final ok = await chats.setChatTitle(api, chatId: temp.id, title: name);
    if (!ok) return null;
    await _configurePrivacy(api, temp.id);
    return temp;
  }

  // Turns an orphan "Облачное хранилище" group into a valid env group
  static Future<CachedChat?> repairOrphan(Api api, CachedChat orphan) async {
    final name = '$_prefix${_computeSpecialNumber(orphan.id)}';
    final ok = await chats.setChatTitle(api, chatId: orphan.id, title: name);
    if (!ok) return null;
    await _configurePrivacy(api, orphan.id);
    return orphan;
  }

  static Iterable<CloudFile> _cloudFilesFrom(
    Iterable<CachedMessage> msgs,
    int chatId,
    int accountId,
  ) sync* {
    for (final msg in msgs) {
      for (final a in msg.attachments ?? []) {
        if (a is FileAttachment && a.name != null) {
          yield CloudFile(
            name: a.name!,
            size: a.size,
            time: msg.time,
            fileId: a.fileId,
            messageId: msg.id,
            chatId: chatId,
            accountId: accountId,
          );
        }
      }
    }
  }

  static Future<List<CloudFile>> fetchFiles(
    MessagesModule messages,
    int accountId,
    int chatId, {
    int count = 200,
  }) async {
    final msgs = await messages.fetchHistory(accountId, chatId, count: count);
    return _cloudFilesFrom(msgs, chatId, accountId).toList();
  }

  // Fetches only the last few messages to find a newly uploaded file — avoids full 200-msg reload
  static Future<CloudFile?> fetchLatestFile(
    MessagesModule messages,
    int accountId,
    int chatId, {
    int? expectedFileId,
  }) async {
    final msgs = await messages.fetchHistory(accountId, chatId, count: 5);
    for (final file in _cloudFilesFrom(msgs, chatId, accountId)) {
      if (expectedFileId == null || file.fileId == expectedFileId) {
        return file;
      }
    }
    return null;
  }

  static ({String url, int expires})? getCachedLink(int accountId, int fileId) {
    final key = '$accountId:$fileId';
    final entry = _linkCache[key];
    if (entry == null) return null;
    if (entry.expires <= DateTime.now().millisecondsSinceEpoch) {
      _linkCache.remove(key);
      return null;
    }
    return entry;
  }

  static Future<({String url, int expires})?> fetchFileUrl(
    Api api, {
    required int accountId,
    required int fileId,
    required int chatId,
    required String messageId,
  }) async {
    try {
      final packet = await api.sendRequest(Opcode.fileDownload, {
        'fileId': fileId,
        'chatId': chatId,
        'messageId': int.tryParse(messageId) ?? messageId,
      });
      if (!packet.isOk) return null;
      final data = packet.payload;
      if (data is! Map) return null;
      final url = data['url'] as String?;
      if (url == null) return null;
      final uri = Uri.tryParse(url);
      final expiresStr = uri?.queryParameters['expires'];
      final expires = int.tryParse(expiresStr ?? '') ?? 0;
      final entry = (url: url, expires: expires);
      _linkCache['$accountId:$fileId'] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }
}
