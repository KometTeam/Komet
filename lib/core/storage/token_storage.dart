import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _tokenPrefix = 'auth_token_';
  static const _activeAccountKey = 'active_account_id';

  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  static Future<void> writeSecure(String key, String value) async {
    await _secure.write(key: key, value: value);
  }

  static Future<String?> readSecure(String key) async {
    return _secure.read(key: key);
  }

  static Future<void> deleteSecure(String key) async {
    await _secure.delete(key: key);
  }

  static Future<void> saveToken(String token, int accountId) async {
    await _secure.write(key: '$_tokenPrefix$accountId', value: token);
  }

  static Future<String?> readToken(int accountId) async {
    final key = '$_tokenPrefix$accountId';
    final secured = await _secure.read(key: key);
    if (secured != null) return secured;

    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy != null) {
      await _secure.write(key: key, value: legacy);
      await prefs.remove(key);
      return legacy;
    }
    return null;
  }

  static Future<void> deleteToken(int accountId) async {
    final key = '$_tokenPrefix$accountId';
    await _secure.delete(key: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  static Future<void> setActiveAccount(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeAccountKey, accountId.toString());
  }

  static Future<void> clearActiveAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeAccountKey);
  }

  static Future<int?> getActiveAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_activeAccountKey);
    return val != null ? int.tryParse(val) : null;
  }

  static Future<String?> readActiveToken() async {
    final id = await getActiveAccountId();
    if (id == null) return null;
    return await readToken(id);
  }

  static Future<void> deleteAccount(int accountId) async {
    await deleteToken(accountId);
    final activeId = await getActiveAccountId();
    if (activeId == accountId) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeAccountKey);
    }
  }
}
