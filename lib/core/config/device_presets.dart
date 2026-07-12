class DevicePreset {
  final String deviceType;
  final String userAgent;
  final String deviceName;
  final String osVersion;
  final String screen;
  final String timezone;
  final String locale;

  DevicePreset({
    required this.deviceType,
    required this.userAgent,
    required this.deviceName,
    required this.osVersion,
    required this.screen,
    required this.timezone,
    required this.locale,
  });
}

final List<DevicePreset> devicePresets = [
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Samsung Galaxy S24 Ultra',
    osVersion: 'Android 14',
    screen: 'xxhdpi 450dpi 1440x3120',
    timezone: 'Europe/Berlin',
    locale: 'de-DE',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    deviceName: 'Google Pixel 8 Pro',
    osVersion: 'Android 14',
    screen: 'xxhdpi 430dpi 1344x2992',
    timezone: 'America/New_York',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; 23021RAA2Y) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    deviceName: 'Xiaomi 13 Pro',
    osVersion: 'Android 13',
    screen: 'xxhdpi 460dpi 1440x3200',
    timezone: 'Asia/Shanghai',
    locale: 'zh-CN',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; CPH2521) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'OnePlus 12',
    osVersion: 'Android 14',
    screen: 'xxhdpi 450dpi 1440x3168',
    timezone: 'Asia/Kolkata',
    locale: 'en-IN',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; SM-G998B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    deviceName: 'Samsung Galaxy S21 Ultra',
    osVersion: 'Android 13',
    screen: 'xxhdpi 460dpi 1440x3200',
    timezone: 'Europe/London',
    locale: 'en-GB',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    deviceName: 'Google Pixel 6',
    osVersion: 'Android 12',
    screen: 'xxhdpi 420dpi 1080x2400',
    timezone: 'America/Chicago',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; RMX3371) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    deviceName: 'Realme GT Master Edition',
    osVersion: 'Android 13',
    screen: 'xxhdpi 400dpi 1080x2400',
    timezone: 'Asia/Dubai',
    locale: 'ar-AE',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 11; M2101K6G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Mobile Safari/537.36',
    deviceName: 'Poco F3',
    osVersion: 'Android 11',
    screen: 'xxhdpi 420dpi 1080x2400',
    timezone: 'Europe/Madrid',
    locale: 'es-ES',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; SO-51D) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    deviceName: 'Sony Xperia 1 V',
    osVersion: 'Android 14',
    screen: 'xxxhdpi 560dpi 1644x3840',
    timezone: 'Asia/Tokyo',
    locale: 'ja-JP',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; XT2201-2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    deviceName: 'Motorola Edge 30 Pro',
    osVersion: 'Android 13',
    screen: 'xxhdpi 400dpi 1080x2400',
    timezone: 'America/Sao_Paulo',
    locale: 'pt-BR',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; SM-A546E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Samsung Galaxy A54',
    osVersion: 'Android 14',
    screen: 'xxhdpi 400dpi 1080x2340',
    timezone: 'Australia/Sydney',
    locale: 'en-AU',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 12; 2201116SG) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    deviceName: 'Redmi Note 11 Pro',
    osVersion: 'Android 12',
    screen: 'xxhdpi 420dpi 1080x2400',
    timezone: 'Europe/Rome',
    locale: 'it-IT',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; ZS676KS) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    deviceName: 'Asus ROG Phone 6',
    osVersion: 'Android 13',
    screen: 'xxhdpi 420dpi 1080x2448',
    timezone: 'Asia/Taipei',
    locale: 'zh-TW',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 10; TA-1021) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36',
    deviceName: 'Nokia 8',
    osVersion: 'Android 10',
    screen: 'xxhdpi 380dpi 1440x2560',
    timezone: 'Europe/Helsinki',
    locale: 'fi-FI',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; PGT-N19) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    deviceName: 'Huawei P60 Pro',
    osVersion: 'Android 13 (EMUI)',
    screen: 'xxhdpi 430dpi 1220x2700',
    timezone: 'Europe/Paris',
    locale: 'fr-FR',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 9; LM-G710) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Mobile Safari/537.36',
    deviceName: 'LG G7 ThinQ',
    osVersion: 'Android 9',
    screen: 'xxhdpi 450dpi 1440x3120',
    timezone: 'Asia/Seoul',
    locale: 'ko-KR',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; Nothing Phone (2)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Nothing Phone (2)',
    osVersion: 'Android 14',
    screen: 'xxhdpi 400dpi 1080x2412',
    timezone: 'America/Toronto',
    locale: 'en-CA',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; SM-F936U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    deviceName: 'Samsung Galaxy Z Fold 4',
    osVersion: 'Android 13',
    screen: 'xhdpi 350dpi 1812x2176',
    timezone: 'America/Denver',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 12; LE2113) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    deviceName: 'OnePlus 9',
    osVersion: 'Android 12',
    screen: 'xxhdpi 420dpi 1080x2400',
    timezone: 'Europe/Stockholm',
    locale: 'sv-SE',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; Pixel 7a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36',
    deviceName: 'Google Pixel 7a',
    osVersion: 'Android 14',
    screen: 'xxhdpi 400dpi 1080x2400',
    timezone: 'Europe/Amsterdam',
    locale: 'nl-NL',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Samsung Galaxy S24',
    osVersion: 'Android 14',
    screen: 'xxhdpi 450dpi 1440x3120',
    timezone: 'America/Vancouver',
    locale: 'en-CA',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; M2101K6C) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    deviceName: 'Poco F3 GT',
    osVersion: 'Android 13',
    screen: 'xxhdpi 420dpi 1080x2400',
    timezone: 'Asia/Kolkata',
    locale: 'en-IN',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; V29) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Vivo V29',
    osVersion: 'Android 14',
    screen: 'xxhdpi 460dpi 1440x3200',
    timezone: 'Asia/Bangkok',
    locale: 'th-TH',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; K30 Ultra) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    deviceName: 'Xiaomi K30 Ultra',
    osVersion: 'Android 13',
    screen: 'xxhdpi 450dpi 1440x3200',
    timezone: 'Asia/Shanghai',
    locale: 'zh-CN',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; P80) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Oppo Find N3',
    osVersion: 'Android 14',
    screen: 'xxhdpi 430dpi 1440x3168',
    timezone: 'Europe/Paris',
    locale: 'fr-FR',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; SM-G916B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    deviceName: 'Samsung Galaxy S20 FE',
    osVersion: 'Android 13',
    screen: 'xxhdpi 400dpi 1080x2400',
    timezone: 'Europe/Berlin',
    locale: 'de-DE',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 12; CPH2135) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    deviceName: 'OnePlus 8 Pro',
    osVersion: 'Android 12',
    screen: 'xxhdpi 450dpi 1440x3168',
    timezone: 'America/New_York',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; S24E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Samsung Galaxy S24 Edge',
    osVersion: 'Android 14',
    screen: 'xxhdpi 460dpi 1440x3200',
    timezone: 'Asia/Tokyo',
    locale: 'ja-JP',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; LE2120) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    deviceName: 'OnePlus 9 Pro',
    osVersion: 'Android 13',
    screen: 'xxhdpi 460dpi 1440x3216',
    timezone: 'America/Toronto',
    locale: 'en-CA',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; A14 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Google Pixel 9 Pro',
    osVersion: 'Android 14',
    screen: 'xxhdpi 430dpi 1344x2992',
    timezone: 'Europe/London',
    locale: 'en-GB',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; 21091116AC) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    deviceName: 'Xiaomi 12T',
    osVersion: 'Android 13',
    screen: 'xxhdpi 460dpi 1440x3200',
    timezone: 'Europe/Rome',
    locale: 'it-IT',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 12; SM-F711B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    deviceName: 'Samsung Galaxy Z Flip 3',
    osVersion: 'Android 12',
    screen: 'xhdpi 370dpi 1080x2640',
    timezone: 'America/Mexico_City',
    locale: 'es-MX',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; XT2201-3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    deviceName: 'Motorola Edge 40',
    osVersion: 'Android 13',
    screen: 'xxhdpi 400dpi 1080x2400',
    timezone: 'Asia/Dubai',
    locale: 'ar-AE',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; 23088RA9AC) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Xiaomi 14 Ultra',
    osVersion: 'Android 14',
    screen: 'xxhdpi 450dpi 1440x3200',
    timezone: 'Europe/Moscow',
    locale: 'ru-RU',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; CPH2487) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
    deviceName: 'OnePlus 11',
    osVersion: 'Android 13',
    screen: 'xxhdpi 450dpi 1440x3216',
    timezone: 'Australia/Sydney',
    locale: 'en-AU',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 12; M2004J19C) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    deviceName: 'Xiaomi Mi 10T Pro',
    osVersion: 'Android 12',
    screen: 'xxhdpi 460dpi 1440x3200',
    timezone: 'America/Sao_Paulo',
    locale: 'pt-BR',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 14; SM-A546B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    deviceName: 'Samsung Galaxy A55',
    osVersion: 'Android 14',
    screen: 'xxhdpi 460dpi 1440x3200',
    timezone: 'Europe/Madrid',
    locale: 'es-ES',
  ),
  DevicePreset(
    deviceType: 'ANDROID',
    userAgent:
        'Mozilla/5.0 (Linux; Android 13; RMX3761) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
    deviceName: 'Realme GT Neo 3',
    osVersion: 'Android 13',
    screen: 'xxhdpi 460dpi 1440x3200',
    timezone: 'Asia/Hong_Kong',
    locale: 'zh-HK',
  ),

  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 15 Pro Max',
    osVersion: 'iOS 17.5.1',
    screen: '1290x2796 3.0x',
    timezone: 'America/Los_Angeles',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 13',
    osVersion: 'iOS 16.7',
    screen: '1170x2532 3.0x',
    timezone: 'Europe/London',
    locale: 'en-GB',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/124.0.6367.88 Mobile/15E148 Safari/604.1',
    deviceName: 'iPad Pro 11-inch',
    osVersion: 'iPadOS 17.5',
    screen: '1668x2388 2.0x',
    timezone: 'Europe/Paris',
    locale: 'fr-FR',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/125.0 Mobile/15E148',
    deviceName: 'iPhone 14 Pro',
    osVersion: 'iOS 17.4.1',
    screen: '1179x2556 3.0x',
    timezone: 'Europe/Berlin',
    locale: 'de-DE',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6.3 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone SE (2020)',
    osVersion: 'iOS 15.8',
    screen: '750x1334 2.0x',
    timezone: 'Australia/Melbourne',
    locale: 'en-AU',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) OPR/55.0.2519.144889 Mobile/15E148',
    deviceName: 'iPhone 15',
    osVersion: 'iOS 17.1',
    screen: '1179x2556 3.0x',
    timezone: 'Asia/Tokyo',
    locale: 'ja-JP',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPad; CPU OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1',
    deviceName: 'iPad Air 5th Gen',
    osVersion: 'iPadOS 16.5',
    screen: '1640x2360 2.0x',
    timezone: 'America/Toronto',
    locale: 'en-CA',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 15 Pro',
    osVersion: 'iOS 17.5',
    screen: '1179x2556 3.0x',
    timezone: 'Asia/Singapore',
    locale: 'en-SG',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 14',
    osVersion: 'iOS 17.4',
    screen: '1170x2532 3.0x',
    timezone: 'Europe/Stockholm',
    locale: 'sv-SE',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 12 Pro Max',
    osVersion: 'iOS 16.6',
    screen: '1284x2778 3.0x',
    timezone: 'Asia/Bangkok',
    locale: 'th-TH',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 15_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 11 Pro',
    osVersion: 'iOS 15.7',
    screen: '1125x2436 3.0x',
    timezone: 'Europe/Istanbul',
    locale: 'tr-TR',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    deviceName: 'iPad Mini 6th Gen',
    osVersion: 'iPadOS 17.5',
    screen: '1488x2266 2.0x',
    timezone: 'America/Mexico_City',
    locale: 'es-MX',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPad; CPU OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.7 Mobile/15E148 Safari/604.1',
    deviceName: 'iPad 10th Gen',
    osVersion: 'iPadOS 16.7',
    screen: '1620x2160 2.0x',
    timezone: 'Asia/Hong_Kong',
    locale: 'zh-HK',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 13 Pro',
    osVersion: 'iOS 17.3',
    screen: '1170x2532 3.0x',
    timezone: 'Europe/Dublin',
    locale: 'en-IE',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 12',
    osVersion: 'iOS 16.5',
    screen: '1125x2436 3.0x',
    timezone: 'Asia/Mumbai',
    locale: 'en-IN',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPad; CPU OS 15_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6 Mobile/15E148 Safari/604.1',
    deviceName: 'iPad Pro 12.9-inch',
    osVersion: 'iPadOS 15.8',
    screen: '2048x2732 2.0x',
    timezone: 'Europe/Vienna',
    locale: 'de-AT',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 14_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.1 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone XS Max',
    osVersion: 'iOS 14.8',
    screen: '1125x2436 3.0x',
    timezone: 'America/Los_Angeles',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 13 mini',
    osVersion: 'iOS 17.2',
    screen: '1080x2340 3.0x',
    timezone: 'America/Miami',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPad; CPU OS 14_8 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1 Mobile/15E148 Safari/604.1',
    deviceName: 'iPad Air 4th Gen',
    osVersion: 'iPadOS 14.8',
    screen: '1640x2360 2.0x',
    timezone: 'Europe/Zurich',
    locale: 'de-CH',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.4 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 11',
    osVersion: 'iOS 16.4',
    screen: '828x1792 2.0x',
    timezone: 'America/Argentina/Buenos_Aires',
    locale: 'es-AR',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone 12 mini',
    osVersion: 'iOS 17.1',
    screen: '1080x2340 3.0x',
    timezone: 'Europe/Brussels',
    locale: 'nl-BE',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
    deviceName: 'iPad Air Pro 11-inch',
    osVersion: 'iPadOS 17.4',
    screen: '2388x1668 2.0x',
    timezone: 'Asia/Bangkok',
    locale: 'en-TH',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 13_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.3 Mobile/15E148 Safari/604.1',
    deviceName: 'iPhone XR',
    osVersion: 'iOS 13.7',
    screen: '828x1792 2.0x',
    timezone: 'Europe/Lisbon',
    locale: 'pt-PT',
  ),
  DevicePreset(
    deviceType: 'IOS',
    userAgent:
        'Mozilla/5.0 (iPad; CPU OS 17_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Mobile/15E148 Safari/604.1',
    deviceName: 'iPad (9th generation)',
    osVersion: 'iPadOS 17.3',
    screen: '1620x2160 2.0x',
    timezone: 'Europe/Prague',
    locale: 'cs-CZ',
  ),

  DevicePreset(
    deviceType: 'DESKTOP',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    deviceName: 'Windows PC',
    osVersion: 'Windows 11',
    screen: '1920x1080 1.25x',
    timezone: 'Europe/Moscow',
    locale: 'ru-RU',
  ),
  DevicePreset(
    deviceType: 'DESKTOP',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    deviceName: 'MacBook Pro',
    osVersion: 'macOS 14.5 Sonoma',
    screen: '1728x1117 2.0x',
    timezone: 'America/New_York',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'DESKTOP',
    userAgent:
        'Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0',
    deviceName: 'Linux PC',
    osVersion: 'Ubuntu 24.04 LTS',
    screen: '2560x1440 1.0x',
    timezone: 'UTC',
    locale: 'en-GB',
  ),
  DevicePreset(
    deviceType: 'DESKTOP',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
    deviceName: 'Windows PC (Firefox)',
    osVersion: 'Windows 10',
    screen: '1536x864 1.0x',
    timezone: 'Europe/Paris',
    locale: 'fr-FR',
  ),
  DevicePreset(
    deviceType: 'DESKTOP',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15',
    deviceName: 'iMac (Safari)',
    osVersion: 'macOS 13.6 Ventura',
    screen: '3840x2160 1.5x',
    timezone: 'America/Los_Angeles',
    locale: 'en-US',
  ),

  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'Windows ',
    screen: '1920x1080',
    timezone: 'Europe/Berlin',
    locale: 'de-DE',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'Windows',
    screen: '2560x1440',
    timezone: 'America/New_York',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36 Edg/123.0.2420.97',
    deviceName: 'Edge',
    osVersion: 'Windows',
    screen: '1536x864',
    timezone: 'Europe/London',
    locale: 'en-GB',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'Windows',
    screen: '1920x1200',
    timezone: 'Europe/Paris',
    locale: 'fr-FR',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'Windows',
    screen: '1366x768',
    timezone: 'Europe/Madrid',
    locale: 'es-ES',
  ),

  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:126.0) Gecko/20100101 Firefox/126.0',
    deviceName: 'Firefox',
    osVersion: 'Windows',
    screen: '1920x1080',
    timezone: 'Europe/Rome',
    locale: 'it-IT',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
    deviceName: 'Firefox',
    osVersion: 'Windows',
    screen: '1440x900',
    timezone: 'Europe/Amsterdam',
    locale: 'nl-NL',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 6.3; Win64; x64; rv:124.0) Gecko/20100101 Firefox/124.0',
    deviceName: 'Firefox',
    osVersion: 'Windows',
    screen: '1600x900',
    timezone: 'Europe/Warsaw',
    locale: 'pl-PL',
  ),

  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36 Edg/125.0.2535.51',
    deviceName: 'Edge',
    osVersion: 'Windows',
    screen: '1920x1080',
    timezone: 'America/Chicago',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.2478.109',
    deviceName: 'Edge',
    osVersion: 'Windows',
    screen: '1366x768',
    timezone: 'America/Sao_Paulo',
    locale: 'pt-BR',
  ),

  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'macOS 14.5',
    screen: '2560x1440',
    timezone: 'America/Los_Angeles',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'macOS 13.6',
    screen: '1440x900',
    timezone: 'America/Toronto',
    locale: 'en-CA',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 11_7_10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'macOS 11.7',
    screen: '1728x1117',
    timezone: 'Australia/Sydney',
    locale: 'en-AU',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'macOS 12.5',
    screen: '2048x1152',
    timezone: 'Europe/London',
    locale: 'en-GB',
  ),

  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:126.0) Gecko/20100101 Firefox/126.0',
    deviceName: 'Firefox',
    osVersion: 'macOS 14.5',
    screen: '1920x1080',
    timezone: 'America/New_York',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:125.0) Gecko/20100101 Firefox/125.0',
    deviceName: 'Firefox',
    osVersion: 'macOS 13.0',
    screen: '1680x1050',
    timezone: 'Europe/Berlin',
    locale: 'de-DE',
  ),

  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15',
    deviceName: 'Safari',
    osVersion: 'macOS 14.5',
    screen: '1440x900',
    timezone: 'America/New_York',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15',
    deviceName: 'Safari',
    osVersion: 'macOS 13.6',
    screen: '2560x1600',
    timezone: 'Europe/Paris',
    locale: 'fr-FR',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6.1 Safari/605.1.15',
    deviceName: 'Safari',
    osVersion: 'macOS 10.14',
    screen: '1280x800',
    timezone: 'Asia/Tokyo',
    locale: 'ja-JP',
  ),

  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'Linux',
    screen: '1920x1080',
    timezone: 'Europe/Moscow',
    locale: 'ru-RU',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'Linux',
    screen: '1366x768',
    timezone: 'Asia/Kolkata',
    locale: 'en-IN',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'Chrome OS',
    screen: '1920x1080',
    timezone: 'America/Mexico_City',
    locale: 'es-MX',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'Linux',
    screen: '1600x900',
    timezone: 'Asia/Shanghai',
    locale: 'zh-CN',
  ),

  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:126.0) Gecko/20100101 Firefox/126.0',
    deviceName: 'Firefox',
    osVersion: 'Linux',
    screen: '1920x1080',
    timezone: 'UTC',
    locale: 'en-GB',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0',
    deviceName: 'Firefox',
    osVersion: 'Linux',
    screen: '2560x1440',
    timezone: 'America/Denver',
    locale: 'en-US',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0',
    deviceName: 'Firefox',
    osVersion: 'Linux',
    screen: '1366x768',
    timezone: 'Asia/Dubai',
    locale: 'ar-AE',
  ),

  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 OPR/110.0.0.0',
    deviceName: 'Opera',
    osVersion: 'Windows',
    screen: '1920x1080',
    timezone: 'Europe/Oslo',
    locale: 'no-NO',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36 Vivaldi/6.5.3206.63',
    deviceName: 'Vivaldi',
    osVersion: 'macOS 14.0',
    screen: '1440x900',
    timezone: 'Europe/Stockholm',
    locale: 'sv-SE',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; rv:102.0) Gecko/20100101 Firefox/102.0',
    deviceName: 'Firefox',
    osVersion: 'Windows',
    screen: '1280x720',
    timezone: 'Asia/Seoul',
    locale: 'ko-KR',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    deviceName: 'Chrome',
    osVersion: 'Linux',
    screen: '1920x1080',
    timezone: 'Europe/Helsinki',
    locale: 'fi-FI',
  ),
  DevicePreset(
    deviceType: 'WEB',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.1.2 Safari/605.1.15',
    deviceName: 'Safari',
    osVersion: 'macOS 10.13',
    screen: '1280x800',
    timezone: 'America/Vancouver',
    locale: 'en-CA',
  ),
];
