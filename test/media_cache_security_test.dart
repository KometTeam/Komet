import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/cache/cache_janitor.dart';
import 'package:komet/core/config/app_cache_limit.dart';
import 'package:komet/core/utils/media_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late HttpServer server;
  HttpOverrides? originalOverrides;
  Completer<void>? slowStarted;
  Completer<void>? releaseSlow;
  setUp(() async {
    originalOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    temp = await Directory.systemTemp.createTemp('komet-cache-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => temp.path,
        );
    MediaCache.resetForTesting();
    AppCacheLimit.current.value = 8;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/slow') {
        slowStarted!.complete();
        await releaseSlow!.future;
      }
      final size = request.uri.path == '/large' ? 16 : 4;
      request.response.contentLength = size;
      request.response.add(List.filled(size, 7));
      await request.response.close();
    });
  });
  tearDown(() async {
    HttpOverrides.global = originalOverrides;
    await server.close(force: true);
    MediaCache.resetForTesting();
    CacheJanitor.instance.resetForTesting();
    AppCacheLimit.current.value = AppCacheLimit.defaultValue;
    await temp.delete(recursive: true);
  });
  test(
    'rejects a file larger than the cache quota without a dangling path',
    () async {
      final file = await MediaCache.getOrDownload(
        'oversize',
        'http://127.0.0.1:${server.port}/large',
      );
      expect(file, isNull);
      expect(await MediaCache.existing('oversize'), isNull);
    },
  );
  test('cache clear prevents a pending download from reappearing', () async {
    slowStarted = Completer<void>();
    releaseSlow = Completer<void>();
    final job = MediaCache.getOrDownload(
      'pending',
      'http://127.0.0.1:${server.port}/slow',
    );
    await slowStarted!.future;
    await MediaCache.clear();
    releaseSlow!.complete();
    expect(await job, isNull);
    expect(await MediaCache.existing('pending'), isNull);
  });

  test(
    'returns the new file when pinned files already exceed the quota',
    () async {
      final pinned = await MediaCache.fileFor(MediaCache.keptName('synthetic'));
      await pinned.writeAsBytes(List.filled(16, 1));
      final file = await MediaCache.getOrDownload(
        'new',
        'http://127.0.0.1:${server.port}/small',
      );
      expect(file, isNotNull);
      expect(await file!.readAsBytes(), [7, 7, 7, 7]);
      expect(await pinned.exists(), isTrue);
    },
  );
}
