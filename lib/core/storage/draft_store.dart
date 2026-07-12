import 'per_chat_json_store.dart';

class DraftStore extends PerChatJsonStore<String> {
  DraftStore._()
    : super(
        prefsKey: 'chat_drafts',
        fromJson: (raw) => raw is String ? raw : null,
        toJson: (value) => value,
      );

  static final DraftStore instance = DraftStore._();

  String? get(int accountId, int chatId) => read(accountId, chatId);

  Future<void> set(int accountId, int chatId, String text) async {
    if (accountId == 0) return;
    final current = read(accountId, chatId);
    if (text.trim().isEmpty) {
      if (current == null) return;
      await write(accountId, chatId, null);
    } else {
      if (current == text) return;
      await write(accountId, chatId, text);
    }
  }

  Future<void> clear(int accountId, int chatId) => set(accountId, chatId, '');
}
