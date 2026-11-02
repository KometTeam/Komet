import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../utils/device_locale.dart';
import 'persisted_setting.dart';

class AppLanguage {
  AppLanguage._();

  static const prefKey = 'app_locale';
  static const serverPrefKey = 'app_server_language';

  static final ValueNotifier<Locale> current = ValueNotifier(
    const Locale(defaultLanguageCode),
  );

  static final _appliesToServer = PersistedSetting<bool>(
    prefKey: serverPrefKey,
    defaultValue: false,
    read: (prefs, key) => prefs.getBool(key),
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static ValueNotifier<bool> get appliesToServer => _appliesToServer.current;

  static String? get serverLanguageCode =>
      appliesToServer.value ? current.value.languageCode : null;

  static bool isSupported(String code) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == code);

  static Locale resolve({String? saved, required String platformCode}) {
    if (saved != null && isSupported(saved)) return Locale(saved);
    if (isSupported(platformCode)) return Locale(platformCode);
    return const Locale(defaultLanguageCode);
  }

  static Future<Locale> load() async {
    final prefs = await SharedPreferences.getInstance();
    final locale = resolve(
      saved: prefs.getString(prefKey),
      platformCode:
          WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    current.value = locale;
    await _appliesToServer.load();
    return locale;
  }

  static Future<bool> save(Locale locale) async {
    if (!isSupported(locale.languageCode)) return false;
    current.value = Locale(locale.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, locale.languageCode);
    return true;
  }

  static Future<void> setAppliesToServer(bool value) =>
      _appliesToServer.save(value);
}
