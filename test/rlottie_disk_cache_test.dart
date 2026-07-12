import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/rlottie/rlottie_disk_cache.dart';
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

  test('disk cache round-trips rendered frames', () async {
    final tmp = Directory.systemTemp.createTempSync('rlottie_cache_test');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);

    const px = 32;
    const frameCount = 5;
    final frames = List.generate(frameCount, (f) {
      final buf = Uint8List(px * px * 4);
      for (var i = 0; i < buf.length; i++) {
        buf[i] = (f * 37 + i) & 0xff;
      }
      return buf;
    });

    const url = 'https://example.com/anim.json';
    await RlottieDiskCache.instance.store(
      url: url,
      px: px,
      frameCount: frameCount,
      frameRate: 30,
      durationMs: 166,
      frames: frames,
    );

    final loaded = await RlottieDiskCache.instance.load(url, px);
    expect(loaded, isNotNull);
    expect(loaded!.px, px);
    expect(loaded.frameCount, frameCount);
    expect(loaded.frameRate, 30);
    expect(loaded.durationMs, 166);
    for (var f = 0; f < frameCount; f++) {
      expect(loaded.frames[f], orderedEquals(frames[f]),
          reason: 'frame $f bytes preserved');
    }

    expect(await RlottieDiskCache.instance.load('https://other/x.json', px),
        isNull);

    tmp.deleteSync(recursive: true);
  });
}
