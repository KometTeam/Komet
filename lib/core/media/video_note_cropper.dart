import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// Центр-кроп записанного видео в квадрат для видеосообщений-кружков.
/// На Android выполняется нативно (media3 Transformer, без искажений —
/// заполняет квадрат и обрезает лишнее по бокам). На других платформах
/// возвращает `null` (кружки там не записываются).
class VideoNoteCropper {
  static const _channel = MethodChannel('ru.komet.app/video');

  static Future<String?> cropSquare(String input, {int size = 480}) async {
    if (!Platform.isAndroid) return null;
    try {
      final dot = input.lastIndexOf('.');
      final base = dot > 0 ? input.substring(0, dot) : input;
      final output = '${base}_sq.mp4';
      final res = await _channel.invokeMethod<String>('cropSquare', {
        'input': input,
        'output': output,
        'size': size,
      });
      return res;
    } catch (e) {
      logger.w('VideoNoteCropper: $e');
      return null;
    }
  }
}
