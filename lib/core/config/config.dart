abstract class ServerConfig {
  static const String host = 'api.oneme.ru';
  static const int port = 443;
  static const Duration pingInterval = Duration(seconds: 30);
  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxReconnectAttempts = 50;
}
