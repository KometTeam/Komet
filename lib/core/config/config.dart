import 'package:shared_preferences/shared_preferences.dart';

import 'build_profile.dart';

// #***! адрес сервера и тайминги
abstract class ServerConfig {
  static const String defaultHost = 'api2.oneme.ru';
  static const List<String> presetHosts = [
    defaultHost,
    'api-test.oneme.ru',
    'api-tg.oneme.ru',
    'api-test2.oneme.ru',
    'api-test3.oneme.ru',
  ];
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
    if (isValidPort(rawPort)) port = rawPort!;
    return (
      host: host,
      port: port,
      trustMincifryCa:
          prefs.getBool(prefTrustMincifryKey) ?? defaultTrustMincifryCa,
    );
  }

  static bool isValidPort(int? port) =>
      port != null && port >= 1 && port <= 65535;

  static Future<void> saveEndpoint({
    required String host,
    required int port,
    required bool trustMincifryCa,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefHostKey, host);
    await prefs.setInt(prefPortKey, port);
    await prefs.setBool(prefTrustMincifryKey, trustMincifryCa);
  }

  static Future<void> resetEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefHostKey);
    await prefs.remove(prefPortKey);
    await prefs.remove(prefTrustMincifryKey);
  }
}
