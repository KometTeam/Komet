import 'dart:io';
import 'package:flutter/services.dart';

class UploadNotificationService {
  static const _ch = MethodChannel('ru.komet.app/upload_service');

  static Future<void> start(String filename) async {
    if (!Platform.isAndroid) return;
    try { await _ch.invokeMethod('start', {'filename': filename}); } catch (_) {}
  }

  static Future<void> update({
    required String filename,
    required int progressPercent,
    required int speedBps,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('update', {
        'filename': filename,
        'progress': progressPercent,
        'speed': speedBps,
      });
    } catch (_) {}
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try { await _ch.invokeMethod('stop'); } catch (_) {}
  }
}
