import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/cache/cache_janitor.dart';
import 'package:komet/core/config/app_cache_limit.dart';
import 'package:komet/core/utils/media_cache.dart';
import 'package:komet/core/utils/media_cache_names.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('komet-janitor-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => root.path,
        );
  });

  tearDownAll(() => root.delete(recursive: true));

  setUp(() {
    for (final entity in root.listSync()) {
      entity.deleteSync(recursive: true);
    }
    MediaCache.resetForTesting();
    CacheJanitor.instance.resetForTesting();
  });

  tearDown(() {
    CacheJanitor.instance.resetForTesting();
    AppCacheLimit.current.value = AppCacheLimit.defaultValue;
  });

  Future<File> place(File file, int size, Duration age) async {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(List.filled(size, 1));
    await file.setLastModified(DateTime.now().subtract(age));
    return file;
  }

  Future<File> media(String name, int size, Duration age) async =>
      place(await MediaCache.fileFor(name), size, age);

  Future<File> image(String name, int size, Duration age) => place(
    File(p.join(root.path, DefaultCacheManager.key, name)),
    size,
    age,
  );

  Future<File> frames(String name, int size, Duration age) =>
      place(File(p.join(root.path, 'tlottie_frames', name)), size, age);

  test('cache file names map to the kind of media they hold', () {
    expect(
      mediaCacheKindOf(avatarCacheName('https://cdn.test/a.jpg')),
      MediaCacheKind.photo,
    );
    expect(mediaCacheKindOf(videoPreviewCacheName(5)), MediaCacheKind.video);
    expect(mediaCacheKindOf(gifCacheName(6)), MediaCacheKind.video);
    expect(mediaCacheKindOf(storyVideoCacheName(1, 2)), MediaCacheKind.video);
    expect(
      mediaCacheKindOf(voiceCacheName(audioId: 7, messageId: '8')),
      MediaCacheKind.voice,
    );
    expect(
      mediaCacheKindOf(voiceCacheName(messageId: '-3')),
      MediaCacheKind.voice,
    );
    expect(mediaCacheKindOf('12_track.ogg'), MediaCacheKind.file);
    expect(mediaCacheKindOf('12_report.pdf'), MediaCacheKind.file);
    expect(
      mediaCacheKindOf(MediaCache.keptName('photo_1.jpg')),
      MediaCacheKind.kept,
    );
  });

  test('trim drops the least recently used files across caches', () async {
    AppCacheLimit.current.value = 100;
    final oldVideo = await media('video_1.mp4', 60, const Duration(days: 3));
    final oldImage = await image('a.jpg', 60, const Duration(days: 2));
    final document = await media('1_doc.pdf', 30, const Duration(hours: 1));
    final fresh = await media('photo_9.jpg', 40, Duration.zero);
    final kept = await media(
      MediaCache.keptName('photo_2.jpg'),
      50,
      const Duration(days: 10),
    );

    await CacheJanitor.instance.trim();

    expect(await oldVideo.exists(), isFalse);
    expect(await oldImage.exists(), isFalse);
    expect(await document.exists(), isTrue);
    expect(await fresh.exists(), isTrue);
    expect(await kept.exists(), isTrue);
  });

  test('trim keeps everything when the cache is unlimited', () async {
    AppCacheLimit.current.value = AppCacheLimit.unlimited;
    final old = await media('video_1.mp4', 500, const Duration(days: 30));

    await CacheJanitor.instance.trim();

    expect(await old.exists(), isTrue);
  });

  test('scan groups usage by kind and clear removes only chosen kinds', () async {
    const day = Duration(days: 1);
    await media('photo_1.jpg', 10, day);
    await media('video_1.mp4', 20, day);
    await media('5.ogg', 30, day);
    await media('7_archive.zip', 40, day);
    await media(MediaCache.keptName('video_2.mp4'), 50, day);
    await image('b.webp', 60, day);
    await image('c.json', 70, day);
    await frames('x_256.ktlf', 80, day);

    final report = await CacheJanitor.instance.scan();
    expect(report.of(StorageCategory.photos), 70);
    expect(report.of(StorageCategory.videos), 20);
    expect(report.of(StorageCategory.voice), 30);
    expect(report.of(StorageCategory.files), 40);
    expect(report.of(StorageCategory.keptMedia), 50);
    expect(report.of(StorageCategory.stickers), 150);

    final freed = await CacheJanitor.instance.clear({
      StorageCategory.videos,
      StorageCategory.stickers,
      StorageCategory.database,
    });
    expect(freed, 170);

    final after = await CacheJanitor.instance.scan();
    expect(after.of(StorageCategory.videos), 0);
    expect(after.of(StorageCategory.stickers), 0);
    expect(after.of(StorageCategory.photos), 70);
    expect(after.of(StorageCategory.keptMedia), 50);
  });

  test('clearing a downloaded file updates its presence flag', () async {
    await media('3_notes.txt', 10, const Duration(days: 1));
    final presence = MediaCache.presence('3_notes.txt');
    await MediaCache.existing('3_notes.txt');
    expect(presence.value, isTrue);

    await CacheJanitor.instance.clear({StorageCategory.files});

    expect(presence.value, isFalse);
  });
}
