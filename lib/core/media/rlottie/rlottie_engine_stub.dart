import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

class RlottieClip {
  RlottieClip({this.px = 0});

  final int px;
  int frameCount = 0;
  int durationMs = 1000;
  double frameRate = 60;
  final ValueNotifier<int> ready = ValueNotifier(0);

  ui.Image? frameAt(int index) => null;
}

class RlottieEngine {
  RlottieEngine._();
  static final RlottieEngine instance = RlottieEngine._();

  static String? debugLibraryPath;

  bool get available => false;

  Future<RlottieClip?> acquire(String url, int px, {String? inlineJson}) async =>
      null;

  Future<void> prewarm(String url, int px) async {}

  void release(RlottieClip clip) {}
}
