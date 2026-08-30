import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/logger.dart';

// #***! микрофон в списке выбора
class AudioInputDevice {
  const AudioInputDevice({required this.id, required this.label});

  final String id;
  final String label;
}

// #***! аудиоустройства через WebRTC
class AudioDevices {
  AudioDevices._();

  // #***! список микрофонов, пустые и дубли выкидываем
  static Future<List<AudioInputDevice>> microphones() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final mics = <AudioInputDevice>[];
      final seen = <String>{};
      for (final device in devices) {
        if (device.kind != 'audioinput') continue;
        if (device.deviceId.isEmpty || !seen.add(device.deviceId)) continue;
        mics.add(
          AudioInputDevice(id: device.deviceId, label: device.label.trim()),
        );
      }
      return mics;
    } catch (e) {
      logger.w('[call] enumerateDevices: $e');
      return const [];
    }
  }

  // #***! на мобилках и маке устройство переключает сам движок
  static bool get switchesInsideEngine =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static Future<void> selectInput(String deviceId) async {
    try {
      await Helper.selectAudioInput(deviceId);
    } catch (e) {
      logger.w('[call] selectAudioInput($deviceId): $e');
    }
  }

  // #***! ограничения захвата, для мониторинга глушим шумодав иначе себя не слышно
  static Object micConstraints(
    String? deviceId, {
    bool monitorCapture = false,
  }) {
    final constraints = <String, dynamic>{};
    final hasDevice = deviceId != null && deviceId.isNotEmpty;
    if (hasDevice && !switchesInsideEngine) {
      if (kIsWeb) {
        constraints['deviceId'] = deviceId;
      } else {
        constraints['optional'] = [
          {'sourceId': deviceId},
        ];
      }
    }
    if (monitorCapture) {
      constraints['echoCancellation'] = true;
      constraints['noiseSuppression'] = false;
      constraints['autoGainControl'] = false;
      constraints['highpassFilter'] = false;
    }
    return constraints.isEmpty ? true : constraints;
  }

  // #***! ищем по части id или названия, сразу после подключения его может не быть
  static Future<String?> findDevice(String token, {int attempts = 1}) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      for (final device in await microphones()) {
        if (device.id == token ||
            device.id.contains(token) ||
            device.label.contains(token)) {
          return device.id;
        }
      }
      if (attempt + 1 < attempts) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    return null;
  }
}
