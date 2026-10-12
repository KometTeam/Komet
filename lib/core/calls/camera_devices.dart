import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/logger.dart';

enum CameraFacing { front, back, external }

class VideoInputDevice {
  const VideoInputDevice({
    required this.id,
    required this.label,
    required this.facing,
  });

  final String id;
  final String label;
  final CameraFacing facing;
}

class CameraDevices {
  CameraDevices._();

  static Future<List<VideoInputDevice>> cameras() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final cameras = <VideoInputDevice>[];
      final seen = <String>{};
      for (final device in devices) {
        if (device.kind != 'videoinput') continue;
        if (device.deviceId.isEmpty || !seen.add(device.deviceId)) continue;
        final label = device.label.trim();
        cameras.add(
          VideoInputDevice(
            id: device.deviceId,
            label: label,
            facing: facingOf(label),
          ),
        );
      }
      return cameras;
    } catch (e) {
      logger.w('[media] enumerate cameras: $e');
      return const [];
    }
  }

  static CameraFacing facingOf(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('front') || lower.contains('user')) {
      return CameraFacing.front;
    }
    if (lower.contains('back') ||
        lower.contains('rear') ||
        lower.contains('environment')) {
      return CameraFacing.back;
    }
    return CameraFacing.external;
  }

  static Object constraints(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) return true;
    if (kIsWeb) return <String, dynamic>{'deviceId': deviceId};
    return <String, dynamic>{
      'optional': [
        {'sourceId': deviceId},
      ],
    };
  }
}
