import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../../core/config/komet_settings.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/text_format.dart';
import '../../models/attachment.dart';
import 'chats.dart' show chats;

class ContactCache {
  static final Map<int, String> _nameCache = {};
  static final Map<int, String> _avatarCache = {};
  static final Map<int, Set<String>> _optionsCache = {};

  static const _prefsKey = 'contact_cache_v1';
  static Timer? _saveTimer;
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id == null || value is! Map) return;
        final name = value['n'];
        final avatar = value['a'];
        final opts = value['o'];
        if (name is String) _nameCache[id] = name;
        if (avatar is String) _avatarCache[id] = avatar;
        if (opts is List) _optionsCache[id] = opts.whereType<String>().toSet();
      });
    } catch (_) {}
  }

  static void put(int id, String name) {
    _nameCache[id] = name;
    _scheduleSave();
  }

  static void putAvatar(int id, String? baseUrl) {
    if (baseUrl != null) {
      _avatarCache[id] = baseUrl;
      _scheduleSave();
    }
  }

  static void putOptions(int id, Set<String> opts) {
    _optionsCache[id] = opts;
    _scheduleSave();
  }

  static String? get(int id) => _nameCache[id];
  static String? getAvatar(int id) => _avatarCache[id];
  static Set<String>? getOptions(int id) => _optionsCache[id];
  static bool isOfficial(int id) =>
      _optionsCache[id]?.contains('OFFICIAL') ?? false;

  static void clear() {
    _nameCache.clear();
    _avatarCache.clear();
    _optionsCache.clear();
    _saveTimer?.cancel();
    _saveTimer = null;
    unawaited(_wipePersisted());
  }

  static void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 3), () => unawaited(_save()));
  }

  static Future<void> _save() async {
    final ids = <int>{
      ..._nameCache.keys,
      ..._avatarCache.keys,
      ..._optionsCache.keys,
    };
    final map = <String, dynamic>{};
    for (final id in ids) {
      final entry = <String, dynamic>{};
      final name = _nameCache[id];
      final avatar = _avatarCache[id];
      final opts = _optionsCache[id];
      if (name != null) entry['n'] = name;
      if (avatar != null) entry['a'] = avatar;
      if (opts != null && opts.isNotEmpty) entry['o'] = opts.toList();
      if (entry.isNotEmpty) map['$id'] = entry;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(map));
  }

  static Future<void> _wipePersisted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

class TranscriptionResult {
  final int status;
  final String? text;
  final String? messageId;
  final int? chatId;
  final int? mediaId;

  TranscriptionResult({
    required this.status,
    this.text,
    this.messageId,
    this.chatId,
    this.mediaId,
  });
}

class TranscriptionCache {
  static final Map<String, TranscriptionResult> _cache = {};

  static void put(String messageId, TranscriptionResult result) {
    _cache[messageId] = result;
  }

  static TranscriptionResult? get(String messageId) => _cache[messageId];

  static bool has(String messageId) => _cache.containsKey(messageId);

  static void clear() => _cache.clear();
}

class FileHistoryEntry {
  final int fileId;
  final String? url;
  final String? token;
  final String? filename;
  final int? size;
  final DateTime sentAt;

  FileHistoryEntry({
    required this.fileId,
    this.url,
    this.token,
    this.filename,
    this.size,
    required this.sentAt,
  });

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    if (url != null) 'url': url,
    if (token != null) 'token': token,
    if (filename != null) 'filename': filename,
    if (size != null) 'size': size,
    'sentAt': sentAt.millisecondsSinceEpoch,
  };

  static FileHistoryEntry? fromJson(Map<String, dynamic> j) {
    final id = j['fileId'];
    final ts = j['sentAt'];
    if (id is! int || ts is! int) return null;
    return FileHistoryEntry(
      fileId: id,
      url: j['url'] as String?,
      token: j['token'] as String?,
      filename: j['filename'] as String?,
      size: j['size'] as int?,
      sentAt: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }
}

class FileHistoryCache {
  static const _prefKey = 'file_history_v1';
  static const _maxEntries = 50;

  static final ValueNotifier<List<FileHistoryEntry>> notifier = ValueNotifier(
    const [],
  );

  static List<FileHistoryEntry> get history => notifier.value;
  static bool get isEmpty => notifier.value.isEmpty;

  static SharedPreferences? _prefs;

  static Future<void> load(SharedPreferences prefs) async {
    _prefs = prefs;
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw);
      if (list is! List) return;
      final entries = <FileHistoryEntry>[];
      for (final e in list) {
        if (e is Map) {
          final entry = FileHistoryEntry.fromJson(Map<String, dynamic>.from(e));
          if (entry != null) entries.add(entry);
        }
      }
      notifier.value = entries;
    } catch (_) {}
  }

  static void add(FileHistoryEntry entry) {
    final next = [
      entry,
      ...notifier.value.where((e) => e.fileId != entry.fileId),
    ];
    if (next.length > _maxEntries) next.removeRange(_maxEntries, next.length);
    notifier.value = next;
    _persist();
  }

  static void remove(int fileId) {
    final next = notifier.value.where((e) => e.fileId != fileId).toList();
    if (next.length == notifier.value.length) return;
    notifier.value = next;
    _persist();
  }

  static void _persist() {
    final prefs = _prefs;
    if (prefs == null) return;
    final encoded = jsonEncode(notifier.value.map((e) => e.toJson()).toList());
    prefs.setString(_prefKey, encoded);
  }
}

class FileUploadInfo {
  final String url;
  final int fileId;
  final String token;

  FileUploadInfo({
    required this.url,
    required this.fileId,
    required this.token,
  });
}

class VideoUploadInfo {
  final String url;
  final int videoId;
  final String token;

  VideoUploadInfo({
    required this.url,
    required this.videoId,
    required this.token,
  });
}

class ReplyInfo {
  final String? messageId;
  final int senderId;
  final String? text;
  final int? time;
  final List<MessageAttachment>? attachments;

  const ReplyInfo({
    this.messageId,
    required this.senderId,
    this.text,
    this.time,
    this.attachments,
  });

  static ReplyInfo? fromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final link = payload['link'];
    if (link is! Map) return null;
    if ((link['type'] as String?)?.toUpperCase() != 'REPLY') return null;

    final msg = link['message'];
    if (msg is! Map) {
      final mid = link['messageId'];
      if (mid == null) return null;
      return ReplyInfo(messageId: mid.toString(), senderId: 0);
    }

    List<MessageAttachment>? attaches;
    final raw = msg['attaches'];
    if (raw is List && raw.isNotEmpty) {
      attaches = raw
          .whereType<Map>()
          .map((a) => MessageAttachment.fromMap(Map<String, dynamic>.from(a)))
          .toList();
    }

    final sender = msg['sender'];
    return ReplyInfo(
      messageId: msg['id']?.toString(),
      senderId: sender is int
          ? sender
          : int.tryParse(sender?.toString() ?? '') ?? 0,
      text: msg['text']?.toString(),
      time: msg['time'] is int ? msg['time'] as int : null,
      attachments: attaches,
    );
  }

  String previewText() {
    final t = text;
    if (t != null && t.trim().isNotEmpty) return t;
    final a = attachments;
    if (a != null && a.isNotEmpty) {
      switch (a.first.type) {
        case AttachmentType.photo:
          return 'Фото';
        case AttachmentType.video:
          return 'Видео';
        case AttachmentType.audio:
          return 'Голосовое сообщение';
        case AttachmentType.file:
          return 'Файл';
        case AttachmentType.sticker:
          return 'Стикер';
        case AttachmentType.contact:
          return 'Контакт';
        case AttachmentType.location:
          return 'Геолокация';
        case AttachmentType.poll:
          return 'Опрос';
        case AttachmentType.call:
          return 'Звонок';
        case AttachmentType.share:
          return 'Ссылка';
        case AttachmentType.control:
          return '';
        case AttachmentType.inlineKeyboard:
          return '';
        case AttachmentType.forward:
          return 'Переслано';
        case AttachmentType.unknown:
          return 'Вложение';
      }
    }
    return '';
  }
}

class AudioUploadInfo {
  final String url;
  final int audioId;
  final String token;

  AudioUploadInfo({
    required this.url,
    required this.audioId,
    required this.token,
  });
}

class CachedMessage {
  final String id;
  final int accountId;
  final int chatId;
  final int senderId;
  final String? text;
  final int time;
  final String? status;
  final Map<String, dynamic>? payload;
  final List<MessageAttachment>? attachments;
  final bool isControl;
  final bool deleted;
  final List<Map<String, dynamic>>? editHistory;

  const CachedMessage({
    required this.id,
    required this.accountId,
    required this.chatId,
    required this.senderId,
    this.text,
    required this.time,
    this.status,
    this.payload,
    this.attachments,
    this.isControl = false,
    this.deleted = false,
    this.editHistory,
  });

  CachedMessage copyWith({
    String? status,
    bool? deleted,
    List<MessageAttachment>? attachments,
    List<Map<String, dynamic>>? editHistory,
    Map<String, dynamic>? payload,
  }) => CachedMessage(
    id: id,
    accountId: accountId,
    chatId: chatId,
    senderId: senderId,
    text: text,
    time: time,
    status: status ?? this.status,
    payload: payload ?? this.payload,
    attachments: attachments ?? this.attachments,
    isControl: isControl,
    deleted: deleted ?? this.deleted,
    editHistory: editHistory ?? this.editHistory,
  );

  static List<Map<String, dynamic>>? parseEditHistory(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return list.isEmpty ? null : list;
      }
    } catch (_) {}
    return null;
  }

  static List<Map<String, dynamic>> appendEditHistory(
    List<Map<String, dynamic>>? current,
    String? oldText,
    int time,
  ) {
    final list = current != null
        ? List<Map<String, dynamic>>.from(current)
        : <Map<String, dynamic>>[];
    if (list.isNotEmpty && (list.last['text'] as String?) == oldText) {
      return list;
    }
    list.add({'text': oldText, 'time': time});
    return list;
  }

  static (List<MessageAttachment>?, bool) parseAttachments(
    Map<String, dynamic> map,
  ) {
    List<MessageAttachment>? attachments;
    final link = map['link'];
    final linkType = link is Map ? link['type'] as String? : null;
    if (linkType == 'FORWARD') {
      attachments = [ForwardedMessageAttachment.fromMap(map)];
    } else {
      final attaches = map['attaches'] as List?;
      if (attaches != null) {
        attachments = attaches
            .whereType<Map>()
            .map((a) => MessageAttachment.fromMap(Map<String, dynamic>.from(a)))
            .toList();
      }
    }
    final isControl =
        attachments?.any((a) => a.type == AttachmentType.control) ?? false;
    return (attachments, isControl);
  }

  factory CachedMessage.fromDbRow(Map<String, dynamic> row) {
    Map<String, dynamic>? payload;
    final payloadRaw = row['payload'];
    if (payloadRaw is String && payloadRaw.isNotEmpty) {
      try {
        payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      } catch (_) {}
    }

    List<MessageAttachment>? attachments;
    bool isControl = false;
    if (payload != null) {
      final parsed = parseAttachments(payload);
      attachments = parsed.$1;
      isControl = parsed.$2;
    }

    return CachedMessage(
      id: row['id']?.toString() ?? '',
      accountId: row['account_id'] is int
          ? row['account_id'] as int
          : int.tryParse(row['account_id']?.toString() ?? '') ?? 0,
      chatId: row['chat_id'] is int
          ? row['chat_id'] as int
          : int.tryParse(row['chat_id']?.toString() ?? '') ?? 0,
      senderId: row['sender_id'] is int
          ? row['sender_id'] as int
          : int.tryParse(row['sender_id']?.toString() ?? '') ?? 0,
      text: row['text']?.toString(),
      time: row['time'] is int
          ? row['time'] as int
          : int.tryParse(row['time']?.toString() ?? '') ?? 0,
      status: row['status']?.toString(),
      payload: payload,
      attachments: attachments,
      isControl: isControl,
      deleted: row['deleted'] is int
          ? row['deleted'] == 1
          : row['deleted']?.toString() == '1',
      editHistory: parseEditHistory(row['edit_history']),
    );
  }

  int? get delayedTimeToFire {
    final attrs = payload?['delayedAttributes'];
    if (attrs is Map) {
      final t = attrs['timeToFire'];
      if (t is int) return t;
      if (t is String) return int.tryParse(t);
    }
    return null;
  }

  bool get isDelayed => delayedTimeToFire != null;

  ReplyInfo? get replyInfo => ReplyInfo.fromPayload(payload);

  List<FormatRange> get formatRanges =>
      parseFormatElements(payload?['elements']);

  static List<CachedMessage> _decodeRows(List<Map<String, dynamic>> rows) =>
      rows.map(CachedMessage.fromDbRow).toList();

  static Future<List<CachedMessage>> fromDbRowsAsync(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.length < 20) {
      return Future.value(_decodeRows(rows));
    }
    return compute(_decodeRows, rows);
  }

  Map<String, dynamic> toDbRow() => {
    'id': id,
    'account_id': accountId,
    'chat_id': chatId,
    'sender_id': senderId,
    'text': text,
    'time': time,
    'status': status,
    'payload': payload != null ? jsonEncode(payload) : null,
    'deleted': deleted ? 1 : 0,
    'edit_history': editHistory != null ? jsonEncode(editHistory) : null,
  };

  static CachedMessage fromPushPayload(int accountId, int chatId, Map msg) {
    final full = Map<String, dynamic>.from(msg);
    final parsed = parseAttachments(full);
    return CachedMessage(
      id: msg['id']?.toString() ?? '',
      accountId: accountId,
      chatId: chatId,
      senderId: msg['sender'] as int? ?? 0,
      text: msg['text'] as String?,
      time: (msg['time'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      status: (msg['status'] as String?) ?? 'sent',
      payload: full,
      attachments: parsed.$1,
      isControl: parsed.$2,
    );
  }
}

class MessagesModule {
  final Api _api;

  MessagesModule(this._api);

  Future<List<CachedMessage>> fetchHistory(
    int accountId,
    int chatId, {
    int? fromTime,
    int count = 50,
    int forward = 0,
    int? backward,
  }) async {
    final payload = {
      'chatId': chatId,
      'from': fromTime ?? (DateTime.now().millisecondsSinceEpoch + 86400000),
      'forward': forward,
      'backward': backward ?? count,
      'getMessages': true,
    };

    final response = await _api.sendRequest(Opcode.chatHistory, payload);

    if (!response.isOk) return [];

    final data = response.payload;
    if (data is! Map) return [];

    final messagesData = data['messages'];
    if (messagesData is! List) return [];

    final List<CachedMessage> results = [];

    for (var i = 0; i < messagesData.length; i++) {
      final m = messagesData[i];
      if (m is! Map) continue;

      final msg = _parseMessage(m.cast<dynamic, dynamic>(), accountId, chatId);
      if (msg != null) {
        results.add(msg);
      }

      if (i > 0 && i % 20 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    final toSave = KometSettings.viewRedacted.value && results.isNotEmpty
        ? await _mergeEditHistory(accountId, chatId, results)
        : results;

    if (toSave.isNotEmpty) {
      try {
        await AppDatabase.saveMessages(toSave.map((m) => m.toDbRow()).toList());
      } catch (e) {
        logger.e('saveMessages error: $e');
      }
    }

    return toSave;
  }

  Future<List<Map<String, dynamic>>> searchMessages(
    int chatId,
    String query, {
    int count = 30,
  }) async {
    final response = await _api.sendRequest(Opcode.msgSearch, {
      'chatId': chatId,
      'query': query,
      'count': count,
    });

    if (!response.isOk) return const [];

    final data = response.payload;
    if (data is! Map) return const [];

    final result = data['result'];
    if (result is! List) return const [];

    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast()))
        .toList();
  }

  Future<List<CachedMessage>> _mergeEditHistory(
    int accountId,
    int chatId,
    List<CachedMessage> serverMessages,
  ) async {
    final cachedRows = await AppDatabase.loadMessagesByIds(
      accountId,
      chatId,
      serverMessages.map((m) => m.id).toList(),
    );
    final byId = <String, Map<String, dynamic>>{};
    for (final row in cachedRows) {
      final id = row['id']?.toString();
      if (id != null) byId[id] = row;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <CachedMessage>[];
    for (final msg in serverMessages) {
      final existing = byId[msg.id];
      if (existing == null) {
        out.add(msg);
        continue;
      }
      var history = CachedMessage.parseEditHistory(existing['edit_history']);
      final oldText = existing['text']?.toString();
      if ((oldText ?? '') != (msg.text ?? '') &&
          oldText != null &&
          oldText.isNotEmpty) {
        history = CachedMessage.appendEditHistory(history, oldText, now);
      }
      out.add(history == null ? msg : msg.copyWith(editHistory: history));
    }
    return out;
  }

  Future<List<CachedMessage>> getLocalHistory(
    int accountId,
    int chatId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await AppDatabase.loadMessages(
      accountId,
      chatId,
      limit: limit,
      offset: offset,
    );
    return CachedMessage.fromDbRowsAsync(rows);
  }

  CachedMessage? _parseMessage(
    Map<dynamic, dynamic> m,
    int accountId,
    int chatId,
  ) {
    final id = m['id']?.toString();
    if (id == null) return null;

    final full = Map<String, dynamic>.from(m.cast());
    final parsed = CachedMessage.parseAttachments(full);

    return CachedMessage(
      id: id,
      accountId: accountId,
      chatId: chatId,
      senderId: _parseIntField(m['sender']),
      text: m['text']?.toString(),
      time: _parseIntField(m['time']),
      status: m['status']?.toString(),
      payload: full,
      attachments: parsed.$1,
      isControl: parsed.$2,
    );
  }

  int _parseIntField(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<String> sendMessage(
    int accountId,
    int chatId,
    String text, {
    bool notify = true,
    int? scheduledTime,
    int? replyToMessageId,
    List<Map<String, dynamic>> elements = const [],
  }) async {
    final message = <String, dynamic>{
      'text': text,
      'cid': DateTime.now().millisecondsSinceEpoch * -1,
      'elements': elements,
      'attaches': [],
    };
    if (replyToMessageId != null) {
      message['link'] = {
        'type': 'REPLY',
        'chatId': chatId,
        'messageId': replyToMessageId,
      };
    }
    if (scheduledTime != null) {
      message['delayedAttributes'] = {
        'timeToFire': scheduledTime,
        'notifySender': true,
      };
    }
    final payload = {'chatId': chatId, 'message': message, 'notify': notify};

    return _sendAndExtractMessageId(payload, 'Ошибка отправки');
  }

  Future<String> _sendAndExtractMessageId(
    Map<String, dynamic> payload,
    String defaultError,
  ) async {
    final response = await _api.sendRequest(Opcode.msgSend, payload);
    if (!response.isOk) {
      _throwSendError(response.payload, defaultError);
    }
    final data = response.payload;
    if (data is Map) {
      final msgMap = data['message'];
      if (msgMap is Map) {
        final id = msgMap['id'];
        if (id != null) return id.toString();
      }
    }
    return '';
  }

  Never _throwSendError(dynamic payload, String fallback) {
    final msg = (payload is Map)
        ? (payload['localizedMessage'] ?? payload['message'] ?? fallback)
        : fallback;
    throw Exception(msg.toString());
  }

  Map<String, dynamic>? _sentMessageMap(Packet response) {
    if (!response.isOk) return null;
    final data = response.payload;
    if (data is Map) {
      final msg = data['message'];
      if (msg is Map) return Map<String, dynamic>.from(msg);
    }
    return null;
  }

  Future<T> _sendWithNotReadyRetry<T>({
    required Map<String, dynamic> payload,
    required int maxAttempts,
    required Duration retryDelay,
    required T Function(Packet response) onResult,
    required T onExhausted,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _api.sendRequest(Opcode.msgSend, payload);
        return onResult(response);
      } on PacketError catch (e) {
        if (!(e.errorKey?.contains('not.ready') ?? false)) {
          logger.w('msgSend rejected: key=${e.errorKey} msg=${e.message}');
          rethrow;
        }
        if (attempt == maxAttempts - 1) return onExhausted;
        await Future.delayed(retryDelay);
      }
    }
    return onExhausted;
  }

  Future<String> forwardMessage(
    int targetChatId,
    int sourceChatId,
    int messageId, {
    bool notify = true,
  }) async {
    final message = <String, dynamic>{
      'isLive': false,
      'detectShare': false,
      'elements': [],
      'attaches': [],
      'cid': DateTime.now().millisecondsSinceEpoch * -1,
      'link': {
        'type': 'FORWARD',
        'chatId': sourceChatId,
        'messageId': messageId,
      },
    };
    final payload = {
      'chatId': targetChatId,
      'message': message,
      'notify': notify,
    };

    return _sendAndExtractMessageId(payload, 'Ошибка пересылки');
  }

  static CachedMessage buildForwardMessage({
    required int myId,
    required int targetChatId,
    required int sourceChatId,
    required CachedMessage source,
    required String tempId,
    required int time,
    required String status,
  }) {
    final srcPayload = source.payload;
    final srcLink = srcPayload?['link'];
    Map<String, dynamic> originalMsg;
    if (srcLink is Map &&
        srcLink['type'] == 'FORWARD' &&
        srcLink['message'] is Map) {
      originalMsg = Map<String, dynamic>.from(srcLink['message'] as Map);
    } else {
      originalMsg = {
        'id': int.tryParse(source.id) ?? source.id,
        'sender': source.senderId,
        'time': source.time,
        'text': source.text,
        'attaches': (srcPayload?['attaches'] as List?) ?? const [],
      };
    }
    final payload = <String, dynamic>{
      'elements': const [],
      'attaches': const [],
      'link': {
        'type': 'FORWARD',
        'chatId': sourceChatId,
        'messageId': int.tryParse(source.id) ?? source.id,
        'message': originalMsg,
      },
    };
    return CachedMessage(
      id: tempId,
      accountId: myId,
      chatId: targetChatId,
      senderId: myId,
      text: null,
      time: time,
      status: status,
      payload: payload,
      attachments: [ForwardedMessageAttachment.fromMap(payload)],
    );
  }

  static CachedMessage reidentifyMessage(
    CachedMessage message,
    String newId, {
    String? status,
  }) => CachedMessage(
    id: newId,
    accountId: message.accountId,
    chatId: message.chatId,
    senderId: message.senderId,
    text: message.text,
    time: message.time,
    status: status ?? message.status,
    payload: message.payload,
    attachments: message.attachments,
    isControl: message.isControl,
    deleted: message.deleted,
    editHistory: message.editHistory,
  );

  static String forwardPreviewText(CachedMessage message) {
    final link = message.payload?['link'];
    if (link is Map && link['message'] is Map) {
      final original = link['message'] as Map;
      final text = original['text'];
      if (text is String && text.trim().isNotEmpty) return text;
    }
    return 'Пересланное сообщение';
  }

  Future<bool> sendLinkMessage(int chatId, String url) async {
    final message = <String, dynamic>{
      'text': url,
      'cid': DateTime.now().millisecondsSinceEpoch * -1,
      'elements': [
        {
          'type': 'LINK',
          'from': 0,
          'length': url.length,
          'attributes': {'url': url},
        },
      ],
      'attaches': [],
    };
    return _api.sendRequestOk(Opcode.msgSend, {
      'chatId': chatId,
      'message': message,
      'notify': true,
    });
  }

  Future<List<CachedMessage>> fetchDelayedMessages(
    int accountId,
    int chatId,
  ) async {
    final payload = {
      'chatId': chatId,
      'forward': 0,
      'backwardTime': 0,
      'getChat': false,
      'from': 1,
      'itemType': 'DELAYED',
      'getMessages': true,
      'forwardTime': 0,
      'interactive': true,
      'backward': 150,
    };

    final response = await _api.sendRequest(Opcode.chatHistory, payload);
    if (!response.isOk) return [];

    final data = response.payload;
    if (data is! Map) return [];

    final messagesData = data['messages'];
    if (messagesData is! List) return [];

    final results = <CachedMessage>[];
    for (final m in messagesData) {
      if (m is! Map) continue;
      final msg = _parseMessage(m.cast<dynamic, dynamic>(), accountId, chatId);
      if (msg != null) results.add(msg);
    }

    results.sort(
      (a, b) => (a.delayedTimeToFire ?? a.time).compareTo(
        b.delayedTimeToFire ?? b.time,
      ),
    );

    return results;
  }

  Future<bool> editMessage(
    int chatId,
    String messageId, {
    required String text,
    List<Map<String, dynamic>> elements = const [],
    bool sendAttachments = false,
  }) async {
    final id = int.tryParse(messageId);
    if (id == null) return false;

    final payload = <String, dynamic>{
      'messageId': id,
      'chatId': chatId,
      'elements': elements,
      'text': text,
    };
    if (sendAttachments) payload['attachments'] = const <dynamic>[];

    return _api.sendRequestOk(Opcode.msgEdit, payload);
  }

  Future<bool> editScheduledMessage(
    int chatId,
    String messageId, {
    required String text,
    required int timeToFire,
  }) async {
    final id = int.tryParse(messageId);
    if (id == null) return false;

    final payload = {
      'messageId': id,
      'chatId': chatId,
      'elements': <dynamic>[],
      'text': text,
      'delayedAttributes': {'timeToFire': timeToFire, 'notifySender': true},
    };

    return _api.sendRequestOk(Opcode.msgEdit, payload);
  }

  Future<bool> deleteMessages(
    int chatId,
    List<String> messageIds, {
    bool forEveryone = false,
    String itemType = 'REGULAR',
  }) async {
    final ids = messageIds
        .map((id) => int.tryParse(id))
        .whereType<int>()
        .toList();
    if (ids.isEmpty) return false;

    final payload = {
      'messageIds': ids,
      'chatId': chatId,
      'forMe': !forEveryone,
      'itemType': itemType,
    };

    return _api.sendRequestOk(Opcode.msgDelete, payload);
  }

  Future<({bool ok, Map<String, dynamic>? info})> setReaction(
    int chatId,
    String messageId,
    String emoji,
  ) async {
    final id = int.tryParse(messageId);
    if (id == null) return (ok: false, info: null);
    final response = await _api.sendRequest(Opcode.msgReaction, {
      'chatId': chatId,
      'messageId': id,
      'reaction': {'reactionType': 'EMOJI', 'id': emoji},
    });
    return _applyReactionResponse(chatId, messageId, response);
  }

  Future<({bool ok, Map<String, dynamic>? info})> cancelReaction(
    int chatId,
    String messageId,
  ) async {
    final id = int.tryParse(messageId);
    if (id == null) return (ok: false, info: null);
    final response = await _api.sendRequest(Opcode.msgCancelReaction, {
      'chatId': chatId,
      'messageId': id,
    });
    return _applyReactionResponse(chatId, messageId, response);
  }

  Future<({bool ok, Map<String, dynamic>? info})> _applyReactionResponse(
    int chatId,
    String messageId,
    Packet response,
  ) async {
    if (!response.isOk) return (ok: false, info: null);
    final payload = response.payload;
    final info = payload is Map
        ? _normalizeReactionInfo(payload['reactionInfo'])
        : null;
    try {
      await _persistReaction(chatId, messageId, info);
    } catch (_) {}
    return (ok: true, info: info);
  }

  static Map<String, dynamic>? _normalizeReactionInfo(dynamic raw) {
    if (raw is! Map) return null;
    final rawCounters = raw['counters'];
    if (rawCounters is! List) return null;
    final counters = <Map<String, dynamic>>[];
    for (final c in rawCounters) {
      if (c is! Map) continue;
      final reaction = c['reaction']?.toString();
      if (reaction == null || reaction.isEmpty) continue;
      final count = c['count'];
      counters.add({'reaction': reaction, 'count': count is int ? count : 0});
    }
    if (counters.isEmpty) return null;
    final your = raw['yourReaction']?.toString();
    final total = raw['totalCount'];
    return {
      'counters': counters,
      if (your != null && your.isNotEmpty) 'yourReaction': your,
      'totalCount': total is int
          ? total
          : counters.fold<int>(0, (a, b) => a + (b['count'] as int)),
    };
  }

  Future<void> _persistReaction(
    int chatId,
    String messageId,
    Map<String, dynamic>? info,
  ) async {
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null) return;
    final existing = await AppDatabase.loadMessage(accountId, chatId, messageId);
    if (existing == null) return;

    Map<String, dynamic> payloadMap;
    final raw = existing['payload'];
    if (raw is String && raw.isNotEmpty) {
      try {
        payloadMap = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        payloadMap = <String, dynamic>{};
      }
    } else {
      payloadMap = <String, dynamic>{};
    }

    if (info == null) {
      payloadMap.remove('reactionInfo');
    } else {
      payloadMap['reactionInfo'] = info;
    }

    final newRow = Map<String, dynamic>.from(existing);
    newRow['payload'] = jsonEncode(payloadMap);
    await AppDatabase.saveMessages([newRow]);
  }

  Future<Map<String, dynamic>?> sendButtonCallback({
    required int chatId,
    required String messageId,
    required String callbackId,
    String? payload,
  }) async {
    final mid = int.tryParse(messageId);
    if (mid == null) return null;

    final request = {
      'chatId': chatId,
      'messageId': mid,
      'callbackId': callbackId,
      'payload': ?payload,
    };

    final response = await _api.sendRequest(Opcode.msgSendCallback, request);
    if (!response.isOk) return null;
    final data = response.payload;
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  Future<TranscriptionResult> requestTranscription(
    int chatId,
    int messageId,
    int mediaId,
  ) async {
    final payload = {
      'chatId': chatId,
      'messageId': messageId,
      'mediaId': mediaId,
    };

    final response = await _api.sendRequest(Opcode.audioTranscription, payload);
    if (!response.isOk) return TranscriptionResult(status: -1);

    final data = response.payload;
    if (data is! Map) return TranscriptionResult(status: -1);

    final transcriptionStatus = data['transcriptionStatus'] as int? ?? -1;
    if (transcriptionStatus == 1) {
      final text = data['transcription'] as String? ?? '';
      if (text.isEmpty) {
        return TranscriptionResult(
          status: 1,
          text: 'не удалось распознать текст',
        );
      }
      return TranscriptionResult(status: 1, text: text);
    }

    return TranscriptionResult(status: transcriptionStatus);
  }

  Future<FileUploadInfo?> requestUploadUrl({int count = 1}) async {
    final payload = {'count': count};
    final response = await _api.sendRequest(Opcode.fileUpload, payload);
    if (!response.isOk) return null;

    final data = response.payload;
    if (data is! Map) return null;

    final infoList = data['info'] as List?;
    if (infoList == null || infoList.isEmpty) return null;

    final info = infoList.first;
    if (info is! Map) return null;

    return FileUploadInfo(
      url: info['url'] as String? ?? '',
      fileId: info['fileId'] as int? ?? 0,
      token: info['token'] as String? ?? '',
    );
  }

  Future<bool> sendFileMessage(
    int chatId,
    int fileId, {
    String? token,
    bool notify = true,
    int? scheduledTime,
    int maxAttempts = 20,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    final message = <String, dynamic>{
      'isLive': false,
      'detectShare': false,
      'elements': <dynamic>[],
      'cid': DateTime.now().millisecondsSinceEpoch,
      'attaches': [
        if (token != null)
          {'_type': 'FILE', 'token': token}
        else
          {'_type': 'FILE', 'fileId': fileId},
      ],
    };
    if (scheduledTime != null) {
      message['delayedAttributes'] = {
        'timeToFire': scheduledTime,
        'notifySender': true,
      };
    }
    final payload = {'chatId': chatId, 'message': message, 'notify': notify};

    return _sendWithNotReadyRetry<bool>(
      payload: payload,
      maxAttempts: maxAttempts,
      retryDelay: retryDelay,
      onResult: (response) => response.isOk,
      onExhausted: false,
    );
  }

  Future<String?> requestPhotoUploadUrl() async {
    final response = await _api.sendRequest(Opcode.photoUpload, {'count': 1});
    if (!response.isOk) return null;
    final data = response.payload;
    if (data is! Map) return null;
    return data['url'] as String?;
  }

  Future<Map<String, dynamic>?> sendPhotoMessage(
    int chatId,
    List<String> photoTokens, {
    String? caption,
    bool notify = true,
    int? scheduledTime,
    int maxAttempts = 20,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    final message = <String, dynamic>{
      'cid': DateTime.now().millisecondsSinceEpoch * -1,
      'attaches': [
        for (final token in photoTokens)
          {'_type': 'PHOTO', 'photoToken': token},
      ],
    };
    if (caption != null && caption.isNotEmpty) message['text'] = caption;
    if (scheduledTime != null) {
      message['delayedAttributes'] = {
        'timeToFire': scheduledTime,
        'notifySender': true,
      };
    }
    final payload = {'chatId': chatId, 'message': message, 'notify': notify};

    return _sendWithNotReadyRetry<Map<String, dynamic>?>(
      payload: payload,
      maxAttempts: maxAttempts,
      retryDelay: retryDelay,
      onResult: _sentMessageMap,
      onExhausted: null,
    );
  }

  Future<VideoUploadInfo?> requestVideoUploadUrl() async {
    final response = await _api.sendRequest(Opcode.videoUpload, {
      'uploaderType': 0,
      'type': 0,
      'count': 1,
    });
    if (!response.isOk) return null;

    final data = response.payload;
    if (data is! Map) return null;

    final infoList = data['info'] as List?;
    if (infoList == null || infoList.isEmpty) return null;

    final info = infoList.first;
    if (info is! Map) return null;

    return VideoUploadInfo(
      url: info['url'] as String? ?? '',
      videoId: info['videoId'] as int? ?? 0,
      token: info['token'] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>?> sendVideoMessage(
    int chatId,
    String token, {
    String? caption,
    bool notify = true,
    int? scheduledTime,
    int maxAttempts = 30,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    final message = <String, dynamic>{
      'isLive': false,
      'detectShare': false,
      'elements': <dynamic>[],
      'cid': DateTime.now().millisecondsSinceEpoch * -1,
      'attaches': [
        {'videoType': 0, '_type': 'VIDEO', 'token': token},
      ],
    };
    if (caption != null && caption.isNotEmpty) message['text'] = caption;
    if (scheduledTime != null) {
      message['delayedAttributes'] = {
        'timeToFire': scheduledTime,
        'notifySender': true,
      };
    }
    final payload = {'chatId': chatId, 'message': message, 'notify': notify};

    return _sendWithNotReadyRetry<Map<String, dynamic>?>(
      payload: payload,
      maxAttempts: maxAttempts,
      retryDelay: retryDelay,
      onResult: _sentMessageMap,
      onExhausted: null,
    );
  }

  Future<AudioUploadInfo?> requestAudioUploadUrl() async {
    final response = await _api.sendRequest(Opcode.videoUpload, {
      'uploaderType': 1,
      'type': 2,
      'count': 1,
    });
    if (!response.isOk) return null;

    final data = response.payload;
    if (data is! Map) return null;

    final infoList = data['info'] as List?;
    if (infoList == null || infoList.isEmpty) return null;

    final info = infoList.first;
    if (info is! Map) return null;

    return AudioUploadInfo(
      url: info['url'] as String? ?? '',
      audioId: info['videoId'] as int? ?? 0,
      token: info['token'] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>?> sendAudioMessage(
    int chatId,
    String token, {
    required int duration,
    Uint8List? wave,
    bool notify = true,
    int? scheduledTime,
    int maxAttempts = 30,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    final message = <String, dynamic>{
      'isLive': false,
      'detectShare': false,
      'elements': <dynamic>[],
      'cid': DateTime.now().millisecondsSinceEpoch * -1,
      'attaches': [
        {
          'duration': duration,
          '_type': 'AUDIO',
          'wave': (wave != null && wave.isNotEmpty) ? wave : Uint8List(80),
          'token': token,
        },
      ],
    };
    if (scheduledTime != null) {
      message['delayedAttributes'] = {
        'timeToFire': scheduledTime,
        'notifySender': true,
      };
    }
    final payload = {'chatId': chatId, 'message': message, 'notify': notify};

    return _sendWithNotReadyRetry<Map<String, dynamic>?>(
      payload: payload,
      maxAttempts: maxAttempts,
      retryDelay: retryDelay,
      onResult: _sentMessageMap,
      onExhausted: null,
    );
  }

  Future<VideoUploadInfo?> requestVideoNoteUploadUrl() async {
    final response = await _api.sendRequest(Opcode.videoUpload, {
      'uploaderType': 1,
      'type': 1,
      'count': 1,
    });
    if (!response.isOk) return null;

    final data = response.payload;
    if (data is! Map) return null;

    final infoList = data['info'] as List?;
    if (infoList == null || infoList.isEmpty) return null;

    final info = infoList.first;
    if (info is! Map) return null;

    return VideoUploadInfo(
      url: info['url'] as String? ?? '',
      videoId: info['videoId'] as int? ?? 0,
      token: info['token'] as String? ?? '',
    );
  }

  Future<Map<String, dynamic>?> sendVideoNoteMessage(
    int chatId,
    String token, {
    required int duration,
    Uint8List? wave,
    String? thumbhash,
    bool notify = true,
    int maxAttempts = 30,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    final message = <String, dynamic>{
      'isLive': false,
      'detectShare': false,
      'elements': <dynamic>[],
      'cid': DateTime.now().millisecondsSinceEpoch * -1,
      'attaches': [
        {
          'duration': duration,
          'videoType': 1,
          '_type': 'VIDEO',
          'wave': (wave != null && wave.isNotEmpty) ? wave : Uint8List(80),
          'token': token,
          if (thumbhash != null && thumbhash.isNotEmpty) 'thumbhash': thumbhash,
        },
      ],
    };
    final payload = {'chatId': chatId, 'message': message, 'notify': notify};

    return _sendWithNotReadyRetry<Map<String, dynamic>?>(
      payload: payload,
      maxAttempts: maxAttempts,
      retryDelay: retryDelay,
      onResult: _sentMessageMap,
      onExhausted: null,
    );
  }

  Future<Map<String, dynamic>?> sendLocationMessage(
    int chatId,
    double latitude,
    double longitude, {
    double zoom = 15,
    bool notify = true,
  }) async {
    final payload = {
      'chatId': chatId,
      'message': {
        'cid': DateTime.now().millisecondsSinceEpoch * -1,
        'attaches': [
          {
            '_type': 'LOCATION',
            'latitude': latitude,
            'longitude': longitude,
            'zoom': zoom,
          },
        ],
      },
      'notify': notify,
    };

    final response = await _api.sendRequest(Opcode.msgSend, payload);
    return _sentMessageMap(response);
  }

  static const int _pollAnonymousFlag = 4;
  static const int _pollMultipleFlag = 1;

  Future<Map<String, dynamic>?> sendPollMessage(
    int chatId,
    String title,
    List<String> answers, {
    bool multiple = false,
    bool anonymous = true,
    bool notify = true,
  }) async {
    final settings =
        (anonymous ? _pollAnonymousFlag : 0) |
        (multiple ? _pollMultipleFlag : 0);
    final payload = {
      'chatId': chatId,
      'message': {
        'cid': DateTime.now().millisecondsSinceEpoch * -1,
        'attaches': [
          {
            '_type': 'POLL',
            'title': title,
            'settings': settings,
            'answers': [
              for (final a in answers) {'text': a},
            ],
          },
        ],
      },
      'notify': notify,
    };

    final response = await _api.sendRequest(Opcode.msgSend, payload);
    return _sentMessageMap(response);
  }

  void sendTyping(int chatId, String type) {
    unawaited(() async {
      try {
        await _api.sendRequest(Opcode.msgTyping, {
          'chatId': chatId,
          'type': type,
        });
      } catch (_) {}
    }());
  }

  Future<Map<String, dynamic>?> sendStickerMessage(
    int chatId,
    int stickerId, {
    bool notify = true,
  }) async {
    final payload = {
      'chatId': chatId,
      'message': {
        'cid': DateTime.now().millisecondsSinceEpoch * -1,
        'attaches': [
          {'_type': 'STICKER', 'stickerId': stickerId},
        ],
      },
      'notify': notify,
    };

    final response = await _api.sendRequest(Opcode.msgSend, payload);
    return _sentMessageMap(response);
  }

  Future<Uint8List?> downloadPhoto(String baseUrl, String photoToken) async {
    try {
      final response = await _api.sendRequest(Opcode.fileDownload, {
        'url': baseUrl,
        'token': photoToken,
      });

      if (!response.isOk) return null;
      final data = response.payload;
      if (data is! Map) return null;

      final content = data['content'];
      if (content is Uint8List) return content;
      if (content is List<int>) return Uint8List.fromList(content);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getPhotoUrl(String baseUrl, String photoToken) async {
    try {
      final response = await _api.sendRequest(Opcode.fileDownload, {
        'url': baseUrl,
        'token': photoToken,
      });

      if (!response.isOk) return null;
      final data = response.payload;
      if (data is! Map) return null;

      return data['content'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, String>> getVideoSources({
    required String messageId,
    required int chatId,
    required String token,
    required int videoId,
  }) async {
    try {
      final response = await _api.sendRequest(Opcode.videoPlay, {
        'messageId': int.tryParse(messageId) ?? 0,
        'chatId': chatId,
        'token': token,
        'videoId': videoId,
      });
      if (!response.isOk) return const {};
      final data = response.payload;
      if (data is! Map) return const {};

      const mp4Keys = {
        'MP4_1080': '1080p',
        'MP4_720': '720p',
        'MP4_480': '480p',
        'MP4_360': '360p',
        'MP4_240': '240p',
        'MP4_144': '144p',
      };
      final sources = <String, String>{};
      for (final entry in mp4Keys.entries) {
        final url = data[entry.key];
        if (url is String && url.isNotEmpty) sources[entry.value] = url;
      }
      if (sources.isEmpty) {
        final hls = data['HLS'];
        if (hls is String && hls.isNotEmpty) sources['Авто'] = hls;
        final external = data['EXTERNAL'];
        if (external is String && external.isNotEmpty) {
          sources['Источник'] = external;
        }
      }
      return sources;
    } catch (_) {
      return const {};
    }
  }

  Future<String?> getVideoUrl({
    required String messageId,
    required int chatId,
    required String token,
    required int videoId,
  }) async {
    final sources = await getVideoSources(
      messageId: messageId,
      chatId: chatId,
      token: token,
      videoId: videoId,
    );
    return sources.values.isEmpty ? null : sources.values.first;
  }

  Future<Uint8List?> downloadVideo(String baseUrl, String videoToken) async {
    try {
      final response = await _api.sendRequest(Opcode.fileDownload, {
        'url': baseUrl,
        'token': videoToken,
      });

      if (!response.isOk) return null;
      final data = response.payload;
      if (data is! Map) return null;

      final content = data['content'];
      if (content is Uint8List) return content;
      if (content is List<int>) return Uint8List.fromList(content);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Uint8List?> downloadFile(String baseUrl, String fileToken) async {
    try {
      final response = await _api.sendRequest(Opcode.fileDownload, {
        'url': baseUrl,
        'token': fileToken,
      });

      if (!response.isOk) return null;
      final data = response.payload;
      if (data is! Map) return null;

      final content = data['content'];
      if (content is Uint8List) return content;
      if (content is List<int>) return Uint8List.fromList(content);
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getFileUrl({
    required String messageId,
    required int chatId,
    required int fileId,
  }) async {
    try {
      final response = await _api.sendRequest(Opcode.fileDownload, {
        'messageId': int.tryParse(messageId) ?? 0,
        'chatId': chatId,
        'fileId': fileId,
      });

      if (!response.isOk) return null;
      final data = response.payload;
      if (data is! Map) return null;

      return data['url'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<String?> searchContactById(int contactId) async {
    final cached = ContactCache.get(contactId);
    if (cached != null) return cached;

    if (_api.state != SessionState.online) return null;

    try {
      final response = await _api.sendRequest(Opcode.contactInfo, {
        'contactIds': [contactId],
      });

      if (!response.isOk) return null;
      final data = response.payload;
      if (data is! Map) return null;

      final contacts = data['contacts'] as List?;
      if (contacts != null && contacts.isNotEmpty) {
        final contact = contacts.first;
        if (contact is Map) {
          final names = contact['names'] as List?;
          if (names != null && names.isNotEmpty) {
            final name = names.first;
            if (name is Map) {
              final firstName = name['firstName'] as String? ?? '';
              final lastName = name['lastName'] as String?;
              final fullName = lastName != null
                  ? '$firstName $lastName'
                  : firstName;
              ContactCache.put(contactId, fullName);

              final baseUrl = contact['baseUrl'] as String?;
              ContactCache.putAvatar(contactId, baseUrl);

              final rawOpts = contact['options'];
              if (rawOpts is List) {
                ContactCache.putOptions(
                  contactId,
                  rawOpts.whereType<String>().toSet(),
                );
              }

              chats.applyContactUpdate(contactId);
              return fullName;
            }
          }
        }
      }
    } catch (e) {
      logger.e('searchContactById error: $e');
    }
    return null;
  }

  Future<bool> ensureContactNames(Iterable<int> ids) async {
    final missing = ids
        .where((id) => id != 0 && ContactCache.get(id) == null)
        .toSet();
    if (missing.isEmpty) return false;
    if (_api.state != SessionState.online) return false;

    try {
      final response = await _api.sendRequest(Opcode.contactInfo, {
        'contactIds': missing.toList(),
      });

      if (!response.isOk) return false;
      final data = response.payload;
      if (data is! Map) return false;

      final contacts = data['contacts'];
      if (contacts is! List) return false;

      var resolvedAny = false;
      for (final raw in contacts.whereType<Map>()) {
        final id = raw['id'];
        if (id is! int) continue;

        final names = raw['names'];
        if (names is List && names.isNotEmpty) {
          final nameRaw = names.firstWhere(
            (n) => n is Map && n['type'] == 'ONEME',
            orElse: () => names.firstWhere((n) => n is Map, orElse: () => null),
          );
          if (nameRaw is Map) {
            final firstName = (nameRaw['firstName'] as String?) ?? '';
            final lastName = nameRaw['lastName'] as String?;
            final fullName = (lastName != null && lastName.isNotEmpty)
                ? '$firstName $lastName'
                : firstName;
            if (fullName.isNotEmpty) ContactCache.put(id, fullName);
          }
        }

        final baseUrl = raw['baseUrl'] as String?;
        if (baseUrl != null && baseUrl.isNotEmpty) {
          ContactCache.putAvatar(id, baseUrl);
        }

        final rawOpts = raw['options'];
        if (rawOpts is List) {
          ContactCache.putOptions(id, rawOpts.whereType<String>().toSet());
        }

        chats.applyContactUpdate(id);
        resolvedAny = true;
      }

      return resolvedAny;
    } catch (e) {
      logger.e('ensureContactNames error: $e');
      return false;
    }
  }
}
