import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

// #***! разрешения на камеру и микрофон
class VideoNoteAccess {
  const VideoNoteAccess({required this.camera, required this.microphone});

  static const denied = VideoNoteAccess(camera: false, microphone: false);

  final bool camera;
  final bool microphone;

  bool get granted => camera && microphone;
}

// #***! запись кружка целиком в нативе, превью текстурой
class NativeVideoNoteRecorder {
  static const _channel = MethodChannel('ru.komet.app/video_note');

  int? textureId;
  bool hasFlash = false;
  // #***! десктопа не касается
  bool get isAvailable => Platform.isAndroid || Platform.isIOS;

  Future<VideoNoteAccess> requestAccess() async {
    if (!isAvailable) return VideoNoteAccess.denied;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('permission');
      return VideoNoteAccess(
        camera: res?['camera'] as bool? ?? false,
        microphone: res?['microphone'] as bool? ?? false,
      );
    } catch (e) {
      logger.w('NativeVideoNoteRecorder.requestAccess: $e');
      return VideoNoteAccess.denied;
    }
  }

  // #***! инициализация камеры, textureId нужен виджету превью
  Future<bool> init({bool front = true, int size = 480, int fps = 30}) async {
    if (!isAvailable) return false;
    final res = await _channel.invokeMapMethod<String, dynamic>('init', {
      'front': front,
      'size': size,
      'fps': fps,
    });
    textureId = res?['textureId'] as int?;
    hasFlash = res?['hasFlash'] as bool? ?? false;
    return textureId != null;
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

  // #***! запись без поддержки платформы это ошибка программиста, кидаем исключение
  Future<void> start() async {
    if (!isAvailable) {
      throw PlatformException(
        code: 'UNSUPPORTED',
        message: 'video notes are not supported on this platform',
      );
    }
    await _channel.invokeMethod('start');
  }

  Future<String?> stop() async {
    if (!isAvailable) return null;
    return _channel.invokeMethod<String>('stop');
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
