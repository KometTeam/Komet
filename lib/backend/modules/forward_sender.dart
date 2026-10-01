import 'dart:async';
import 'dart:math';

import '../../core/cache/message_session_cache.dart';
import '../../core/utils/logger.dart';
import '../../main.dart';
import 'chats.dart';
import 'message_copy.dart';
import 'messages.dart';

// #***! запрос на пересылку — источник сообщений, ждёт цели/подтверждения
class ForwardRequest {
  final int sourceChatId;
  final String sourceChatName;
  final String sourceChatIconUrl;
  final String sourceChatType;
  final List<CachedMessage> messages;
  final bool hideSender;

  ForwardRequest({
    required this.sourceChatId,
    required this.sourceChatName,
    required this.sourceChatIconUrl,
    required this.sourceChatType,
    required List<CachedMessage> messages,
    this.hideSender = false,
  }) : messages = List.unmodifiable(messages);

  late final bool canHideSender = messages.every(
    (message) => MessageCopy.of(message) != null,
  );

  ForwardRequest withMessages(List<CachedMessage> value) =>
      _copyWith(messages: value);

  ForwardRequest withHideSender(bool value) => _copyWith(hideSender: value);

  ForwardRequest _copyWith({List<CachedMessage>? messages, bool? hideSender}) =>
      ForwardRequest(
        sourceChatId: sourceChatId,
        sourceChatName: sourceChatName,
        sourceChatIconUrl: sourceChatIconUrl,
        sourceChatType: sourceChatType,
        messages: messages ?? this.messages,
        hideSender: hideSender ?? this.hideSender,
      );

  CachedMessage optimisticForward(
    CachedMessage source, {
    required int myId,
    required int targetChatId,
    required String tempId,
    required String status,
  }) => MessagesModule.buildForwardMessage(
    myId: myId,
    targetChatId: targetChatId,
    sourceChatId: sourceChatId,
    source: source,
    tempId: tempId,
    time: DateTime.now().millisecondsSinceEpoch,
    status: status,
    sourceChatName: sourceChatName,
    sourceChatIconUrl: sourceChatIconUrl,
    sourceChatType: sourceChatType,
  );
}

class ForwardCaption {
  final String text;
  final List<Map<String, dynamic>> elements;

  const ForwardCaption(this.text, [this.elements = const []]);

  bool get isEmpty => text.isEmpty;
}

class ForwardSendResult {
  final Set<int> delivered;
  final Map<int, int> unfinished;

  const ForwardSendResult({required this.delivered, required this.unfinished});
}

class ForwardSender {
  ForwardSender._();

  static const int _parallelChats = 3;

  static final StreamController<List<CachedMessage>> _deliveredController =
      StreamController.broadcast();

  static Stream<List<CachedMessage>> get delivered =>
      _deliveredController.stream;

  static Future<ForwardSendResult> send({
    required int accountId,
    required List<int> chatIds,
    required ForwardRequest request,
    ForwardCaption caption = const ForwardCaption(''),
    Map<int, int> resumeFrom = const {},
  }) async {
    final copies = request.hideSender
        ? [for (final source in request.messages) MessageCopy.of(source)]
        : null;
    if (copies != null && copies.contains(null)) {
      return ForwardSendResult(
        delivered: const {},
        unfinished: {
          for (final chatId in chatIds) chatId: resumeFrom[chatId] ?? 0,
        },
      );
    }
    final pending = [...chatIds];
    final delivered = <int>{};
    final unfinished = <int, int>{};
    Future<void> worker() async {
      while (pending.isNotEmpty) {
        final chatId = pending.removeLast();
        final done = await _sendToChat(
          accountId,
          chatId,
          request,
          copies?.cast<MessageCopy>(),
          caption,
          resumeFrom[chatId] ?? 0,
        );
        if (done == null) {
          delivered.add(chatId);
        } else {
          unfinished[chatId] = done;
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < min(_parallelChats, chatIds.length); i++) worker(),
    ]);
    return ForwardSendResult(delivered: delivered, unfinished: unfinished);
  }

  static Future<int?> _sendToChat(
    int accountId,
    int chatId,
    ForwardRequest request,
    List<MessageCopy>? copies,
    ForwardCaption caption,
    int from,
  ) async {
    final messages = request.messages;
    final steps = messages.length + (caption.isEmpty ? 0 : 1);
    final sent = <CachedMessage>[];
    var step = from;
    try {
      for (; step < steps; step++) {
        sent.add(
          step == messages.length
              ? await _sendCaption(accountId, chatId, caption)
              : copies == null
              ? await sendForward(accountId, chatId, request, messages[step])
              : await _deliverCopy(accountId, chatId, copies[step]),
        );
      }
      return null;
    } catch (e) {
      logger.w('Пересылка в $chatId остановилась на шаге $step: $e');
      return step;
    } finally {
      await _persist(sent);
    }
  }

  static Future<CachedMessage> sendForward(
    int accountId,
    int chatId,
    ForwardRequest request,
    CachedMessage source, {
    CachedMessage? optimistic,
  }) async {
    final local =
        optimistic ??
        request.optimisticForward(
          source,
          myId: accountId,
          targetChatId: chatId,
          tempId: '',
          status: 'sent',
        );
    final realId = await messagesModule.forwardMessage(
      chatId,
      request.sourceChatId,
      int.parse(source.id),
    );
    return MessagesModule.reidentifyMessage(
      local,
      realId.isNotEmpty ? realId : local.id,
      status: 'sent',
    );
  }

  static Future<CachedMessage> sendCopy(
    int accountId,
    int chatId,
    CachedMessage source,
  ) {
    final copy = MessageCopy.of(source);
    if (copy == null) throw StateError('message ${source.id} cannot be copied');
    return _deliverCopy(accountId, chatId, copy);
  }

  static Future<CachedMessage> _deliverCopy(
    int accountId,
    int chatId,
    MessageCopy copy,
  ) async {
    final sent = await messagesModule.sendMessageCopy(chatId, copy);
    return CachedMessage.fromPushPayload(accountId, chatId, sent);
  }

  static Future<void> recordInChatList(CachedMessage message) async {
    final status = message.status ?? 'sending';
    if (message.forwardedAttachment == null) {
      await chats.applyOutgoingMessage(message, status: status);
      return;
    }
    await chats.applyOutgoing(
      message.accountId,
      message.chatId,
      messageId: message.id,
      time: message.time,
      text: MessagesModule.forwardPreviewText(message),
      status: status,
    );
  }

  static Future<void> _persist(List<CachedMessage> sent) async {
    final stored = [
      for (final message in sent)
        if (message.id.isNotEmpty) message,
    ];
    if (stored.isEmpty) return;
    final last = stored.last;
    try {
      await chats.storeSentMessages(last.accountId, last.chatId, stored);
      await recordInChatList(last);
    } catch (e) {
      logger.w('Пересланное в ${last.chatId} не сохранилось: $e');
    }
    MessageSessionCache.append(last.accountId, last.chatId, stored);
    _deliveredController.add(stored);
  }

  static Future<CachedMessage> _sendCaption(
    int accountId,
    int chatId,
    ForwardCaption caption,
  ) async {
    final id = await messagesModule.sendMessage(
      accountId,
      chatId,
      caption.text,
      elements: caption.elements,
    );
    return CachedMessage(
      id: id,
      accountId: accountId,
      chatId: chatId,
      senderId: accountId,
      text: caption.text,
      time: DateTime.now().millisecondsSinceEpoch,
      status: 'sent',
      payload: caption.elements.isEmpty
          ? null
          : {'text': caption.text, 'elements': caption.elements},
    );
  }
}
