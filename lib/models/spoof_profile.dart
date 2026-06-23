class SpoofProfile {
  final bool enabled;
  final String deviceName;
  final String osVersion;
  final String screen;
  final String timezone;
  final String locale;
  final String deviceLocale;
  final String deviceId;
  final String deviceType;
  final String arch;
  final String appVersion;
  final int buildNumber;
  final String pushDeviceType;
  final String instanceId;
  final int? clientSessionId;
  final String userAgent;

  const SpoofProfile({
    required this.enabled,
    this.deviceName = '',
    this.osVersion = '',
    this.screen = '',
    this.timezone = '',
    this.locale = '',
    this.deviceLocale = '',
    this.deviceId = '',
    this.deviceType = 'ANDROID',
    this.arch = 'arm64-v8a',
    this.appVersion = '',
    this.buildNumber = 0,
    this.pushDeviceType = 'GCM',
    this.instanceId = '',
    this.clientSessionId,
    this.userAgent = '',
  });

  SpoofProfile copyWith({
    bool? enabled,
    String? deviceName,
    String? osVersion,
    String? screen,
    String? timezone,
    String? locale,
    String? deviceLocale,
    String? deviceId,
    String? deviceType,
    String? arch,
    String? appVersion,
    int? buildNumber,
    String? pushDeviceType,
    String? instanceId,
    int? clientSessionId,
    String? userAgent,
  }) =>
      SpoofProfile(
        enabled: enabled ?? this.enabled,
        deviceName: deviceName ?? this.deviceName,
        osVersion: osVersion ?? this.osVersion,
        screen: screen ?? this.screen,
        timezone: timezone ?? this.timezone,
        locale: locale ?? this.locale,
        deviceLocale: deviceLocale ?? this.deviceLocale,
        deviceId: deviceId ?? this.deviceId,
        deviceType: deviceType ?? this.deviceType,
        arch: arch ?? this.arch,
        appVersion: appVersion ?? this.appVersion,
        buildNumber: buildNumber ?? this.buildNumber,
        pushDeviceType: pushDeviceType ?? this.pushDeviceType,
        instanceId: instanceId ?? this.instanceId,
        clientSessionId: clientSessionId ?? this.clientSessionId,
        userAgent: userAgent ?? this.userAgent,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'device_name': deviceName,
        'os_version': osVersion,
        'screen': screen,
        'timezone': timezone,
        'locale': locale,
        'device_locale': deviceLocale,
        'device_id': deviceId,
        'device_type': deviceType,
        'arch': arch,
        'app_version': appVersion,
        'build_number': buildNumber,
        'push_device_type': pushDeviceType,
        'instance_id': instanceId,
        'client_session_id': clientSessionId,
        'user_agent': userAgent,
      };

  factory SpoofProfile.fromJson(Map<String, dynamic> json) => SpoofProfile(
        enabled: json['enabled'] as bool? ?? false,
        deviceName: json['device_name'] as String? ?? '',
        osVersion: json['os_version'] as String? ?? '',
        screen: json['screen'] as String? ?? '',
        timezone: json['timezone'] as String? ?? '',
        locale: json['locale'] as String? ?? '',
        deviceLocale: json['device_locale'] as String? ?? '',
        deviceId: json['device_id'] as String? ?? '',
        deviceType: json['device_type'] as String? ?? 'ANDROID',
        arch: json['arch'] as String? ?? 'arm64-v8a',
        appVersion: json['app_version'] as String? ?? '',
        buildNumber: (json['build_number'] as num?)?.toInt() ?? 0,
        pushDeviceType: json['push_device_type'] as String? ?? 'GCM',
        instanceId: json['instance_id'] as String? ?? '',
        clientSessionId: (json['client_session_id'] as num?)?.toInt(),
        userAgent: json['user_agent'] as String? ?? '',
      );
}
