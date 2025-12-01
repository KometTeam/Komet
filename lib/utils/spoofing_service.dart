import 'package:shared_preferences/shared_preferences.dart';

class SpoofingService {


  static Future<Map<String, dynamic>?> getSpoofedSessionData() async {
    final prefs = await SharedPreferences.getInstance();

    final isEnabled = prefs.getBool('spoofing_enabled') ?? false;

    if (!isEnabled) {
      return null; // Если подмена выключена, возвращаем null
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
      'app_version': prefs.getString('spoof_appversion') ?? '25.12.1',
    };
  }
}
