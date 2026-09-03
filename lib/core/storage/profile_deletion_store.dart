import 'package:shared_preferences/shared_preferences.dart';

abstract final class ProfileDeletionStore {
  static String _key(int accountId) => 'profile_delete_at_$accountId';

  static Future<DateTime?> scheduledAt(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_key(accountId)) ?? 0;
    if (millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> save(int accountId, int millis) async {
    final prefs = await SharedPreferences.getInstance();
    if (millis > 0) {
      await prefs.setInt(_key(accountId), millis);
    } else {
      await prefs.remove(_key(accountId));
    }
  }

  static Future<void> clear(int accountId) => save(accountId, 0);
}
