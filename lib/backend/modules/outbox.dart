import 'dart:async';

import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import '../api.dart';
import 'chats.dart';
import 'messages.dart';

class OutboxService {
  OutboxService._();

  static final OutboxService instance = OutboxService._();

  Api? _api;
  MessagesModule? _messages;
  bool _flushing = false;

  void init(Api api, MessagesModule messages) {
    if (_api != null) return;
    _api = api;
    _messages = messages;
    api.stateStream.listen((state) {
      if (state == SessionState.online) unawaited(flush());
    });
    if (api.state == SessionState.online) unawaited(flush());
  }

  Future<void> flush() async {
    if (_flushing) return;
    final api = _api;
    final messages = _messages;
    if (api == null || messages == null) return;
    if (api.state != SessionState.online) return;

    _flushing = true;
    try {
      final accountId = await TokenStorage.getActiveAccountId();
      if (accountId == null) return;

      final rows = await AppDatabase.loadPendingMessages(accountId);
      for (final row in rows) {
        if (api.state != SessionState.online) break;
        final pending = CachedMessage.fromDbRow(row);
        final text = pending.text;
        if (text == null || text.isEmpty) continue;

        final payload = pending.payload;
        final replyToMessageId = _replyIdFromPayload(payload);
        final elements = _elementsFromPayload(payload);

        try {
          final actualId = await messages.sendMessage(
            accountId,
            pending.chatId,
            text,
            replyToMessageId: replyToMessageId,
            elements: elements,
          );
          final sent = CachedMessage(
            id: actualId.isNotEmpty ? actualId : pending.id,
            accountId: accountId,
            chatId: pending.chatId,
            senderId: accountId,
            text: text,
            time: pending.time,
            status: 'sent',
            payload: payload,
          );
          await AppDatabase.saveMessages([sent.toDbRow()]);
          if (sent.id != pending.id) {
            await AppDatabase.deleteMessage(
              accountId,
              pending.chatId,
              pending.id,
            );
          }
          chats.emitMessageSent(pending.chatId, pending.id, sent);
          await chats.applyOutgoing(
            accountId,
            pending.chatId,
            messageId: sent.id,
            time: sent.time,
            text: text,
            status: 'sent',
            elements: elements.isEmpty ? null : elements,
          );
        } catch (e) {
          logger.w('Outbox: отправка ${pending.id} не удалась: $e');
          continue;
        }
      }
    } catch (e) {
      logger.e('Outbox flush: $e');
    } finally {
      _flushing = false;
    }
  }

  int? _replyIdFromPayload(Map<String, dynamic>? payload) {
    if (payload == null) return null;
    final link = payload['link'];
    if (link is! Map) return null;
    if ((link['type'] as String?)?.toUpperCase() != 'REPLY') return null;
    final msg = link['message'];
    if (msg is Map) {
      final id = msg['id'];
      if (id is int) return id;
      if (id != null) return int.tryParse(id.toString());
    }
    final mid = link['messageId'];
    if (mid is int) return mid;
    if (mid != null) return int.tryParse(mid.toString());
    return null;
  }

  List<Map<String, dynamic>> _elementsFromPayload(
    Map<String, dynamic>? payload,
  ) {
    final raw = payload?['elements'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
