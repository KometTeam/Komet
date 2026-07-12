import 'dart:async';

import 'package:flutter/foundation.dart';

enum ChatActivity { typing, sticker }

extension ChatActivityLabel on ChatActivity {
  String get label => switch (this) {
    ChatActivity.typing => 'Печатает...',
    ChatActivity.sticker => 'Выбирает стикер...',
  };
}

ChatActivity chatActivityFromType(dynamic type) =>
    type == 'STICKER' ? ChatActivity.sticker : ChatActivity.typing;

class ChatActivityStore {
  ChatActivityStore._();

  static final ChatActivityStore instance = ChatActivityStore._();

  static const Duration _ttl = Duration(seconds: 6);

  final Map<int, Map<int, ChatActivity>> _users = {};
  final Map<int, Map<int, Timer>> _timers = {};
  final Map<int, ValueNotifier<ChatActivity?>> _notifiers = {};

  ValueListenable<ChatActivity?> listenable(int chatId) =>
      _notifiers.putIfAbsent(
        chatId,
        () => ValueNotifier<ChatActivity?>(_current(chatId)),
      );

  ChatActivity? activity(int chatId) => _current(chatId);

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

  ChatActivity? _current(int chatId) {
    final users = _users[chatId];
    if (users == null || users.isEmpty) return null;
    for (final activity in users.values) {
      if (activity == ChatActivity.typing) return ChatActivity.typing;
    }
    return ChatActivity.sticker;
  }

  void _sync(int chatId) {
    _notifiers[chatId]?.value = _current(chatId);
  }
}
