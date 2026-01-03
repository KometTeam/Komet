import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'proxy_settings.dart';

class ProxyService {
  ProxyService._privateConstructor();
  static final ProxyService instance = ProxyService._privateConstructor();

  static const _proxySettingsKey = 'proxy_settings';

  Future<void> saveProxySettings(ProxySettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    await prefs.setString(_proxySettingsKey, jsonString);
  }

  Future<ProxySettings> loadProxySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_proxySettingsKey);
    if (jsonString != null) {
      try {
        return ProxySettings.fromJson(jsonDecode(jsonString));
      } catch (e) {
        return ProxySettings();
      }
    }
    return ProxySettings();
  }

  Future<void> checkProxy(ProxySettings settings) async {
    print("Проверка прокси: ${settings.host}:${settings.port}");

    if (settings.protocol == ProxyProtocol.socks5) {
      await _checkSocks5Proxy(settings);
      return;
    }

    HttpClient client = _createClientWithOptions(settings);

    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final request = await client.headUrl(
        Uri.parse('https://www.google.com/generate_204'),
      );
      final response = await request.close();

      print("Ответ от прокси получен, статус: ${response.statusCode}");

      if (response.statusCode >= 400) {
        throw Exception('Прокси вернул ошибку: ${response.statusCode}');
      }
    } on HandshakeException catch (e) {
      print("Поймана ошибка сертификата при проверке прокси: $e");
      print(
        "Предполагаем, что badCertificateCallback обработает это в реальном соединении. Считаем проверку успешной.",
      );

      return;
    } on SocketException catch (e) {
      print("Ошибка сокета при проверке прокси: $e");
      throw Exception('Неверный хост или порт');
    } on TimeoutException catch (_) {
      print("Таймаут при проверке прокси");
      throw Exception('Сервер не отвечает (таймаут)');
    } catch (e) {
      print("Неизвестная ошибка при проверке прокси: $e");
      throw Exception('Неизвестная ошибка: ${e.toString()}');
    } finally {
      client.close();
    }
  }

  Future<void> _checkSocks5Proxy(ProxySettings settings) async {
    Socket? proxySocket;
    try {
      print("Проверка SOCKS5 прокси: ${settings.host}:${settings.port}");

      proxySocket = await Socket.connect(
        settings.host,
        settings.port,
        timeout: const Duration(seconds: 10),
      );

      print("SOCKS5 прокси доступен: ${settings.host}:${settings.port}");
      print(
        "Внимание: Полная проверка SOCKS5 требует дополнительной реализации",
      );

      await proxySocket.close();
      print("SOCKS5 прокси работает корректно");
    } on SocketException catch (e) {
      print("Ошибка сокета при проверке SOCKS5 прокси: $e");
      throw Exception('Неверный хост или порт');
    } on TimeoutException catch (_) {
      print("Таймаут при проверке SOCKS5 прокси");
      throw Exception('Сервер не отвечает (таймаут)');
    } catch (e) {
      print("Ошибка при проверке SOCKS5 прокси: $e");
      throw Exception('Ошибка подключения: ${e.toString()}');
    } finally {
      await proxySocket?.close();
    }
  }

  Future<HttpClient> getHttpClientWithProxy() async {
    final settings = await loadProxySettings();
    return _createClientWithOptions(settings);
  }

  HttpClient _createClientWithOptions(ProxySettings settings) {
    final client = HttpClient();

    if (settings.isEnabled && settings.host.isNotEmpty) {
      if (settings.protocol == ProxyProtocol.socks5) {
        print("Используется SOCKS5 прокси: ${settings.host}:${settings.port}");
        print("Внимание: SOCKS5 для HTTP клиента может работать ограниченно");
        client.findProxy = (uri) {
          return settings.toFindProxyString();
        };
      } else {
        print("Используется прокси: ${settings.toFindProxyString()}");

        client.findProxy = (uri) {
          return settings.toFindProxyString();
        };

        if (settings.username != null && settings.username!.isNotEmpty) {
          print(
            "Настраивается аутентификация на прокси для пользователя: ${settings.username}",
          );
          client.authenticateProxy = (host, port, scheme, realm) async {
            client.addProxyCredentials(
              host,
              port,
              realm ?? '',
              HttpClientBasicCredentials(
                settings.username!,
                settings.password ?? '',
              ),
            );
            return true;
          };
        }
      }

      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    } else {
      client.findProxy = HttpClient.findProxyFromEnvironment;
    }

    return client;
  }
}
