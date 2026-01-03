import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'device_presets.dart';
import 'dart:math';

class SpoofingService {
  static Future<Map<String, dynamic>?> getSpoofedSessionData() async {
    final prefs = await SharedPreferences.getInstance();

    final isEnabled = prefs.getBool('spoofing_enabled') ?? false;

    if (!isEnabled) {
      return null;
    }

    return {
      'user_agent': prefs.getString('spoof_useragent'),
      'device_name': prefs.getString('spoof_devicename'),
      'os_version': prefs.getString('spoof_osversion'),
      'screen': prefs.getString('spoof_screen'),
      'timezone': prefs.getString('spoof_timezone'),
      'locale': prefs.getString('spoof_locale'),
      'device_id': prefs.getString('spoof_deviceid'),
      'device_type': prefs.getString('spoof_devicetype'),
      'app_version': prefs.getString('spoof_appversion') ?? '25.21.3',
    };
  }

  /// Генерирует случайный Android SPOOF и сохраняет его
  static Future<void> generateRandomAndroidSpoof() async {
    final prefs = await SharedPreferences.getInstance();

    // Фильтруем только Android presets
    final androidPresets = devicePresets
        .where((preset) => preset.deviceType == 'ANDROID')
        .toList();

    if (androidPresets.isEmpty) {
      print('Ошибка: не найдены Android presets');
      return;
    }

    // Выбираем случайный preset
    final random = Random();
    final randomPreset = androidPresets[random.nextInt(androidPresets.length)];

    // Генерируем случайный device ID
    final deviceId = const Uuid().v4();

    // Сохраняем SPOOF данные
    await prefs.setString('spoof_useragent', randomPreset.userAgent);
    await prefs.setString('spoof_devicename', randomPreset.deviceName);
    await prefs.setString('spoof_osversion', randomPreset.osVersion);
    await prefs.setString('spoof_screen', randomPreset.screen);
    await prefs.setString('spoof_timezone', randomPreset.timezone);
    await prefs.setString('spoof_locale', randomPreset.locale);
    await prefs.setString('spoof_deviceid', deviceId);
    await prefs.setString('spoof_devicetype', randomPreset.deviceType);
    await prefs.setString('spoof_appversion', '25.21.3');

    // Включаем spoofing
    await prefs.setBool('spoofing_enabled', true);

    print('Сгенерирован SPOOF:');
    print('  Device: ${randomPreset.deviceName}');
    print('  OS: ${randomPreset.osVersion}');
    print('  Device ID: $deviceId');
  }
}
