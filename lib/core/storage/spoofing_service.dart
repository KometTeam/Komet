import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/device_presets.dart';
import '../../models/spoof_profile.dart';
import 'token_storage.dart';
import '../utils/ids.dart';
import '../utils/logger.dart';

class SpoofingService {
  static const String hardcodedAppVersion = '26.20.2';
  static const int hardcodedBuildNumber = 6758;
  static const String pendingScope = 'pending';

  static const String _legacyEnabledKey = 'spoofing_enabled';
  static const List<String> _legacyKeys = [
    'spoofing_enabled',
    'spoof_devicename',
    'spoof_osversion',
    'spoof_screen',
    'spoof_timezone',
    'spoof_locale',
    'spoof_devicelocale',
    'spoof_deviceid',
    'spoof_devicetype',
    'spoof_arch',
    'spoof_appversion',
    'spoof_buildnumber',
    'spoof_pushdevicetype',
    'spoof_instanceid',
    'spoof_clientsessionid',
    'spoof_useragent',
  ];

  static final Random _rng = Random.secure();

  static String _profileKey(String scope) => 'spoof_profile_$scope';

  static Future<String> activeScope() async {
    final id = await TokenStorage.getActiveAccountId();
    return id?.toString() ?? pendingScope;
  }

  static Future<SpoofProfile?> loadProfile(String scope) async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs, scope);
  }

  static Future<void> saveProfile(String scope, SpoofProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(scope), jsonEncode(profile.toJson()));
  }

  static Future<void> clearAccountSpoof(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey('$accountId'));
  }

  static Future<void> commitPendingSpoof(int accountId) async {
    final prefs = await SharedPreferences.getInstance();
    final pending = await _read(prefs, pendingScope);
    if (pending == null) return;
    await prefs.setString(
      _profileKey('$accountId'),
      jsonEncode(pending.toJson()),
    );
    await prefs.remove(_profileKey(pendingScope));
  }

  static Future<SpoofProfile> prepareNewAccountSpoof(
    List<int> existingAccountIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final used = <String>{};
    for (final id in existingAccountIds) {
      final existing = await _read(prefs, '$id');
      if (existing != null && existing.deviceName.isNotEmpty) {
        used.add(existing.deviceName);
      }
    }

    bool isAndroid(DevicePreset p) => p.deviceType == 'ANDROID';
    final fresh = devicePresets
        .where((p) => isAndroid(p) && !used.contains(p.deviceName))
        .toList();
    final pool = fresh.isNotEmpty
        ? fresh
        : devicePresets.where(isAndroid).toList();
    final preset = pool[_rng.nextInt(pool.length)];
    final shortLocale = preset.locale.split(RegExp(r'[-_]')).first;

    final profile = SpoofProfile(
      enabled: true,
      deviceName: preset.deviceName,
      osVersion: preset.osVersion,
      screen: preset.screen,
      timezone: preset.timezone,
      locale: shortLocale,
      deviceLocale: shortLocale,
      deviceId: _hex(8),
      deviceType: preset.deviceType,
      arch: 'arm64-v8a',
      appVersion: hardcodedAppVersion,
      buildNumber: hardcodedBuildNumber,
      pushDeviceType: 'GCM',
      instanceId: uuidV4(),
      clientSessionId: _rng.nextInt(0x7FFFFFFF) + 1,
      userAgent: preset.userAgent,
    );

    await prefs.setString(
      _profileKey(pendingScope),
      jsonEncode(profile.toJson()),
    );
    return profile;
  }

  static Future<Map<String, dynamic>?> getSpoofedSessionData({
    String? scope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _read(prefs, scope ?? await activeScope());
    if (profile == null || !profile.enabled) return null;

    return {
      'device_name': profile.deviceName,
      'os_version': profile.osVersion,
      'screen': profile.screen,
      'timezone': profile.timezone,
      'locale': profile.locale,
      'device_locale': profile.deviceLocale,
      'device_id': profile.deviceId,
      'device_type': profile.deviceType,
      'app_version': profile.appVersion.isEmpty
          ? hardcodedAppVersion
          : profile.appVersion,
      'arch': profile.arch.isEmpty ? 'arm64-v8a' : profile.arch,
      'build_number': profile.buildNumber == 0
          ? hardcodedBuildNumber
          : profile.buildNumber,
      'instance_id': profile.instanceId,
      'client_session_id': profile.clientSessionId,
      'push_device_type': profile.pushDeviceType,
    };
  }

  static Future<String?> getWebViewUserAgent() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _read(prefs, await activeScope());
    if (profile == null || !profile.enabled) return null;

    if (profile.userAgent.isNotEmpty) return profile.userAgent;
    for (final preset in devicePresets) {
      if (preset.deviceName == profile.deviceName) return preset.userAgent;
    }
    return _deriveUserAgent(profile);
  }

  static String _deriveUserAgent(SpoofProfile profile) {
    final deviceType = profile.deviceType.isEmpty
        ? 'ANDROID'
        : profile.deviceType;
    final osVersion = profile.osVersion;
    final model = profile.deviceName.isEmpty ? 'K' : profile.deviceName;

    if (deviceType == 'IOS' || deviceType == 'iOS') {
      final version = osVersion
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .replaceAll('.', '_');
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS '
          '${version.isEmpty ? '17_0' : version} like Mac OS X) '
          'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
          'Mobile/15E148 Safari/604.1';
    }

    final android = osVersion.isEmpty ? 'Android 14' : osVersion;
    return 'Mozilla/5.0 (Linux; $android; $model) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  }

  static Future<SpoofProfile?> _read(
    SharedPreferences prefs,
    String scope,
  ) async {
    final raw = prefs.getString(_profileKey(scope));
    if (raw != null && raw.isNotEmpty) {
      try {
        final profile = SpoofProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        return _migrateVersion(prefs, scope, profile);
      } catch (e) {
        logger.w('spoof profile read failed: $e');
      }
    }
    if (scope != pendingScope) {
      return _migrateLegacy(prefs, scope);
    }
    return null;
  }

  static Future<SpoofProfile> _migrateVersion(
    SharedPreferences prefs,
    String scope,
    SpoofProfile profile,
  ) async {
    if (profile.appVersion == hardcodedAppVersion &&
        profile.buildNumber == hardcodedBuildNumber) {
      return profile;
    }
    final migrated = profile.copyWith(
      appVersion: hardcodedAppVersion,
      buildNumber: hardcodedBuildNumber,
    );
    await prefs.setString(_profileKey(scope), jsonEncode(migrated.toJson()));
    return migrated;
  }

  static Future<SpoofProfile?> _migrateLegacy(
    SharedPreferences prefs,
    String scope,
  ) async {
    if (!(prefs.getBool(_legacyEnabledKey) ?? false)) return null;

    final profile = SpoofProfile(
      enabled: true,
      deviceName: prefs.getString('spoof_devicename') ?? '',
      osVersion: prefs.getString('spoof_osversion') ?? '',
      screen: prefs.getString('spoof_screen') ?? '',
      timezone: prefs.getString('spoof_timezone') ?? '',
      locale: prefs.getString('spoof_locale') ?? '',
      deviceLocale: prefs.getString('spoof_devicelocale') ?? '',
      deviceId: prefs.getString('spoof_deviceid') ?? '',
      deviceType: prefs.getString('spoof_devicetype') ?? 'ANDROID',
      arch: prefs.getString('spoof_arch') ?? 'arm64-v8a',
      appVersion: prefs.getString('spoof_appversion') ?? hardcodedAppVersion,
      buildNumber: prefs.getInt('spoof_buildnumber') ?? hardcodedBuildNumber,
      pushDeviceType: prefs.getString('spoof_pushdevicetype') ?? 'GCM',
      instanceId: prefs.getString('spoof_instanceid') ?? '',
      clientSessionId: prefs.getInt('spoof_clientsessionid'),
      userAgent: prefs.getString('spoof_useragent') ?? '',
    );

    await prefs.setString(_profileKey(scope), jsonEncode(profile.toJson()));
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
    return profile;
  }

  static String _hex(int bytes) {
    final sb = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      sb.write(_rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
