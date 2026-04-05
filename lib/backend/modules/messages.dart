import 'dart:convert';
import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/storage/app_database.dart';

class CachedMessage {
  final String id;
  final int accountId;
  final int chatId;
  final int senderId;
  final String? text;
  final int time;
  final String? status;
  final Map<String, dynamic>? payload;

  const CachedMessage({
    required this.id,
    required this.accountId,
    required this.chatId,
    required this.senderId,
    this.text,
    required this.time,
    this.status,
    this.payload,
  });

  factory CachedMessage.fromDbRow(Map<String, dynamic> row) {
    Map<String, dynamic>? payload;
    final payloadRaw = row['payload'];
    if (payloadRaw is String && payloadRaw.isNotEmpty) {
      try {
        payload = jsonDecode(payloadRaw) as Map<String, dynamic>;
      } catch (_) {}
    }

    return CachedMessage(
      id: row['id'] as String,
      accountId: row['account_id'] as int,
      chatId: row['chat_id'] as int,
      senderId: row['sender_id'] as int,
      text: row['text'] as String?,
      time: row['time'] as int,
      status: row['status'] as String?,
      payload: payload,
    );
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
      AppDatabase.saveMessages(rows).ignore();
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
    return rows.map(CachedMessage.fromDbRow).toList();
  }

  CachedMessage? _parseMessage(
    Map<dynamic, dynamic> m,
    int accountId,
    int chatId,
  ) {
    final id = m['id']?.toString();
    if (id == null) return null;

    return CachedMessage(
      id: id,
      accountId: accountId,
      chatId: chatId,
      senderId: (m['sender'] as int?) ?? 0,
      text: m['text'] as String?,
      time: (m['time'] as int?) ?? 0,
      status: m['status'] as String?,
      payload: m.cast<String, dynamic>(),
    );
  }

  Future<void> sendMessage(int accountId, int chatId, String text) async {
    final payload = {'chatId': chatId, 'text': text};

    await _api.sendRequest(Opcode.msgSend, payload);
  }
}
