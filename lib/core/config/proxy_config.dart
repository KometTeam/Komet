import 'package:shared_preferences/shared_preferences.dart';

import '../storage/token_storage.dart';

enum ProxyType { none, socks5, httpConnect }

class ProxySettings {
  final ProxyType type;
  final String host;
  final int port;
  final String? username;
  final String? password;

  const ProxySettings({
    this.type = ProxyType.none,
    this.host = '',
    this.port = 1080,
    this.username,
    this.password,
  });

  bool get isEnabled => type != ProxyType.none && host.isNotEmpty;

  bool get hasCredentials =>
      username != null &&
      username!.isNotEmpty &&
      password != null &&
      password!.isNotEmpty;
}

abstract class ProxyConfig {
  static const String _prefType = 'proxy_type';
  static const String _prefHost = 'proxy_host';
  static const String _prefPort = 'proxy_port';
  static const String _prefUsername = 'proxy_username';
  static const String _prefPassword = 'proxy_password';

  static Future<ProxySettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final typeIndex = prefs.getInt(_prefType) ?? 0;
    final host = prefs.getString(_prefHost) ?? '';
    final port = prefs.getInt(_prefPort) ?? 1080;
    var username = await TokenStorage.readSecure(_prefUsername);
    var password = await TokenStorage.readSecure(_prefPassword);
    final legacyUsername = prefs.getString(_prefUsername);
    final legacyPassword = prefs.getString(_prefPassword);
    if (username == null && legacyUsername != null) {
      username = legacyUsername;
      await TokenStorage.writeSecure(_prefUsername, legacyUsername);
    }
    if (password == null && legacyPassword != null) {
      password = legacyPassword;
      await TokenStorage.writeSecure(_prefPassword, legacyPassword);
    }
    if (legacyUsername != null || legacyPassword != null) {
      await prefs.remove(_prefUsername);
      await prefs.remove(_prefPassword);
    }
    return ProxySettings(
      type: ProxyType.values[typeIndex.clamp(0, ProxyType.values.length - 1)],
      host: host,
      port: port,
      username: username,
      password: password,
    );
  }

  static Future<void> save(ProxySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefType, settings.type.index);
    await prefs.setString(_prefHost, settings.host);
    await prefs.setInt(_prefPort, settings.port);
    await prefs.remove(_prefUsername);
    await prefs.remove(_prefPassword);
    if (settings.username != null) {
      await TokenStorage.writeSecure(_prefUsername, settings.username!);
    } else {
      await TokenStorage.deleteSecure(_prefUsername);
    }
    if (settings.password != null) {
      await TokenStorage.writeSecure(_prefPassword, settings.password!);
    } else {
      await TokenStorage.deleteSecure(_prefPassword);
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefType);
    await prefs.remove(_prefHost);
    await prefs.remove(_prefPort);
    await prefs.remove(_prefUsername);
    await prefs.remove(_prefPassword);
    await TokenStorage.deleteSecure(_prefUsername);
    await TokenStorage.deleteSecure(_prefPassword);
  }
}
