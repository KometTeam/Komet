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

class AudioOutputDevice {
  const AudioOutputDevice({required this.id, required this.label});

  final String id;
  final String label;
}

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

  static Future<List<AudioOutputDevice>> outputs() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final outputs = <AudioOutputDevice>[];
      final seen = <String>{};
      for (final device in devices) {
        if (device.kind != 'audiooutput') continue;
        if (device.deviceId.isEmpty || !seen.add(device.deviceId)) continue;
        outputs.add(
          AudioOutputDevice(id: device.deviceId, label: device.label.trim()),
        );
      }
      logger.i(
        '[call][audio] outputs=${outputs.length} '
        '${outputs.map((device) => device.label).join(' | ')}',
      );
      return outputs;
    } catch (e) {
      logger.w('[call][audio] enumerate outputs failed: $e');
      return const [];
    }
  }

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
      rethrow;
    }
  }

  static Future<String?> selectOutput(String? deviceId) async {
    final devices = await outputs();
    if (devices.isEmpty) {
      throw StateError('Устройства вывода звука не найдены');
    }
    final selected = deviceId == null
        ? devices.where((device) => device.id == 'default').firstOrNull ??
              devices.first
        : devices.where((device) => device.id == deviceId).firstOrNull;
    if (selected == null) {
      throw StateError(
        'Устройство вывода отключено. Обновите список устройств.',
      );
    }
    await Helper.selectAudioOutput(selected.id);
    logger.i(
      '[call][audio] output selected id=${selected.id.hashCode.toUnsigned(32).toRadixString(16)} '
      'label=${selected.label}',
    );
    return deviceId == null ? null : selected.id;
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
