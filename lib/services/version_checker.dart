import 'dart:convert';
import 'package:http/http.dart' as http;

class VersionChecker {
  static const String _packageName = 'ru.oneme.app';
  static const String _apiUrl =
      'https://backapi.rustore.ru/applicationData/overallInfo/$_packageName';

  static Future<String> getLatestVersion() async {
    final info = await getLatestVersionInfo();
    final version = info['versionName'] as String;
    print('[SUCCESS] Версия из RuStore API: $version');
    return version;
  }

  static Future<Map<String, dynamic>> getLatestVersionInfo() async {
    try {
      print('[INFO] Запрос к RuStore API: $_apiUrl');

      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Ошибка API (${response.statusCode})');
      }

      final data = jsonDecode(response.body);

      if (data['code'] != 'OK') {
        throw Exception('API вернул ошибку: ${data['code']}');
      }

      final body = data['body'];
      final versionName = body['versionName']?.toString() ?? '25.21.3';
      final versionCode = body['versionCode'] is int
          ? body['versionCode']
          : int.tryParse(body['versionCode']?.toString() ?? '0') ?? 0;

      print('[SUCCESS] Version: $versionName, Build: $versionCode');

      return {'versionName': versionName, 'versionCode': versionCode};
    } catch (e) {
      throw Exception('Не удалось получить информацию о версии: $e');
    }
  }

  static Future<int> getLatestBuildNumber() async {
    final info = await getLatestVersionInfo();
    return info['versionCode'] as int;
  }
}
