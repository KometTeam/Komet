import 'per_chat_json_store.dart';
import 'token_storage.dart';

// #***! шифрование чата, флаг в prefs ключ в защищённом хранилище
class ChatEncryptionStore extends PerChatJsonStore<bool> {
  ChatEncryptionStore._()
    : super(
        prefsKey: 'chat_encryption',
        fromJson: (raw) => raw == true ? true : null,
        toJson: (value) => value,
      );

  static final ChatEncryptionStore instance = ChatEncryptionStore._();

  static const String _keyPrefix = 'chat_encryption_key';

  bool isEnabled(int accountId, int chatId) => read(accountId, chatId) == true;

  Future<void> setEnabled(int accountId, int chatId, bool enabled) =>
      write(accountId, chatId, enabled ? true : null);

  // #***! ключ в обычные prefs не попадает никогда
  Future<String?> readKey(int accountId, int chatId) async {
    if (accountId == 0) return null;
    return TokenStorage.readSecure(_secureKey(accountId, chatId));
  }

  Future<void> writeKey(int accountId, int chatId, String key) async {
    if (accountId == 0) return;
    await TokenStorage.writeSecure(_secureKey(accountId, chatId), key);
  }

  Future<void> deleteKey(int accountId, int chatId) async {
    if (accountId == 0) return;
    await TokenStorage.deleteSecure(_secureKey(accountId, chatId));
  }

  String _secureKey(int accountId, int chatId) =>
      '${_keyPrefix}_${accountId}_$chatId';
}
