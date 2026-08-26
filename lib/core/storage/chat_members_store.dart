import 'package:flutter/foundation.dart';

class ChatMembersStore {
  ChatMembersStore._();

  static final ChatMembersStore instance = ChatMembersStore._();

  final Map<int, int> _counts = {};
  final Map<int, ValueNotifier<int?>> _notifiers = {};

  ValueListenable<int?> listenable(int chatId) => _notifiers.putIfAbsent(
    chatId,
    () => ValueNotifier<int?>(_counts[chatId]),
  );

  int? count(int chatId) => _counts[chatId];

  void setCount(int chatId, int? count) {
    if (count == null || count < 0) return;
    if (_counts[chatId] == count) return;
    _counts[chatId] = count;
    _notifiers[chatId]?.value = count;
  }

  void adjust(int chatId, int delta) {
    final current = _counts[chatId];
    if (current == null || delta == 0) return;
    final next = current + delta;
    setCount(chatId, next < 0 ? 0 : next);
  }

  void applyChatPayload(Object? chat) {
    if (chat is! Map) return;
    final id = chat['id'];
    final count = chat['participantsCount'];
    if (id is int && count is int) setCount(id, count);
  }

  void clear() {
    _counts.clear();
    for (final notifier in _notifiers.values) {
      notifier.value = null;
    }
  }
}
