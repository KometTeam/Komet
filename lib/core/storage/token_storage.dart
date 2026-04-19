import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _tokenPrefix = 'auth_token_';
  static const _activeAccountKey = 'active_account_id';

  static Future<void> saveToken(String token, int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_tokenPrefix$accountId', token);
  }

  static Future<String?> readToken(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_tokenPrefix$accountId');
  }

  static Future<void> deleteToken(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_tokenPrefix$accountId');
  }

  static Future<void> setActiveAccount(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeAccountKey, accountId.toString());
  }

  static Future<int?> getActiveAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_activeAccountKey);
    return val != null ? int.tryParse(val) : null;
  }

  static Future<String?> readActiveToken() async {
    final id = await getActiveAccountId();
    if (id == null) return null;
    return readToken(id);
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
