import 'dart:async';

import 'messages.dart';

typedef RestoredMessages = ({int chatId, List<CachedMessage> messages});

class PendingMessageDeletions {
  PendingMessageDeletions._();

  static final PendingMessageDeletions instance = PendingMessageDeletions._();

  final Map<int, Map<String, CachedMessage>> _byChat = {};
  final StreamController<RestoredMessages> _restored =
      StreamController.broadcast(sync: true);

  Stream<RestoredMessages> get restored => _restored.stream;

  bool isPending(int chatId, String messageId) =>
      _byChat[chatId]?.containsKey(messageId) ?? false;

  void hold(int chatId, Iterable<CachedMessage> messages) {
    final held = _byChat.putIfAbsent(chatId, () => {});
    for (final message in messages) {
      held[message.id] = message;
    }
  }

  void restore(int chatId, Iterable<String> messageIds) {
    final messages = _take(chatId, messageIds);
    if (messages.isEmpty) return;
    _restored.add((chatId: chatId, messages: messages));
  }

  void drop(int chatId, Iterable<String> messageIds) =>
      _take(chatId, messageIds);

  List<CachedMessage> _take(int chatId, Iterable<String> messageIds) {
    final held = _byChat[chatId];
    if (held == null) return const [];
    final taken = [
      for (final id in messageIds) ?held.remove(id),
    ];
    if (held.isEmpty) _byChat.remove(chatId);
    return taken;
  }
}
