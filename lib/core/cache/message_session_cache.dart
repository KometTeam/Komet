import '../../backend/modules/messages.dart';

class CachedChatMessages {
  final List<CachedMessage> messages;
  final bool reachedStart;

  const CachedChatMessages(this.messages, this.reachedStart);
}

class MessageSessionCache {
  static final Map<String, CachedChatMessages> _store = {};

  static String _key(int accountId, int chatId) => '$accountId:$chatId';

  static CachedChatMessages? get(int accountId, int chatId) =>
      _store[_key(accountId, chatId)];

  static void save(
    int accountId,
    int chatId,
    List<CachedMessage> messages, {
    required bool reachedStart,
  }) {
    if (messages.isEmpty) return;
    _store[_key(accountId, chatId)] = CachedChatMessages(
      List<CachedMessage>.of(messages),
      reachedStart,
    );
  }

  static void remove(int accountId, int chatId) =>
      _store.remove(_key(accountId, chatId));

  static void clearAll() => _store.clear();
}
