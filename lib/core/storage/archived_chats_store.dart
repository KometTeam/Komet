import 'per_chat_json_store.dart';

class ArchivedChatsStore extends PerChatJsonStore<bool> {
  ArchivedChatsStore._()
    : super(
        prefsKey: 'archived_chats',
        fromJson: (raw) => raw == true ? true : null,
        toJson: (value) => value,
      );

  static final ArchivedChatsStore instance = ArchivedChatsStore._();

  bool isArchived(int accountId, int chatId) =>
      read(accountId, chatId) == true;

  Future<void> setArchived(int accountId, int chatId, bool archived) =>
      write(accountId, chatId, archived ? true : null);

  Set<int> archivedChatIds(int accountId) {
    if (accountId == 0) return const {};
    final prefix = '$accountId/';
    final ids = <int>{};
    for (final entry in allEntries) {
      if (entry.value != true) continue;
      if (!entry.key.startsWith(prefix)) continue;
      final id = int.tryParse(entry.key.substring(prefix.length));
      if (id != null) ids.add(id);
    }
    return ids;
  }
}
