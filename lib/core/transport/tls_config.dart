import 'package:kolibri/kolibri.dart' show setTrustMincifryCa;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/config.dart';

abstract class TlsConfig {
  static const String prefKey = 'dev_tls_insecure';

  static Future<void> applyMincifryTrust() async {
    final prefs = await SharedPreferences.getInstance();
    setTrustMincifryCa(
      enabled:
          prefs.getBool(ServerConfig.prefTrustMincifryKey) ??
          ServerConfig.defaultTrustMincifryCa,
    );
  }

  static Future<bool> isInsecureAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  static Future<void> setInsecureAllowed(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }
}
