import 'persisted_setting.dart';

class AppBadge {
  static final enabled = _flag('badge_enabled', true);
  static final includeMuted = _flag('badge_include_muted', false);
  static final countMessages = _flag('badge_count_messages', true);

  static Future<void> load() =>
      Future.wait([enabled.load(), includeMuted.load(), countMessages.load()]);

  static PersistedSetting<bool> _flag(String key, bool fallback) =>
      PersistedSetting<bool>(
        prefKey: key,
        defaultValue: fallback,
        read: (prefs, key) => prefs.getBool(key),
        write: (prefs, key, value) async {
          await prefs.setBool(key, value);
        },
      );
}
