import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Нативная запись видео-кружка: пишет квадрат сразу при съёмке — как
/// официальный клиент (по умолчанию 480×480@30, размер и fps настраиваются
/// в дев-меню). На Android — Camera2 + MediaRecorder, на iOS —
/// AVCaptureSession + AVAssetWriter. Превью отдаётся через Flutter
/// [Texture] по [textureId]. Перекодирование не используется (серверный
/// валидатор принимает только нативно записанный MP4).
class NativeVideoNoteRecorder {
  static const _channel = MethodChannel('ru.komet.app/video_note');

  int? textureId;
  bool hasFlash = false;
  bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  Future<bool> requestPermission() async {
    if (!isAvailable) return false;
    try {
      return await _channel.invokeMethod<bool>('permission') ?? false;
    } catch (e) {
      logger.w('NativeVideoNoteRecorder.requestPermission: $e');
      return false;
    }
  }

  Future<bool> init({bool front = true, int size = 480, int fps = 30}) async {
    if (!isAvailable) return false;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('init', {
        'front': front,
        'size': size,
        'fps': fps,
      });
      textureId = res?['textureId'] as int?;
      hasFlash = res?['hasFlash'] as bool? ?? false;
      return textureId != null;
    } catch (e) {
      logger.w('NativeVideoNoteRecorder.init: $e');
      return false;
    }
  }

  Future<bool> switchCamera() async {
    if (!isAvailable) return false;
    try {
      await _channel.invokeMethod('switch');
      return true;
    } catch (e) {
      logger.w('NativeVideoNoteRecorder.switchCamera: $e');
      return false;
    }
  }

  Future<bool> setTorch(bool on) async {
    if (!isAvailable || !hasFlash) return false;
    try {
      return await _channel.invokeMethod<bool>('torch', {'on': on}) ?? false;
    } catch (e) {
      logger.w('NativeVideoNoteRecorder.setTorch: $e');
      return false;
    }
  }

  Future<bool> start() async {
    if (!isAvailable) return false;
    try {
      await _channel.invokeMethod('start');
      return true;
    } catch (e) {
      logger.w('NativeVideoNoteRecorder.start: $e');
      return false;
    }
  }

  Future<String?> stop() async {
    if (!isAvailable) return null;
    try {
      return await _channel.invokeMethod<String>('stop');
    } catch (e) {
      logger.w('NativeVideoNoteRecorder.stop: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    if (!isAvailable) return;
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}
    textureId = null;
    hasFlash = false;
  }
}
