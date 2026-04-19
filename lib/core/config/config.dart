import 'package:shared_preferences/shared_preferences.dart';

abstract class ServerConfig {
  static const String defaultHost = 'api.oneme.ru';
  static const int defaultPort = 443;
  static const String prefHostKey = 'server_host_override';
  static const String prefPortKey = 'server_port_override';
  static const Duration pingInterval = Duration(seconds: 30);
  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxReconnectAttempts = 50;

  static Future<({String host, int port})> loadEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    final rawHost = prefs.getString(prefHostKey);
    final rawPort = prefs.getInt(prefPortKey);
    final host = (rawHost != null && rawHost.trim().isNotEmpty)
        ? rawHost.trim()
        : defaultHost;
    var port = defaultPort;
    if (rawPort != null && rawPort >= 1 && rawPort <= 65535) {
      port = rawPort;
    }
    return (host: host, port: port);
  }
}
