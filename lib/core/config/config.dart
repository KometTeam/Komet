import 'package:shared_preferences/shared_preferences.dart';

import 'build_profile.dart';

// #***! адрес сервера и тайминги
abstract class ServerConfig {
  static const String defaultHost = 'api2.oneme.ru';
  static const int defaultPort = 443;
  static const bool defaultTrustMincifryCa = true;
  static const String prefHostKey = 'server_host_override';
  static const String prefPortKey = 'server_port_override';
  static const String prefTrustMincifryKey = 'server_trust_mincifry_ca';
  static const Duration pingInterval = Duration(seconds: 10);
  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxReconnectAttempts = 50;

  // #***! в dev адрес можно переопределить, в релизе всегда дефолтный
  static Future<({String host, int port, bool trustMincifryCa})>
  loadEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHost = BuildProfile.devTools ? prefs.getString(prefHostKey) : null;
    final rawPort = BuildProfile.devTools ? prefs.getInt(prefPortKey) : null;
    final host = (rawHost != null && rawHost.trim().isNotEmpty)
        ? rawHost.trim()
        : defaultHost;
    var port = defaultPort;
    if (rawPort != null && rawPort >= 1 && rawPort <= 65535) {
      port = rawPort;
    }
    return (
      host: host,
      port: port,
      trustMincifryCa:
          prefs.getBool(prefTrustMincifryKey) ?? defaultTrustMincifryCa,
    );
  }
}
