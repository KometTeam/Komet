import '../../core/cache/message_session_cache.dart';
import '../../core/crypto/e2ee_service.dart';
import '../../core/crypto/outgoing_message_policy.dart';
import '../../core/storage/app_database.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import '../../main.dart';
import '../../models/story.dart';
import 'chats.dart';
import 'messages.dart';

enum StoryReplyOutcome { sent, encryptedChat, failed }

abstract final class StoryReplySender {
  static Future<({StoryReplyOutcome outcome, int chatId})> send(
    Story story,
    String text,
  ) async {
    final session = api.session;
    final accountId = await TokenStorage.getActiveAccountId();
    if (accountId == null || accountId == 0) {
      return (outcome: StoryReplyOutcome.failed, chatId: 0);
    }
    final ownerId = story.owner.ownerId;
    final chatId =
        await AppDatabase.findDialogChatByParticipant(accountId, ownerId) ??
        (accountId ^ ownerId);
    try {
      await E2eeService.instance.ensureLoaded(accountId);
    } catch (_) {
      return (outcome: StoryReplyOutcome.failed, chatId: chatId);
    }
    if (OutgoingMessagePolicy.requiresEncryption(accountId, chatId)) {
      return (outcome: StoryReplyOutcome.encryptedChat, chatId: chatId);
    }

    final attach = <String, dynamic>{
      '_type': 'STORY_REPLY',
      'owner': story.owner.toMap(),
      'storyId': story.id,
    };
    try {
      final sent = await messagesModule.sendMessage(
        accountId,
        chatId,
        text,
        attaches: [attach],
        beforeSend: () {
          if (session == null || !identical(api.session, session)) {
            throw StateError('Account changed during story reply');
          }
          OutgoingMessagePolicy.requireSupported(accountId, chatId);
        },
      );
      final id = int.tryParse(sent.id);
      if (id != null && id != 0) {
        await _persist(
          CachedMessage.fromPushPayload(accountId, chatId, {
            'id': sent.id,
            'sender': accountId,
            'time': messageIdToTime(id),
            'text': sent.text ?? text,
            'elements': ?sent.elements,
            'attaches': sent.attaches ?? [attach],
          }),
        );
      }
      return (outcome: StoryReplyOutcome.sent, chatId: chatId);
    } catch (e) {
      logger.w('Ответ на историю не отправился: $e');
      return (outcome: StoryReplyOutcome.failed, chatId: chatId);
    }
  }

  static Future<void> _persist(CachedMessage message) async {
    try {
      await chats.storeSentMessages(message.accountId, message.chatId, [
        message,
      ]);
      await chats.applyOutgoingMessage(message, status: 'sent');
    } catch (e) {
      logger.w('Ответ на историю не сохранился: $e');
    }
    MessageSessionCache.append(message.accountId, message.chatId, [message]);
  }
}
