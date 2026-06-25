import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Нативная запись видео-кружка (Android, Camera2 + MediaRecorder): пишет
/// квадрат 480×480 сразу при съёмке — как официальный клиент. Превью отдаётся
/// через Flutter [Texture] по [textureId]. media3-перекод не используется
/// (серверный валидатор принимает только нативно записанный MP4).
class NativeVideoNoteRecorder {
  static const _channel = MethodChannel('ru.komet.app/video_note');

  int? textureId;
  bool get isAvailable => Platform.isAndroid;

  Future<bool> init({bool front = true}) async {
    if (!isAvailable) return false;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('init', {
        'front': front,
      });
      textureId = res?['textureId'] as int?;
      return textureId != null;
    } catch (e) {
      logger.w('NativeVideoNoteRecorder.init: $e');
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
  }
}
