import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:komet/core/storage/chat_wallpaper_store.dart';
import 'package:komet/frontend/widgets/chat_wallpaper_view.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('komet_wallpaper_test');
  });

  tearDown(() async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    await dir.delete(recursive: true);
  });

  Future<String> picture(String name) async {
    final path = p.join(dir.path, name);
    await File(
      path,
    ).writeAsBytes(img.encodePng(img.Image(width: 2, height: 2)));
    return path;
  }

  Future<void> decoded(String path) {
    final done = Completer<void>();
    final stream = FileImage(File(path)).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        stream.removeListener(listener);
        done.complete();
      },
      onError: (error, _) {
        stream.removeListener(listener);
        done.completeError(error);
      },
    );
    stream.addListener(listener);
    return done.future;
  }

  bool held(String path) => PaintingBinding.instance.imageCache
      .statusForKey(FileImage(File(path)))
      .live;

  test('the global wallpaper survives an image cache purge', () async {
    final path = await picture('global.png');

    WallpaperImages.holdGlobal(ChatWallpaper.image(path));
    await decoded(path);
    PaintingBinding.instance.imageCache.clear();
    expect(held(path), isTrue);

    WallpaperImages.holdGlobal(null);
    expect(held(path), isFalse);
  });

  test('only the two most recent chat wallpapers stay held', () async {
    final first = await picture('first.png');
    final second = await picture('second.png');
    final third = await picture('third.png');

    WallpaperImages.holdRecent(first);
    WallpaperImages.holdRecent(second);
    WallpaperImages.holdRecent(third);
    await Future.wait([decoded(first), decoded(second), decoded(third)]);
    expect(held(first), isFalse);
    expect(held(second), isTrue);
    expect(held(third), isTrue);

    WallpaperImages.holdRecent(second);
    WallpaperImages.holdRecent(first);
    expect(held(third), isFalse);
    expect(held(second), isTrue);
    expect(held(first), isTrue);
  });
}
