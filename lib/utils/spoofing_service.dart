import 'package:shared_preferences/shared_preferences.dart';

class SpoofingService {
  static Future<Map<String, dynamic>?> getSpoofedSessionData() async {
    final prefs = await SharedPreferences.getInstance();

    final isEnabled = prefs.getBool('spoofing_enabled') ?? false;

    if (!isEnabled) {
      return null;
    }

    return {
      'device_name': prefs.getString('spoof_devicename'),
      'os_version': prefs.getString('spoof_osversion'),
      'screen': prefs.getString('spoof_screen'),
      'timezone': prefs.getString('spoof_timezone'),
      'locale': prefs.getString('spoof_locale'),
      'device_id': prefs.getString('spoof_deviceid'),
      'device_type': prefs.getString('spoof_devicetype'),
      'app_version': prefs.getString('spoof_appversion') ?? '25.21.3',
      'arch': prefs.getString('spoof_arch') ?? 'arm64-v8a',
      'build_number': prefs.getInt('spoof_buildnumber') ?? 6498,
    };
  }
}
