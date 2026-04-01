import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _tokenPrefix = 'auth_token_';
  static const _activeAccountKey = 'active_account_id';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveToken(String token, int accountId) =>
      _storage.write(key: '$_tokenPrefix$accountId', value: token);

  static Future<String?> readToken(int accountId) =>
      _storage.read(key: '$_tokenPrefix$accountId');

  static Future<void> deleteToken(int accountId) =>
      _storage.delete(key: '$_tokenPrefix$accountId');

  static Future<void> setActiveAccount(int accountId) =>
      _storage.write(key: _activeAccountKey, value: accountId.toString());

  static Future<int?> getActiveAccountId() async {
    final val = await _storage.read(key: _activeAccountKey);
    return val != null ? int.tryParse(val) : null;
  }

  static Future<String?> readActiveToken() async {
    final id = await getActiveAccountId();
    if (id == null) return null;
    return readToken(id);
  }

  /// Удаляет токен аккаунта и, если он был активным, сбрасывает активный аккаунт.
  static Future<void> deleteAccount(int accountId) async {
    await deleteToken(accountId);
    final activeId = await getActiveAccountId();
    if (activeId == accountId) {
      await _storage.delete(key: _activeAccountKey);
    }
  }
}
