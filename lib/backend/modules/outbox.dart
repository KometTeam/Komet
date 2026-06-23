import 'dart:async';

import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
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
        if (text == null || text.isEmpty || pending.payload != null) continue;

        try {
          final actualId =
              await messages.sendMessage(accountId, pending.chatId, text);
          final sent = CachedMessage(
            id: actualId.isNotEmpty ? actualId : pending.id,
            accountId: accountId,
            chatId: pending.chatId,
            senderId: accountId,
            text: text,
            time: pending.time,
            status: 'sent',
          );
          await AppDatabase.saveMessages([sent.toDbRow()]);
          if (sent.id != pending.id) {
            await AppDatabase.deleteMessage(
                accountId, pending.chatId, pending.id);
          }
          ChatsModule.emitMessageSent(pending.chatId, pending.id, sent);
          await ChatsModule.applyOutgoing(
            accountId,
            pending.chatId,
            messageId: sent.id,
            time: sent.time,
            text: text,
            status: 'sent',
          );
        } catch (_) {
          break;
        }
      }
    } catch (_) {
    } finally {
      _flushing = false;
    }
  }
}
