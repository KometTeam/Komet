import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WindowFrame {
  const WindowFrame._();

  static const MethodChannel _channel = MethodChannel('ru.komet.app/window');

  static bool get isChromeless => !kIsWeb && Platform.isMacOS;

  static final ValueNotifier<double> inset = ValueNotifier(0);

  static Future<void> loadInset() async {
    if (!isChromeless || inset.value > 0) return;
    try {
      final value = await _channel.invokeMethod<double>('titleInset');
      if ((value ?? 0) > 0) inset.value = value!;
    } on PlatformException {
      inset.value = 28;
    } on MissingPluginException {
      inset.value = 28;
    }
  }

  static void startDrag() {
    if (!isChromeless) return;
    unawaited(_channel.invokeMethod<void>('startDrag'));
  }

  static void toggleZoom() {
    if (!isChromeless) return;
    unawaited(_channel.invokeMethod<void>('toggleZoom'));
  }
}
