import 'dart:async';

import 'package:flutter/foundation.dart';

// #***! что делает собеседник, печатает или выбирает стикер
enum ChatActivity { typing, sticker }

extension ChatActivityLabel on ChatActivity {
  String get label => switch (this) {
    ChatActivity.typing => 'Печатает...',
    ChatActivity.sticker => 'Выбирает стикер...',
  };
}

// #***! тип строкой, всё кроме STICKER считаем печатью
ChatActivity chatActivityFromType(dynamic type) =>
    type == 'STICKER' ? ChatActivity.sticker : ChatActivity.typing;

// #***! что происходит и кто этим занят
class ChatActivitySnapshot {
  const ChatActivitySnapshot({required this.activity, required this.userIds});

  final ChatActivity activity;
  final List<int> userIds;

  String get label => activity.label;

  // #***! сравниваем по значению иначе шапка перерисовывается на каждый пуш
  @override
  bool operator ==(Object other) =>
      other is ChatActivitySnapshot &&
      other.activity == activity &&
      listEquals(other.userIds, userIds);

  @override
  int get hashCode => Object.hash(activity, Object.hashAll(userIds));
}

// #***! печатает в памяти, само истекает
class ChatActivityStore {
  ChatActivityStore._();

  static final ChatActivityStore instance = ChatActivityStore._();

  // #***! сервер не шлёт перестал печатать, снимаем сами через 6 сек
  static const Duration _ttl = Duration(seconds: 6);

  final Map<int, Map<int, ChatActivity>> _users = {};
  final Map<int, Map<int, Timer>> _timers = {};
  final Map<int, ValueNotifier<ChatActivitySnapshot?>> _notifiers = {};

  ValueListenable<ChatActivitySnapshot?> listenable(int chatId) =>
      _notifiers.putIfAbsent(
        chatId,
        () => ValueNotifier<ChatActivitySnapshot?>(_current(chatId)),
      );

  ChatActivitySnapshot? snapshot(int chatId) => _current(chatId);

  ChatActivity? activity(int chatId) => _current(chatId)?.activity;

  // #***! новый пуш продлевает таймер
  void mark(int chatId, int userId, ChatActivity activity) {
    final timers = _timers.putIfAbsent(chatId, () => <int, Timer>{});
    timers[userId]?.cancel();
    timers[userId] = Timer(_ttl, () => _remove(chatId, userId));
    _users.putIfAbsent(chatId, () => <int, ChatActivity>{})[userId] = activity;
    _sync(chatId);
  }

  void clearUser(int chatId, int userId) => _remove(chatId, userId);

  void clearChat(int chatId) {
    final timers = _timers.remove(chatId);
    if (timers != null) {
      for (final timer in timers.values) {
        timer.cancel();
      }
    }
    _users.remove(chatId);
    _sync(chatId);
  }

  void _remove(int chatId, int userId) {
    _timers[chatId]?.remove(userId)?.cancel();
    final users = _users[chatId];
    if (users != null) {
      users.remove(userId);
      if (users.isEmpty) _users.remove(chatId);
    }
    _sync(chatId);
  }

  // #***! кто то печатает, показываем печать она важнее стикера
  ChatActivitySnapshot? _current(int chatId) {
    final users = _users[chatId];
    if (users == null || users.isEmpty) return null;
    final leading = users.values.contains(ChatActivity.typing)
        ? ChatActivity.typing
        : ChatActivity.sticker;
    final ids = <int>[];
    users.forEach((userId, activity) {
      if (activity == leading) ids.add(userId);
    });
    return ChatActivitySnapshot(activity: leading, userIds: ids);
  }

  void _sync(int chatId) {
    _notifiers[chatId]?.value = _current(chatId);
  }
}
