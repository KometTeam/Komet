import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

// #***! реальные данные устройства для юзерагента
/// Данные устройства для user-agent, неизменные за время жизни процесса.
/// Читаются с платформы один раз: на каждый реконнект их запрашивать незачем.
class DeviceProfile {
  const DeviceProfile({
    this.osVersion = '',
    this.deviceName = 'Unknown',
    this.manufacturer,
    this.model,
    this.sdkInt,
  });

  final String osVersion;
  final String deviceName;
  final String? manufacturer;
  final String? model;
  final int? sdkInt;

  // #***! читаем один раз за процесс, на каждый реконнект незачем
  static DeviceProfile? _cached;

  static Future<DeviceProfile> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final profile = await _read();
    _cached = profile;
    return profile;
  }

  // #***! у каждой платформы свой источник, на незнакомой пусто
  static Future<DeviceProfile> _read() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return DeviceProfile(
        osVersion: 'Android ${info.version.release}',
        deviceName: '${info.manufacturer} ${info.model}',
        manufacturer: info.manufacturer,
        model: info.model,
        sdkInt: info.version.sdkInt,
      );
    }
    if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return DeviceProfile(
        osVersion: info.systemVersion,
        deviceName: info.utsname.machine,
      );
    }
    if (Platform.isLinux) {
      final info = await deviceInfo.linuxInfo;
      return DeviceProfile(osVersion: info.name);
    }
    if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      return DeviceProfile(osVersion: info.productName);
    }
    return const DeviceProfile();
  }
}
