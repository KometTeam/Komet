import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

// #***! заглушка для платформ без нативки
class TlottieClip {
  TlottieClip({this.px = 0});

  final int px;
  int frameCount = 0;
  int durationMs = 1000;
  double frameRate = 60;
  final ValueNotifier<int> ready = ValueNotifier(0);

  ui.Image? frameAt(int index) => null;
}

class TlottieEngine {
  TlottieEngine._();
  static final TlottieEngine instance = TlottieEngine._();

  static String? debugLibraryPath;

  bool get available => false;

  Future<TlottieClip?> acquire(String url, int px, {String? inlineJson}) async =>
      null;

  Future<void> prewarm(String url, int px) async {}

  void release(TlottieClip clip) {}
}
