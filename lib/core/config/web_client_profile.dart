// #***! веб-клиент MAX: сессия живёт на нашем сокете, но хэндшейк уходит как из
// браузера. Веб всегда шлёт код по SMS (сокет — как повезёт), поэтому это
// единственный способ гарантированно получить SMS вместо пуш-кода.
// Пока один профиль; когда понадобится — сюда ляжет набор как в device_presets.
class WebClientProfile {
  final String appVersion;
  final String deviceName;
  final String osVersion;
  final String screen;
  final String headerUserAgent;

  const WebClientProfile({
    required this.appVersion,
    required this.deviceName,
    required this.osVersion,
    required this.screen,
    required this.headerUserAgent,
  });

  // #***! в веб-хэндшейке этих полей нет вовсе: ядро опускает arch при пустой
  // строке, buildNumber и clientSessionId при нуле, mt_instanceid при пустом
  static const String deviceType = 'WEB';
  static const String pushDeviceType = 'WEBPUSH';
  static const String arch = '';
  static const int buildNumber = 0;
  static const String instanceId = '';
  static const int clientSessionId = 0;
  static const bool isPwa = false;

  static const WebClientProfile firefoxLinux = WebClientProfile(
    appVersion: '26.9.6',
    deviceName: 'Firefox',
    osVersion: 'Linux',
    screen: '1080x1920 1.0x',
    headerUserAgent:
        'Mozilla/5.0 (X11; Linux x86_64; rv:153.0) Gecko/20100101 Firefox/153.0',
  );

  static const WebClientProfile defaultProfile = firefoxLinux;
}
