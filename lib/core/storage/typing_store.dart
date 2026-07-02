import 'dart:async';

import 'package:flutter/foundation.dart';

class TypingStore {
  TypingStore._();

  static final TypingStore instance = TypingStore._();

  static const Duration _ttl = Duration(seconds: 6);

  final Map<int, Set<int>> _users = {};
  final Map<int, Map<int, Timer>> _timers = {};
  final Map<int, ValueNotifier<bool>> _notifiers = {};

  ValueListenable<bool> listenable(int chatId) => _notifiers.putIfAbsent(
    chatId,
    () => ValueNotifier<bool>(_users[chatId]?.isNotEmpty ?? false),
  );

  bool isTyping(int chatId) => _users[chatId]?.isNotEmpty ?? false;

  void markTyping(int chatId, int userId) {
    final timers = _timers.putIfAbsent(chatId, () => <int, Timer>{});
    timers[userId]?.cancel();
    timers[userId] = Timer(_ttl, () => _remove(chatId, userId));
    _users.putIfAbsent(chatId, () => <int>{}).add(userId);
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

  void _sync(int chatId) {
    _notifiers[chatId]?.value = _users[chatId]?.isNotEmpty ?? false;
  }
}
