import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/tlottie/tlottie_engine.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tlottie engine renders a real clip into ui.Image frames', () async {
    final libPath = Platform.environment['TLOTTIE_LIB'];
    if (libPath == null || !File(libPath).existsSync()) {
      markTestSkipped('set TLOTTIE_LIB to libkomet_tlottie.so to run');
      return;
    }
    TlottieEngine.debugLibraryPath = libPath;
    final tmp = Directory.systemTemp.createTempSync('tlottie_engine_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);

    expect(
      TlottieEngine.instance.available,
      isTrue,
      reason: 'library should open',
    );

    final json = File('assets/lottie/ic_settings.json').readAsStringSync();
    const px = 256;
    final clip = await TlottieEngine.instance.acquire(
      'poc://ic_settings',
      px,
      inlineJson: json,
    );

    expect(clip, isNotNull);
    expect(clip!.frameCount, greaterThan(1));
    expect(clip.durationMs, greaterThan(0));

    final target = clip.frameCount;
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (clip.ready.value < target && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(clip.ready.value, target, reason: 'all frames decoded');

    final cacheDir = Directory('${tmp.path}/tlottie_frames');
    final written = DateTime.now().add(const Duration(seconds: 10));
    while (cacheDir.listSync().isEmpty && DateTime.now().isBefore(written)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(cacheDir.listSync(), hasLength(1), reason: 'worker stored the clip');

    final mid = clip.frameAt(target ~/ 2);
    expect(mid, isNotNull);
    expect(mid!.source.width, px);
    expect(mid.source.height, px);

    final page = mid.image;
    final data = await page.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final left = mid.source.left.toInt();
    final top = mid.source.top.toInt();
    var opaque = 0;
    var transparent = 0;
    for (var y = top; y < top + px; y++) {
      for (var x = left; x < left + px; x++) {
        final alpha = bytes[(y * page.width + x) * 4 + 3];
        if (alpha == 0) {
          transparent++;
        } else if (alpha > 250) {
          opaque++;
        }
      }
    }
    expect(opaque, greaterThan(0), reason: 'gear pixels present');
    expect(
      transparent,
      greaterThan(0),
      reason: 'transparent background present',
    );

    final out = Platform.environment['TLOTTIE_PNG_OUT'];
    if (out != null) {
      final png = await page.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(png!.buffer.asUint8List());
      debugPrint('wrote decoded atlas page PNG: $out');
    }

    TlottieEngine.instance.release(clip);
  });

  test('a clip released while rendering is cancelled and loads anew', () async {
    final libPath = Platform.environment['TLOTTIE_LIB'];
    if (libPath == null || !File(libPath).existsSync()) {
      markTestSkipped('set TLOTTIE_LIB to libkomet_tlottie.so to run');
      return;
    }
    TlottieEngine.debugLibraryPath = libPath;
    final tmp = Directory.systemTemp.createTempSync('tlottie_cancel_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);

    final json = File('assets/lottie/ic_settings.json').readAsStringSync();
    const url = 'poc://ic_settings_cancel';
    final first = await TlottieEngine.instance.acquire(
      url,
      384,
      inlineJson: json,
    );
    expect(first, isNotNull);
    expect(first!.complete, isFalse);
    TlottieEngine.instance.release(first);

    final second = await TlottieEngine.instance.acquire(
      url,
      384,
      inlineJson: json,
    );
    expect(second, isNotNull);
    expect(identical(second, first), isFalse, reason: 'cancelled clip dropped');

    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (second!.ready.value < second.frameCount &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(second.ready.value, second.frameCount);
    TlottieEngine.instance.release(second);
  });

  test('a clip taken over in the frame its holder lets go keeps rendering', () async {
    final libPath = Platform.environment['TLOTTIE_LIB'];
    if (libPath == null || !File(libPath).existsSync()) {
      markTestSkipped('set TLOTTIE_LIB to libkomet_tlottie.so to run');
      return;
    }
    TlottieEngine.debugLibraryPath = libPath;
    final tmp = Directory.systemTemp.createTempSync('tlottie_handover_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);

    final json = File('assets/lottie/ic_settings.json').readAsStringSync();
    const url = 'poc://ic_settings_handover';
    final first = await TlottieEngine.instance.acquire(
      url,
      384,
      inlineJson: json,
    );
    expect(first, isNotNull);
    expect(first!.complete, isFalse);

    final takeover = TlottieEngine.instance.acquire(
      url,
      384,
      inlineJson: json,
    );
    TlottieEngine.instance.release(first);
    final second = await takeover;
    expect(identical(second, first), isTrue, reason: 'clip handed over');

    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (second!.ready.value < second.frameCount &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(second.ready.value, second.frameCount);
    expect(second.frameAt(second.frameCount - 1), isNotNull);
    TlottieEngine.instance.release(second);
  });
}
