import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/app_database.dart';
import '../../core/utils/logger.dart';
import '../../models/attachment.dart';
import 'chats.dart' show ChatsModule;

class ContactCache {
  static final Map<int, String> _nameCache = {};
  static final Map<int, String> _avatarCache = {};
  static final Map<int, Set<String>> _optionsCache = {};

  static void put(int id, String name) => _nameCache[id] = name;

  static void putAvatar(int id, String? baseUrl) {
    if (baseUrl != null) _avatarCache[id] = baseUrl;
  }

  static void putOptions(int id, Set<String> opts) => _optionsCache[id] = opts;

  static String? get(int id) => _nameCache[id];
  static String? getAvatar(int id) => _avatarCache[id];
  static Set<String>? getOptions(int id) => _optionsCache[id];
  static bool isOfficial(int id) =>
      _optionsCache[id]?.contains('OFFICIAL') ?? false;

  static void clear() {
    _nameCache.clear();
    _avatarCache.clear();
    _optionsCache.clear();
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
  });

  factory CachedMessage.fromDbRow(Map<String, dynamic> row) {
    Map<String, dynamic>? payload;
    final payloadRaw = row['payload'];
    if (payloadRaw is String && payloadRaw.isNotEmpty) {
      try {
        payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      } catch (_) {}
    }

    List<MessageAttachment>? attachments;
    if (payload != null) {
      final linkType = payload['link']?['type'] as String?;
      if (linkType == 'FORWARD') {
        attachments = [ForwardedMessageAttachment.fromMap(payload)];
      } else {
        final attaches = payload['attaches'] as List?;
        if (attaches != null) {
          attachments = attaches
              .map(
                (a) => MessageAttachment.fromMap(
                  Map<String, dynamic>.from(a as Map),
                ),
              )
              .toList();
        }
      }
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
      isControl:
          attachments?.any((a) => a.type == AttachmentType.control) ?? false,
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
  };

  static CachedMessage fromPushPayload(int accountId, int chatId, Map msg) {
    List<MessageAttachment>? attachments;
    final attaches = msg['attaches'];
    if (attaches is List && attaches.isNotEmpty) {
      attachments = attaches
          .whereType<Map>()
          .map((a) => MessageAttachment.fromMap(Map<String, dynamic>.from(a)))
          .toList();
    }
    return CachedMessage(
      id: msg['id']?.toString() ?? '',
      accountId: accountId,
      chatId: chatId,
      senderId: msg['sender'] as int? ?? 0,
      text: msg['text'] as String?,
      time: (msg['time'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      status: (msg['status'] as String?) ?? 'sent',
      payload: Map<String, dynamic>.from(msg),
      attachments: attachments,
    );
  }
}

class MessagesModule {
  final Api _api;

  MessagesModule(this._api);

  /// Загружает историю сообщений для указанного чата.
  ///
  /// [fromTime] — опционально, время от которого грузить (миллисекунды).
  /// Если не указано, грузит самые свежие.
  /// [count] — количество сообщений.
  Future<List<CachedMessage>> fetchHistory(
    int accountId,
    int chatId, {
    int? fromTime,
    int count = 50,
  }) async {
    final payload = {
      'chatId': chatId,
      'from':
          fromTime ??
          (DateTime.now().millisecondsSinceEpoch +
              86400000), // +1 день для запаса
      'forward': 0,
      'backward': count,
      'getMessages': true,
    };

    final response = await _api.sendRequest(Opcode.chatHistory, payload);

    if (!response.isOk) return [];

    final data = response.payload;
    if (data is! Map) return [];

    final messagesData = data['messages'];
    if (messagesData is! List) return [];

    final List<CachedMessage> results = [];
    final List<Map<String, dynamic>> rows = [];

    for (var i = 0; i < messagesData.length; i++) {
      final m = messagesData[i];
      if (m is! Map) continue;

      final msg = _parseMessage(m.cast<dynamic, dynamic>(), accountId, chatId);
      if (msg != null) {
        results.add(msg);
        rows.add(msg.toDbRow());
      }

      if (i > 0 && i % 20 == 0) {
        await Future.delayed(Duration.zero);
      }
    }

    if (rows.isNotEmpty) {
      AppDatabase.saveMessages(rows).catchError((e) {
        logger.e('saveMessages error: $e');
      });
    }

    return results;
  }

  /// Загружает сообщения из локальной базы данных.
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

    final linkRaw = m['link'];
    String? linkType;
    if (linkRaw is Map) {
      linkType = linkRaw['type'] as String?;
    }

    List<MessageAttachment>? attachments;
    bool isControl = false;
    if (linkType == 'FORWARD') {
      final fwdMap = Map<String, dynamic>.from(m.cast());
      attachments = [ForwardedMessageAttachment.fromMap(fwdMap)];
    } else {
      final attaches = m['attaches'] as List?;
      if (attaches != null) {
        attachments = attaches
            .whereType<Map>()
            .map((a) => MessageAttachment.fromMap(Map<String, dynamic>.from(a)))
            .toList();
        // Detect CONTROL
        if (attachments.any((a) => a.type == AttachmentType.control)) {
          isControl = true;
        }
      }
    }

    return CachedMessage(
      id: id,
      accountId: accountId,
      chatId: chatId,
      senderId: _parseIntField(m['sender']),
      text: m['text']?.toString(),
      time: _parseIntField(m['time']),
      status: m['status']?.toString(),
      payload: Map<String, dynamic>.from(m.cast()),
      attachments: attachments,
      isControl: isControl,
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
  }) async {
    final message = <String, dynamic>{
      'text': text,
      'cid': DateTime.now().millisecondsSinceEpoch * -1,
      'elements': [],
      'attaches': [],
    };
    if (scheduledTime != null) {
      message['delayedAttributes'] = {
        'timeToFire': scheduledTime,
        'notifySender': true,
      };
    }
    final payload = {
      'chatId': chatId,
      'message': message,
      'notify': notify,
    };

    final response = await _api.sendRequest(Opcode.msgSend, payload);
    if (!response.isOk) {
      final msg = (response.payload is Map)
          ? (response.payload['localizedMessage'] ??
                response.payload['message'] ??
                'Ошибка отправки')
          : 'Ошибка отправки';
      throw Exception(msg.toString());
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

  /// Загружает отложенные (запланированные) сообщения чата.
  ///
  /// В отличие от обычной истории, отложенные сообщения не сохраняются
  /// в локальную БД — они живут только до момента отправки.
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

  /// Редактирует текст (подпись) обычного сообщения.
  ///
  /// Поле `attachments` не передаётся — сервер сохраняет существующие
  /// вложения.
  Future<bool> editMessage(
    int chatId,
    String messageId, {
    required String text,
  }) async {
    final id = int.tryParse(messageId);
    if (id == null) return false;

    final payload = {
      'messageId': id,
      'chatId': chatId,
      'elements': <dynamic>[],
      'text': text,
    };

    final response = await _api.sendRequest(Opcode.msgEdit, payload);
    return response.isOk;
  }

  /// Редактирует отложенное сообщение: меняет текст и/или время отправки.
  ///
  /// Вложения сервер сохраняет сам — в payload они не передаются.
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
      'delayedAttributes': {
        'timeToFire': timeToFire,
        'notifySender': true,
      },
    };

    final response = await _api.sendRequest(Opcode.msgEdit, payload);
    return response.isOk;
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

    final response = await _api.sendRequest(Opcode.msgDelete, payload);
    return response.isOk;
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
    Duration initialDelay = const Duration(seconds: 3),
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
    final payload = {
      'chatId': chatId,
      'message': message,
      'notify': notify,
    };

    await Future.delayed(initialDelay);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _api.sendRequest(Opcode.msgSend, payload);
        if (response.isOk) return true;
        return false;
      } on PacketError catch (e) {
        if (e.errorKey != 'attachment.not.ready') rethrow;
        if (attempt == maxAttempts - 1) return false;
        await Future.delayed(retryDelay);
      }
    }
    return false;
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

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _api.sendRequest(Opcode.msgSend, payload);
        if (!response.isOk) return null;
        final data = response.payload;
        if (data is Map) {
          final msg = data['message'];
          if (msg is Map) return Map<String, dynamic>.from(msg);
        }
        return null;
      } on PacketError catch (e) {
        if (e.errorKey != 'attachment.not.ready') rethrow;
        if (attempt == maxAttempts - 1) return null;
        await Future.delayed(retryDelay);
      }
    }
    return null;
  }

  /// Запрашивает URL для загрузки видео (опкод 82).
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

  /// Отправляет сообщение с видео по [token], полученному из
  /// [requestVideoUploadUrl]. Сервер может ответить `attachment.not.ready`,
  /// пока обрабатывает загруженное видео — в этом случае запрос повторяется.
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

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final response = await _api.sendRequest(Opcode.msgSend, payload);
        if (!response.isOk) return null;
        final data = response.payload;
        if (data is Map) {
          final msg = data['message'];
          if (msg is Map) return Map<String, dynamic>.from(msg);
        }
        return null;
      } on PacketError catch (e) {
        if (e.errorKey != 'attachment.not.ready') rethrow;
        if (attempt == maxAttempts - 1) return null;
        await Future.delayed(retryDelay);
      }
    }
    return null;
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
    if (!response.isOk) return null;
    final data = response.payload;
    if (data is Map) {
      final msg = data['message'];
      if (msg is Map) return Map<String, dynamic>.from(msg);
    }
    return null;
  }

  Future<Map<String, dynamic>?> sendPollMessage(
    int chatId,
    String title,
    List<String> answers, {
    bool multiple = false,
    bool anonymous = true,
    bool notify = true,
  }) async {
    final settings = (anonymous ? 4 : 0) | (multiple ? 1 : 0);
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
    if (!response.isOk) return null;
    final data = response.payload;
    if (data is Map) {
      final msg = data['message'];
      if (msg is Map) return Map<String, dynamic>.from(msg);
    }
    return null;
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

  /// Запрашивает у сервера ссылку на воспроизведение видео (opcode 83).
  ///
  /// Формат подтверждён дампом: запрос `{messageId, chatId, token, videoId}`,
  /// ответ содержит `MP4_1080/MP4_720/...`, `HLS`, `DASH`, `EXTERNAL`.
  /// Возвращает лучший доступный progressive-MP4 (или HLS как запасной).
  Future<String?> getVideoUrl({
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
      if (!response.isOk) return null;
      final data = response.payload;
      if (data is! Map) return null;

      const mp4Keys = ['MP4_1080', 'MP4_720', 'MP4_480', 'MP4_360', 'MP4_240'];
      for (final key in mp4Keys) {
        final url = data[key];
        if (url is String && url.isNotEmpty) return url;
      }
      final hls = data['HLS'];
      if (hls is String && hls.isNotEmpty) return hls;
      final external = data['EXTERNAL'];
      if (external is String && external.isNotEmpty) return external;
      return null;
    } catch (_) {
      return null;
    }
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

  /// Запрашивает у сервера временный CDN-URL для скачивания файла (opcode 88).
  ///
  /// Формат подтверждён дампом: запрос `{messageId, chatId, fileId}`,
  /// ответ `{url: "https://fd.oneme.ru/getfile?..."}`.
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

              ChatsModule.applyContactUpdate(contactId);
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
}
