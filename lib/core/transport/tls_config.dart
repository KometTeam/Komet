import 'package:kolibri/kolibri.dart' show setTrustMincifryCa;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/build_profile.dart';
import '../config/config.dart';

// #***! TLS, доверие к CA минцифры и dev режим
abstract class TlsConfig {
  static const String prefKey = 'dev_tls_insecure';

  // #***! флаг доверия в раст
  static Future<void> applyMincifryTrust() async {
    final prefs = await SharedPreferences.getInstance();
    setTrustMincifryCa(
      enabled:
          prefs.getBool(ServerConfig.prefTrustMincifryKey) ??
          ServerConfig.defaultTrustMincifryCa,
    );
  }

  // #***! только в dev сборке, в релизе false
  static Future<bool> isInsecureAllowed() async {
    if (!BuildProfile.insecureTransport) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  static Future<void> setInsecureAllowed(bool value) async {
    if (!BuildProfile.insecureTransport) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }
}
