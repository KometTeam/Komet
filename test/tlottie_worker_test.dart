import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/media/tlottie/tlottie_atlas.dart';
import 'package:komet/core/media/tlottie/tlottie_codec.dart';
import 'package:komet/core/media/tlottie/tlottie_worker.dart';

Uint8List _frames(int px, int count) {
  final size = px * px * 4;
  final all = Uint8List(size * count);
  for (var i = 0; i < all.length; i++) {
    all[i] = (i ~/ size * 53 + i * 7) & 0xff;
  }
  return all;
}

void main() {
  late Directory dir;
  late Isolate isolate;
  late ReceivePort receive;
  late StreamIterator<Object?> messages;
  late SendPort worker;

  Future<Object?> next() async {
    await messages.moveNext();
    return messages.current;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tlottie_worker_test');
    receive = ReceivePort();
    isolate = await Isolate.spawn(
      tlottieWorkerMain,
      WorkerConfig(toMain: receive.sendPort, pagesDir: '${dir.path}/pages'),
    );
    messages = StreamIterator(receive);
    worker = await next() as SendPort;
  });

  tearDown(() async {
    isolate.kill(priority: Isolate.immediate);
    receive.close();
    await dir.delete(recursive: true);
  });

  String cached(int px, int count, {String name = 'clip.ktlf'}) {
    final path = '${dir.path}/$name';
    File(path).writeAsBytesSync(
      TlottieCodec.encode(
        EncodedClipHeader(
          px: px,
          frameCount: count,
          frameRate: 30,
          durationMs: 666,
        ),
        _frames(px, count),
      ),
    );
    return path;
  }

  test('a cached clip comes back as atlas pages', () async {
    const px = 8;
    const count = 20;
    final frames = _frames(px, count);
    final path = cached(px, count);

    worker.send(const LoadJob(jobId: 7, path: '', px: px));
    expect(await next(), isA<LoadMiss>());
    expect(await next(), isA<WorkerIdle>());

    worker.send(LoadJob(jobId: 8, path: path, px: px));
    final meta = await next() as ClipMeta;
    expect((meta.jobId, meta.totalFrame, meta.durationMs), (8, count, 666));

    const layout = AtlasLayout(px: px, frameCount: count);
    final pages = <int, Uint8List>{};
    for (var p = 0; p < layout.pageCount; p++) {
      final page = await next() as RenderedPage;
      pages[page.page] = File(page.path).readAsBytesSync();
      File(page.path).deleteSync();
    }
    expect(await next(), isA<RenderDone>());
    expect(await next(), isA<WorkerIdle>());

    final size = px * px * 4;
    for (var f = 0; f < count; f++) {
      final page = pages[layout.pageOf(f)]!;
      final stride = layout.widthOf(layout.pageOf(f)) * 4;
      final start = layout.topOf(f) * stride + layout.leftOf(f) * 4;
      expect(
        page.sublist(start, start + px * 4),
        orderedEquals(frames.sublist(f * size, f * size + px * 4)),
        reason: 'first row of frame $f',
      );
    }
  });

  test('a cached clip of another size is a miss', () async {
    final path = cached(8, 2);

    worker.send(LoadJob(jobId: 1, path: path, px: 16));
    expect(await next(), isA<LoadMiss>());
    expect(await next(), isA<WorkerIdle>());
  });

  test('a failed page write reports the job and keeps the worker', () async {
    final path = cached(8, 20);
    Directory('${dir.path}/pages').deleteSync(recursive: true);
    File('${dir.path}/pages').writeAsStringSync('');

    worker.send(LoadJob(jobId: 2, path: path, px: 8));
    expect(await next(), isA<ClipMeta>());
    final error = await next();
    expect(error, isA<RenderError>());
    expect((error as RenderError).jobId, 2);
    expect(await next(), isA<WorkerIdle>());

    worker.send(const LoadJob(jobId: 3, path: '', px: 8));
    expect(await next(), isA<LoadMiss>());
    expect(await next(), isA<WorkerIdle>());
  });

  test('a cancel sent right after the job stops it before any page', () async {
    final path = cached(8, 40);

    worker.send(LoadJob(jobId: 4, path: path, px: 8));
    worker.send(const CancelJob(4));
    expect(await next(), isA<ClipMeta>());
    expect(await next(), isA<WorkerIdle>());
  });
}
