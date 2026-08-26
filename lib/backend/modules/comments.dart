import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../api.dart';
import 'messages.dart' show CachedMessage;

class CommentsInfo {
  final String postId;
  final int? totalCount;
  final int? updatedAt;
  const CommentsInfo({
    required this.postId,
    this.totalCount,
    this.updatedAt,
  });

  factory CommentsInfo.fromPayload(String postId, Map payload) {
    final raw = payload['totalCount'];
    int? count;
    if (raw is int) {
      count = raw;
    } else if (raw is String) {
      count = int.tryParse(raw);
    }
    return CommentsInfo(
      postId: postId,
      totalCount: count,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class CommentAddedEvent {
  final int chatId;
  final String postId;
  final CachedMessage comment;
  const CommentAddedEvent(this.chatId, this.postId, this.comment);
}

class CommentsModule {
  final Api _api;

  CommentsModule(this._api);

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final _infoController =
      StreamController<Map<String, CommentsInfo>>.broadcast();
  Stream<Map<String, CommentsInfo>> get infoStream => _infoController.stream;

  final _commentController = StreamController<CommentAddedEvent>.broadcast();
  Stream<CommentAddedEvent> get commentStream => _commentController.stream;

  Map<String, CommentsInfo> _info = <String, CommentsInfo>{};
  Map<String, CommentsInfo> get infoSnapshot => Map.unmodifiable(_info);

  CommentsInfo? infoFor(String postId) => _info[postId];

  int _accountId = 0;

  void dispose() {
    _pushSub?.cancel();
    _pushSub = null;
    _infoController.close();
    _commentController.close();
    revision.dispose();
  }

  void attachPushHandlers(Api api) {
    _pushSub?.cancel();
    _pushSub = api.pushStream.listen(_handlePush);
  }

  StreamSubscription<Packet>? _pushSub;

  void _handlePush(Packet packet) {
    switch (packet.opcode) {
      case Opcode.commentsInfo:
        final payload = packet.payload;
        if (payload is! Map) return;
        final updates = payload['commentsInfoUpdates'];
        if (updates is List) handleInfoUpdate(updates);
      case Opcode.notifMessage:
        _handleCommentPush(packet);
    }
  }

  void _handleCommentPush(Packet packet) {
    final payload = packet.payload;
    if (payload is! Map) return;
    final chatId = payload['chatId'];
    if (chatId is! int) return;
    final msg = payload['message'];
    if (msg is! Map) return;

    final link = msg['link'];
    final postId =
        (payload['postId'] ?? (link is Map ? link['postId'] : null) ??
                msg['postId'])
            ?.toString();
    if (postId == null || postId.isEmpty) return;

    final comment = _parseComment(
      msg.cast<dynamic, dynamic>(),
      _accountId,
      chatId,
      postId,
    );
    if (comment == null) return;
    _commentController.add(CommentAddedEvent(chatId, postId, comment));
  }

  void handleInfoUpdate(List updates) {
    if (updates.isEmpty) return;
    Map<String, CommentsInfo>? next;
    for (final raw in updates) {
      if (raw is! Map) continue;
      final postId = raw['postId']?.toString();
      final commentsInfo = raw['commentsInfo'];
      if (postId == null || commentsInfo is! Map) continue;
      final updated = CommentsInfo.fromPayload(
        postId,
        Map<String, dynamic>.from(commentsInfo.cast()),
      );
      next ??= Map<String, CommentsInfo>.from(_info);
      next[postId] = updated;
    }
    if (next == null) return;
    _info = next;
    revision.value = revision.value + 1;
    _infoController.add(Map.unmodifiable(_info));
  }

  Future<Map<String, CommentsInfo>> fetchInfo({
    required int accountId,
    required int chatId,
    required List<String> postIds,
  }) async {
    _accountId = accountId;
    if (postIds.isEmpty) return const {};
    final response = await _api.sendRequest(Opcode.commentsInfo, {
      'chatId': chatId,
      'postIds': postIds.map((id) => int.tryParse(id) ?? id).toList(),
    });
    if (!response.isOk) return const {};
    final payload = response.payload;
    if (payload is! Map) return const {};
    final updates = payload['commentsInfoUpdates'];
    if (updates is! List) return const {};
    handleInfoUpdate(updates);
    final byPost = <String, CommentsInfo>{};
    for (final raw in updates.whereType<Map>()) {
      final postId = raw['postId']?.toString();
      final commentsInfo = raw['commentsInfo'];
      if (postId == null || commentsInfo is! Map) continue;
      byPost[postId] = CommentsInfo.fromPayload(
        postId,
        Map<String, dynamic>.from(commentsInfo.cast()),
      );
    }
    return byPost;
  }

  Future<List<CachedMessage>> fetchHistory(
    int accountId,
    int chatId,
    String postId, {
    required int fromTime,
    int forward = 30,
    int backward = 15,
  }) async {
    _accountId = accountId;
    final payload = <String, dynamic>{
      'chatId': chatId,
      'postId': int.tryParse(postId) ?? postId,
      'from': fromTime,
      'forward': forward,
      'backward': backward,
      'getMessages': true,
    };

    final response = await _api.sendRequest(Opcode.chatHistory, payload);
    if (!response.isOk) return const [];
    final data = response.payload;
    if (data is! Map) return const [];

    final messagesData = data['messages'];
    if (messagesData is! List) return const [];

    final results = <CachedMessage>[];
    for (var i = 0; i < messagesData.length; i++) {
      final m = messagesData[i];
      if (m is! Map) continue;
      final parsed = _parseComment(
        m.cast<dynamic, dynamic>(),
        accountId,
        chatId,
        postId,
      );
      if (parsed != null) results.add(parsed);
      if (i > 0 && i % 20 == 0) await Future<void>.delayed(Duration.zero);
    }

    return results;
  }

  Future<String> sendComment(
    int accountId,
    int chatId,
    String postId,
    String text, {
    bool notify = true,
    int? replyToMessageId,
    List<Map<String, dynamic>> elements = const [],
  }) async {
    _accountId = accountId;
    final Object postIdField = int.tryParse(postId) ?? postId;
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
        'postId': postIdField,
        'messageId': replyToMessageId,
      };
    }
    final payload = <String, dynamic>{
      'chatId': chatId,
      'postId': postIdField,
      'message': message,
      'notify': notify,
    };

    final response = await _api.sendRequest(Opcode.msgSend, payload);
    if (!response.isOk) {
      final raw = response.payload;
      final msg = (raw is Map)
          ? (raw['localizedMessage'] ?? raw['message'] ?? 'Ошибка отправки')
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

  void sendTyping(int chatId, String postId, String type) {
    unawaited(() async {
      try {
        await _api.sendRequest(Opcode.msgTyping, {
          'chatId': chatId,
          'postId': int.tryParse(postId) ?? postId,
          'type': type,
        });
      } catch (_) {}
    }());
  }

  CachedMessage? _parseComment(
    Map<dynamic, dynamic> m,
    int accountId,
    int chatId,
    String postId,
  ) {
    final id = m['id']?.toString();
    if (id == null) return null;

    final full = Map<String, dynamic>.from(m.cast());
    full['postId'] = postId;
    final parsed = CachedMessage.parseAttachments(full);
    final senderId = _parseIntField(m['sender']);

    return CachedMessage(
      id: id,
      accountId: accountId,
      chatId: chatId,
      senderId: senderId,
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
}
