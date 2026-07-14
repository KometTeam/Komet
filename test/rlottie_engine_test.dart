import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/rlottie/rlottie_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rlottie engine renders a real clip into ui.Image frames', () async {
    final libPath = Platform.environment['RLOTTIE_LIB'];
    if (libPath == null || !File(libPath).existsSync()) {
      markTestSkipped('set RLOTTIE_LIB to librlottie.so to run');
      return;
    }
    RlottieEngine.debugLibraryPath = libPath;

    expect(RlottieEngine.instance.available, isTrue,
        reason: 'library should open');

    final json = File('assets/lottie/ic_settings.json').readAsStringSync();
    const px = 256;
    final clip = await RlottieEngine.instance
        .acquire('poc://ic_settings', px, inlineJson: json);

    expect(clip, isNotNull);
    expect(clip!.frameCount, greaterThan(1));
    expect(clip.durationMs, greaterThan(0));

    final target = clip.frameCount;
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (clip.ready.value < target && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(clip.ready.value, target, reason: 'all frames decoded');

    final mid = clip.frameAt(target ~/ 2);
    expect(mid, isNotNull);
    expect(mid!.width, px);
    expect(mid.height, px);

    final data = await mid.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    var opaque = 0;
    var transparent = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] == 0) {
        transparent++;
      } else if (bytes[i] > 250) {
        opaque++;
      }
    }
    expect(opaque, greaterThan(0), reason: 'gear pixels present');
    expect(transparent, greaterThan(0), reason: 'transparent background present');

    final png = await mid.toByteData(format: ui.ImageByteFormat.png);
    final out = Platform.environment['RLOTTIE_PNG_OUT'];
    if (out != null) {
      File(out).writeAsBytesSync(png!.buffer.asUint8List());
      debugPrint('wrote decoded frame PNG: $out');
    }

    RlottieEngine.instance.release(clip);
  });
}
