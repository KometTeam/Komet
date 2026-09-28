import 'ios_release.dart';

// #***! откуда берём обновления, адрес зашит через --dart-define
abstract final class UpdateConfig {
  static const String baseUrl = String.fromEnvironment(
    'KOMET_UPDATE_BASE_URL',
    defaultValue: 'https://dl.komet.pw',
  );

  // #***! пустой адрес значит обновления выключены, на iOS их нет вовсе
  static bool get isConfigured =>
      IosRelease.selfUpdate && _normalizedBase.isNotEmpty;

  // #***! цепляем метку минуты иначе CDN отдаст старый манифест
  static Uri get manifestUri => Uri.parse(
    '$_normalizedBase/latest.json',
  ).replace(queryParameters: {'t': _cacheBuster});

  static String get downloadsPage => _normalizedBase;

  static String get _normalizedBase {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static String get _cacheBuster =>
      (DateTime.now().millisecondsSinceEpoch ~/ 60000).toString();
}
