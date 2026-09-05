import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;

import '../../../../backend/api.dart';
import '../../../../backend/modules/chats.dart';
import '../../../../backend/modules/messages.dart';
import '../../../../core/config/app_commands.dart';
import '../../../../core/crypto/message_decryption_cache.dart';
import '../../../../core/plugins/plugin_outgoing_text.dart';
import '../../../../core/protocol/packet.dart';
import '../../../../core/storage/app_database.dart';
import '../../../../core/storage/draft_store.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../commands/commands.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/rich_message_controller.dart';
import 'chat_controller.dart';

List<Map<String, dynamic>> trimmedElements(
  List<Map<String, dynamic>> raw,
  String rawText,
  String text,
) {
  if (raw.isEmpty) return const [];
  final leading = rawText.length - rawText.trimLeft().length;
  final result = <Map<String, dynamic>>[];
  for (final element in raw) {
    var from = (element['from'] as int) - leading;
    var length = element['length'] as int;
    if (from < 0) {
      length += from;
      from = 0;
    }
    if (from >= text.length || length <= 0) continue;
    if (from + length > text.length) length = text.length - from;
    if (length <= 0) continue;
    result.add({...element, 'from': from, 'length': length});
  }
  return result;
}

// #***! запрос на пересылку — источник сообщений, ждёт цели/подтверждения
class ForwardRequest {
  final int sourceChatId;
  final String sourceChatName;
  final String sourceChatIconUrl;
  final String sourceChatType;
  final List<CachedMessage> messages;

  ForwardRequest({
    required this.sourceChatId,
    required this.sourceChatName,
    required this.sourceChatIconUrl,
    required this.sourceChatType,
    required List<CachedMessage> messages,
  }) : messages = List.unmodifiable(messages);

  ForwardRequest withMessages(List<CachedMessage> value) => ForwardRequest(
    sourceChatId: sourceChatId,
    sourceChatName: sourceChatName,
    sourceChatIconUrl: sourceChatIconUrl,
    sourceChatType: sourceChatType,
    messages: value,
  );
}

// #***! текстовые сообщения + пересылка + reply-состояние; медиа-отправка
// живёт отдельно в ChatMediaSendController — здесь то, что завязано на
// reply/draft/slash-команды/подтверждение отправки
class ChatTextSendController {
  final ChatController chatController;
  final RichMessageController messageController;
  final ValueNotifier<bool> hasText;
  final ValueNotifier<CachedMessage?> replyTo;
  final ValueNotifier<List<CachedMessage>> pendingForwards;
  final bool commentsMode;
  final String? commentPostId;
  final VoidCallback bumpMessages;
  final VoidCallback scrollToBottom;
  final VoidCallback focusComposer;
  final void Function(String?) setLastSentId;
  final void Function(String) notify;
  final bool Function() isMounted;
  final BuildContext Function() contextOf;
  final CachedChat? Function() chatOf;
  final void Function(CachedChat) setChat;
  final bool Function() isChatListed;
  final VoidCallback markChatListed;
  final Future<String?> Function(String text, {bool notify}) encryptOutgoing;
  final Future<void> Function(SlashCommand command, String args) executeCommand;
  final void Function(CachedMessage) checkPrankTrigger;
  final VoidCallback syncOtherReadTime;

  ChatTextSendController({
    required this.chatController,
    required this.messageController,
    required this.hasText,
    required this.replyTo,
    required this.pendingForwards,
    required this.commentsMode,
    required this.commentPostId,
    required this.bumpMessages,
    required this.scrollToBottom,
    required this.focusComposer,
    required this.setLastSentId,
    required this.notify,
    required this.isMounted,
    required this.contextOf,
    required this.chatOf,
    required this.setChat,
    required this.isChatListed,
    required this.markChatListed,
    required this.encryptOutgoing,
    required this.executeCommand,
    required this.checkPrankTrigger,
    required this.syncOtherReadTime,
  });

  int get _myId => chatController.myId;
  int get _chatId => chatController.chatId;

  // #***! доступен _pickReplyChat (остаётся в chat_screen.dart, навигация)
  int? replySourceChatId;
  ForwardRequest? forwardRequest;
  bool _forwardSending = false;

  void startReply(CachedMessage message) {
    cancelForward();
    replyTo.value = message;
    replySourceChatId = null;
    focusComposer();
  }

  void cancelReply() {
    replyTo.value = null;
    replySourceChatId = null;
  }

  void setForwardRequest(ForwardRequest request) {
    cancelReply();
    forwardRequest = request;
    pendingForwards.value = request.messages;
  }

  void cancelForward() {
    forwardRequest = null;
    pendingForwards.value = const [];
  }

  Future<void> _syncForwardOutgoing(
    CachedMessage message, {
    String? removeId,
  }) async {
    await chatController.persistOutgoing(message, removeId: removeId);
    try {
      await chats.applyOutgoing(
        _myId,
        _chatId,
        messageId: message.id,
        time: message.time,
        text: MessagesModule.forwardPreviewText(message),
        status: message.status ?? 'sending',
      );
    } catch (_) {}
  }

  Future<bool> sendForwardRequest() async {
    var request = forwardRequest;
    if (request == null) return true;
    if (api.state != SessionState.online) {
      notify('Нет соединения');
      return false;
    }
    Haptics.send();
    while (request != null && request.messages.isNotEmpty) {
      if (!identical(forwardRequest, request)) return false;
      final source = request.messages.first;
      final optimistic = MessagesModule.buildForwardMessage(
        myId: _myId,
        targetChatId: _chatId,
        sourceChatId: request.sourceChatId,
        source: source,
        tempId: chatController.nextTempId(),
        time: DateTime.now().millisecondsSinceEpoch,
        status: 'sending',
        sourceChatName: request.sourceChatName,
        sourceChatIconUrl: request.sourceChatIconUrl,
        sourceChatType: request.sourceChatType,
      );
      chatController.addMessage(optimistic);
      bumpMessages();
      scrollToBottom();
      await _syncForwardOutgoing(optimistic);
      final sent = await _sendOneForward(optimistic, request.sourceChatId);
      if (!sent || !isMounted()) return false;
      if (!identical(forwardRequest, request)) return false;
      final remaining = request.messages.skip(1).toList(growable: false);
      if (remaining.isEmpty) {
        cancelForward();
        return true;
      }
      request = request.withMessages(remaining);
      forwardRequest = request;
      pendingForwards.value = request.messages;
    }
    cancelForward();
    return true;
  }

  Future<bool> _sendOneForward(
    CachedMessage optimistic,
    int sourceChatId,
  ) async {
    final link = optimistic.payload?['link'];
    final rawWireId = link is Map ? link['messageId'] : null;
    final wireId = rawWireId is int ? rawWireId : null;
    if (wireId == null) return false;
    try {
      final realId = await messagesModule.forwardMessage(
        _chatId,
        sourceChatId,
        wireId,
      );
      final sent = MessagesModule.reidentifyMessage(
        optimistic,
        realId.isNotEmpty ? realId : optimistic.id,
        status: 'sent',
      );
      if (isMounted()) {
        final index = chatController.indexOfId(optimistic.id);
        if (index != -1) {
          chatController.setMessageAt(index, sent);
          bumpMessages();
        }
      }
      await _syncForwardOutgoing(sent, removeId: optimistic.id);
      return true;
    } catch (_) {
      final index = chatController.indexOfId(optimistic.id);
      if (index != -1 && isMounted()) {
        chatController.removeMessageAt(index);
        bumpMessages();
      }
      try {
        await AppDatabase.deleteMessage(_myId, _chatId, optimistic.id);
      } catch (_) {}
      if (isMounted()) {
        Haptics.error();
        notify('Не удалось переслать');
      }
      return false;
    }
  }

  Future<void> sendMessage() async {
    if (forwardRequest == null) {
      await sendTextMessage();
      return;
    }
    if (_forwardSending || _myId == 0) return;
    _forwardSending = true;
    try {
      final forwarded = await sendForwardRequest();
      if (!forwarded || !isMounted()) return;
      if (messageController.text.trim().isEmpty) return;
      await sendTextMessage();
    } finally {
      _forwardSending = false;
    }
  }

  Future<void> sendTextMessage() async {
    final content = messageController.buildContent();
    final rawText = content.text;
    final text = rawText.trim();
    if (text.isEmpty || _myId == 0) return;

    if (AppCommands.current.value && text.startsWith('/')) {
      final command = CommandRegistry.instance.find(text);
      if (command == null) {
        messageController.clear();
        hasText.value = false;
        notify('ТАКОЙ КОМАНДЫ НЕТУ🚨🚨🚨');
        return;
      }
      final args = commandArgs(text);
      messageController.clear();
      hasText.value = false;
      unawaited(executeCommand(command, args));
      return;
    }

    if (chatOf()?.confirmBeforeSend ?? false) {
      final context = contextOf();
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showConfirmDialog(
        context,
        message: l10n.chatSendConfirmMessage,
        confirmLabel: l10n.chatSendConfirmAction,
      );
      if (!confirmed || !isMounted()) return;
    }

    final wireText = await encryptOutgoing(text);
    if (wireText == null || !isMounted()) return;
    final encrypted = wireText != text;

    final tempId = chatController.nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final online = api.state == SessionState.online;

    final reply = replyTo.value;
    final int? replyId = reply == null ? null : int.tryParse(reply.id);
    final int? replySrcChatId = replyId == null ? null : replySourceChatId;
    Map<String, dynamic>? replyPayload;
    if (reply != null && replyId != null) {
      replyPayload = {
        'link': {
          'type': 'REPLY',
          'chatId': replySrcChatId ?? _chatId,
          'message': {
            'id': replyId,
            'sender': reply.senderId,
            'text': reply.text,
            'time': reply.time,
            'attaches': reply.payload?['attaches'] ?? const [],
          },
        },
      };
    }
    replyTo.value = null;
    replySourceChatId = null;

    final elements = encrypted
        ? const <Map<String, dynamic>>[]
        : trimmedElements(content.elements, rawText, text);
    final Map<String, dynamic>? composedPayload =
        (replyPayload == null && elements.isEmpty)
        ? null
        : {...?replyPayload, if (elements.isNotEmpty) 'elements': elements};

    final composed = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: _chatId,
      senderId: _myId,
      text: wireText,
      time: now,
      status: online ? 'sending' : 'pending',
      payload: composedPayload,
    );
    if (encrypted) MessageDecryptionCache.instance.seed(tempId, text);

    hasText.value = false;
    setLastSentId(tempId);
    chatController.addMessage(composed);
    messageController.clear();
    if (!commentsMode && DraftStore.instance.get(_myId, _chatId) != null) {
      unawaited(DraftStore.instance.clear(_myId, _chatId));
    }
    bumpMessages();
    if (!commentsMode) {
      unawaited(chatController.persistOutgoing(composed));
      unawaited(
        chats.applyOutgoing(
          _myId,
          _chatId,
          messageId: tempId,
          time: now,
          text: wireText,
          status: composed.status ?? 'sending',
          elements: elements,
        ),
      );
    }

    // Instant tactile "whoosh" the moment the message leaves the composer,
    // not after the network round-trip — feedback must feel immediate.
    Haptics.send();

    scrollToBottom();
    checkPrankTrigger(composed);

    if (!online) return;

    try {
      final actualId = commentsMode
          ? await commentsModule.sendComment(
              _myId,
              _chatId,
              commentPostId!,
              wireText,
              replyToMessageId: replyId,
              elements: elements,
            )
          : await messagesModule.sendMessage(
              _myId,
              _chatId,
              wireText,
              replyToMessageId: replyId,
              replySourceChatId: replySrcChatId,
              elements: elements,
            );

      final index = chatController.indexOfId(tempId);
      if (index != -1 && isMounted()) {
        final sent = CachedMessage(
          id: actualId.isNotEmpty ? actualId : tempId,
          accountId: _myId,
          chatId: _chatId,
          senderId: _myId,
          text: wireText,
          time: now,
          status: 'sent',
          payload: composedPayload,
        );
        if (encrypted) {
          MessageDecryptionCache.instance.adopt(tempId, sent.id);
        }
        chatController.setMessageAt(index, sent);
        bumpMessages();
        if (!commentsMode) {
          unawaited(chatController.persistOutgoing(sent, removeId: tempId));
          unawaited(
            chats.applyOutgoing(
              _myId,
              _chatId,
              messageId: sent.id,
              time: now,
              text: wireText,
              status: 'sent',
              elements: elements,
            ),
          );
        }
      }

      if (!commentsMode && !isChatListed()) {
        unawaited(
          chats.refreshChats(api, [_chatId]).then((list) {
            if (!isMounted() || list.isEmpty) return;
            setChat(list.first);
            markChatListed();
            bumpMessages();
            syncOtherReadTime();
          }),
        );
      }
    } catch (e) {
      if (replySrcChatId != null) {
        logger.w('Cross-chat reply rejected: $e');
        final index = chatController.indexOfId(tempId);
        if (index != -1 && isMounted()) {
          chatController.removeMessageAt(index);
          bumpMessages();
        }
        unawaited(AppDatabase.deleteMessage(_myId, _chatId, tempId));
        if (isMounted()) {
          Haptics.error();
          notify(e.toString());
        }
        return;
      }
      final failed = isPermanentSendFailure(e);
      final status = failed ? 'error' : 'pending';
      if (failed) logger.w('Отправка отклонена сервером: $e');
      final index = chatController.indexOfId(tempId);
      if (index != -1 && isMounted()) {
        final queued = CachedMessage(
          id: tempId,
          accountId: _myId,
          chatId: _chatId,
          senderId: _myId,
          text: text,
          time: now,
          status: status,
          payload: composedPayload,
        );
        chatController.setMessageAt(index, queued);
        bumpMessages();
        if (!commentsMode) {
          unawaited(chatController.persistOutgoing(queued));
          unawaited(
            chats.applyOutgoing(
              _myId,
              _chatId,
              messageId: tempId,
              time: now,
              text: text,
              status: status,
              elements: elements,
            ),
          );
        }
      }
    }
  }

  CachedMessage _replaceMessage(
    int index, {
    String? id,
    String? text,
    String? status,
  }) {
    final old = chatController.messages[index];
    final updated = CachedMessage(
      id: id ?? old.id,
      accountId: old.accountId,
      chatId: old.chatId,
      senderId: old.senderId,
      text: text ?? old.text,
      time: old.time,
      status: status ?? old.status,
      payload: old.payload,
      attachments: old.attachments,
      isControl: old.isControl,
      editHistory: old.editHistory,
    );
    chatController.setMessageAt(index, updated);
    bumpMessages();
    return updated;
  }

  Future<String> postCommandMessage(String text) async {
    if (!isMounted() || _myId == 0) return '';
    final outgoing = await preparePluginOutgoingText(
      text,
      (plaintext) => encryptOutgoing(plaintext, notify: false),
    );
    if (!isMounted()) return '';
    final tempId = chatController.nextTempId();
    final now = DateTime.now().millisecondsSinceEpoch;
    final online = api.state == SessionState.online;
    final composed = CachedMessage(
      id: tempId,
      accountId: _myId,
      chatId: _chatId,
      senderId: _myId,
      text: outgoing.wireText,
      time: now,
      status: online ? 'sending' : 'pending',
    );
    if (outgoing.encrypted) {
      MessageDecryptionCache.instance.seed(tempId, outgoing.plaintext);
    }
    chatController.addMessage(composed);
    bumpMessages();
    scrollToBottom();
    unawaited(chatController.persistOutgoing(composed));
    unawaited(
      chats.applyOutgoing(
        _myId,
        _chatId,
        messageId: tempId,
        time: now,
        text: outgoing.wireText,
        status: composed.status ?? 'sending',
      ),
    );
    if (!online) return tempId;
    try {
      final actualId = await messagesModule.sendMessage(
        _myId,
        _chatId,
        outgoing.wireText,
      );
      final realId = actualId.isNotEmpty ? actualId : tempId;
      final i = chatController.indexOfId(tempId);
      if (i != -1) {
        final sent = _replaceMessage(i, id: realId, status: 'sent');
        if (outgoing.encrypted) {
          MessageDecryptionCache.instance.adopt(tempId, realId);
        }
        unawaited(chatController.persistOutgoing(sent, removeId: tempId));
        unawaited(
          chats.applyOutgoing(
            _myId,
            _chatId,
            messageId: realId,
            time: now,
            text: outgoing.wireText,
            status: 'sent',
          ),
        );
      }
      return realId;
    } catch (_) {
      return tempId;
    }
  }

  Future<void> updateCommandMessage(String id, String text) async {
    if (id.isEmpty) return;
    final outgoing = await preparePluginOutgoingText(
      text,
      (plaintext) => encryptOutgoing(plaintext, notify: false),
    );
    if (!isMounted()) return;
    final i = chatController.indexOfId(id);
    if (i != -1) {
      final edited = _replaceMessage(
        i,
        text: outgoing.wireText,
        status: 'EDITED',
      );
      if (outgoing.encrypted) {
        MessageDecryptionCache.instance.seed(id, outgoing.plaintext);
      }
      unawaited(chatController.persistOutgoing(edited));
    }
    if (!id.startsWith('temp_')) {
      await messagesModule.editMessage(_chatId, id, text: outgoing.wireText);
    }
  }
}
