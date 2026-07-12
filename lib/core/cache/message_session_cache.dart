import 'dart:collection';

import '../../backend/modules/messages.dart';

class CachedChatMessages {
  final List<CachedMessage> messages;
  final bool reachedStart;

  const CachedChatMessages(this.messages, this.reachedStart);
}

class MessageSessionCache {
  static const int _capacity = 24;

  static final LinkedHashMap<String, CachedChatMessages> _store =
      LinkedHashMap<String, CachedChatMessages>();

  static String _key(int accountId, int chatId) => '$accountId:$chatId';

  static CachedChatMessages? get(int accountId, int chatId) {
    final key = _key(accountId, chatId);
    final entry = _store.remove(key);
    if (entry == null) return null;
    _store[key] = entry;
    return entry;
  }

  static void save(
    int accountId,
    int chatId,
    List<CachedMessage> messages, {
    required bool reachedStart,
  }) {
    if (messages.isEmpty) return;
    final key = _key(accountId, chatId);
    _store.remove(key);
    _store[key] = CachedChatMessages(
      List<CachedMessage>.of(messages),
      reachedStart,
    );
    while (_store.length > _capacity) {
      _store.remove(_store.keys.first);
    }
  }

  static void remove(int accountId, int chatId) =>
      _store.remove(_key(accountId, chatId));

  static void clearAll() => _store.clear();
}
