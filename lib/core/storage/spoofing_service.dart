import 'package:shared_preferences/shared_preferences.dart';

class SpoofingService {
  static const String hardcodedAppVersion = '26.8.1';
  static const int hardcodedBuildNumber = 6606;

  static Future<Map<String, dynamic>?> getSpoofedSessionData() async {
    final prefs = await SharedPreferences.getInstance();

    final isEnabled = prefs.getBool('spoofing_enabled') ?? false;
    if (!isEnabled) return null;

    return {
      'device_name': prefs.getString('spoof_devicename'),
      'os_version': prefs.getString('spoof_osversion'),
      'screen': prefs.getString('spoof_screen'),
      'timezone': prefs.getString('spoof_timezone'),
      'locale': prefs.getString('spoof_locale'),
      'device_id': prefs.getString('spoof_deviceid'),
      'device_type': prefs.getString('spoof_devicetype'),
      'app_version': hardcodedAppVersion,
      'arch': prefs.getString('spoof_arch') ?? 'arm64-v8a',
      'build_number': hardcodedBuildNumber,
    };
  }
}
