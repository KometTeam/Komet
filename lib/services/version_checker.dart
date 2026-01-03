import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gwid/utils/spoofing_service.dart';

class VersionChecker {
  static const String _url = 'https://www.rustore.ru/catalog/app/ru.oneme.app';
  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  static Future<String> getLatestVersion() async {
    try {
      final spoofData = await SpoofingService.getSpoofedSessionData();
      final userAgent = spoofData?['user_agent'] ?? _defaultUserAgent;

      final html = await _fetchPage(_url, userAgent);

      final version = _extractVersionFromJsonLd(html);

      if (version != null) {
        print('[SUCCESS] Версия из RuStore: $version');
        return version;
      }

      throw Exception('Ключ softwareVersion не найден в JSON-LD');
    } catch (e) {
      throw Exception('Не удалось проверить версию: $e');
    }
  }

  static Future<String> _fetchPage(String url, String userAgent) async {
    print('[INFO] Запрос к $url c User-Agent: $userAgent');

    final response = await http
        .get(Uri.parse(url), headers: {'User-Agent': userAgent})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Ошибка загрузки $url (${response.statusCode})');
    }

    return response.body;
  }

  static String? _extractVersionFromJsonLd(String html) {
    final scriptRegex = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
      caseSensitive: false,
      dotAll: true,
    );

    final match = scriptRegex.firstMatch(html);
    if (match == null) {
      print('[WARN] Тег JSON-LD не найден на странице');
      return null;
    }

    final jsonContent = match.group(1);
    if (jsonContent == null) return null;

    try {
      final jsonData = jsonDecode(jsonContent);
      Map<String, dynamic>? appInfo;

      if (jsonData is Map<String, dynamic>) {
        if (jsonData.containsKey('@graph') && jsonData['@graph'] is List) {
          final graph = jsonData['@graph'] as List;

          final foundItem = graph.firstWhere(
            (item) => item['@type'] == 'SoftwareApplication',
            orElse: () => null,
          );

          if (foundItem != null) {
            appInfo = foundItem as Map<String, dynamic>;
          }
        } else if (jsonData['@type'] == 'SoftwareApplication') {
          appInfo = jsonData;
        }
      }

      if (appInfo != null) {
        return appInfo['softwareVersion']?.toString();
      }

      print('[WARN] Объект SoftwareApplication не найден в JSON данных');
    } catch (e) {
      print('[ERROR] Ошибка парсинга JSON: $e');
    }

    return null;
  }
}
