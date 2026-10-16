import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:komet_tlottie/komet_tlottie.dart';

import 'tlottie_atlas.dart';
import 'tlottie_codec.dart';

class WorkerConfig {
  const WorkerConfig({required this.toMain, required this.pagesDir});

  final SendPort toMain;
  final String pagesDir;
}

class LoadJob {
  const LoadJob({required this.jobId, required this.path, required this.px});

  final int jobId;
  final String path;
  final int px;
}

class RenderJob {
  const RenderJob({
    required this.jobId,
    required this.json,
    required this.px,
    this.cachePath,
    this.libPath,
  });

  final int jobId;
  final Uint8List json;
  final int px;
  final String? cachePath;
  final String? libPath;
}

class ClipMeta {
  const ClipMeta({
    required this.jobId,
    required this.totalFrame,
    required this.frameRate,
    required this.durationMs,
  });

  final int jobId;
  final int totalFrame;
  final double frameRate;
  final int durationMs;
}

class RenderedPage {
  const RenderedPage({
    required this.jobId,
    required this.page,
    required this.path,
  });

  final int jobId;
  final int page;
  final String path;
}

class RenderDone {
  const RenderDone(this.jobId);
  final int jobId;
}

class LoadMiss {
  const LoadMiss(this.jobId);
  final int jobId;
}

class CacheWritten {
  const CacheWritten();
}

class WorkerIdle {
  const WorkerIdle();
}

class RenderError {
  const RenderError(this.jobId, this.message);
  final int jobId;
  final String message;
}

class CancelJob {
  const CancelJob(this.jobId);
  final int jobId;
}

const double _maxCacheFps = 30.0;

class _Cancelled implements Exception {
  const _Cancelled();
}

void tlottieWorkerMain(WorkerConfig config) {
  final toMain = config.toMain;
  final port = ReceivePort();
  toMain.send(port.sendPort);

  final cancelled = <int>{};
  final pagesDir = Directory(config.pagesDir)..createSync(recursive: true);
  TlottieBindings? bindings;
  String? boundLibPath;

  Future<void> yieldTo(int jobId) async {
    await Future<void>.delayed(Duration.zero);
    if (cancelled.contains(jobId)) throw const _Cancelled();
  }

  void sendPage(int jobId, int page, Uint8List atlas) {
    final path = '${pagesDir.path}/${jobId}_$page.bgra';
    File(path).writeAsBytesSync(atlas);
    toMain.send(RenderedPage(jobId: jobId, page: page, path: path));
  }

  Future<void> load(LoadJob job) async {
    final file = File(job.path);
    DecodedClip? clip;
    try {
      if (file.existsSync()) clip = TlottieCodec.decode(file.readAsBytesSync());
    } catch (_) {
      clip = null;
    }
    if (clip == null || clip.header.px != job.px) {
      toMain.send(LoadMiss(job.jobId));
      return;
    }
    try {
      file.setLastModifiedSync(DateTime.now());
    } catch (_) {}
    final header = clip.header;
    toMain.send(
      ClipMeta(
        jobId: job.jobId,
        totalFrame: header.frameCount,
        frameRate: header.frameRate,
        durationMs: header.durationMs,
      ),
    );
    final layout = AtlasLayout(px: header.px, frameCount: header.frameCount);
    for (var page = 0; page < layout.pageCount; page++) {
      await yieldTo(job.jobId);
      final atlas = layout.allocate(page);
      final first = page * AtlasLayout.framesPerPage;
      for (var f = first; f < first + layout.framesOn(page); f++) {
        layout.blit(atlas, f, clip.frame(f));
      }
      sendPage(job.jobId, page, atlas);
    }
    toMain.send(RenderDone(job.jobId));
  }

  Future<void> render(RenderJob job) async {
    if (bindings == null || boundLibPath != job.libPath) {
      bindings = TlottieBindings.open(path: job.libPath);
      boundLibPath = job.libPath;
    }
    final tl = bindings;
    if (tl == null) throw StateError('tlottie unavailable');
    final anim = tl.parse(job.json);
    if (anim == null) throw StateError('parse failed');

    final Uint8List frames;
    final EncodedClipHeader header;
    final buffer = calloc<Uint32>(job.px * job.px);
    try {
      final total = tl.frameCount(anim);
      final fps = tl.frameRate(anim);
      final durationMs = fps <= 0 ? 1000 : (total / fps * 1000).round();
      var outCount = total;
      if (fps > _maxCacheFps && total > 1) {
        outCount = (durationMs / 1000.0 * _maxCacheFps).round().clamp(2, total);
      }
      final outFps = durationMs <= 0 ? fps : outCount * 1000.0 / durationMs;
      header = EncodedClipHeader(
        px: job.px,
        frameCount: outCount,
        frameRate: outFps,
        durationMs: durationMs,
      );
      toMain.send(
        ClipMeta(
          jobId: job.jobId,
          totalFrame: outCount,
          frameRate: outFps,
          durationMs: durationMs,
        ),
      );

      final px = job.px;
      final frameBytes = px * px * 4;
      final layout = AtlasLayout(px: px, frameCount: outCount);
      frames = Uint8List(frameBytes * outCount);
      final view = buffer.cast<Uint8>().asTypedList(frameBytes);
      var atlas = layout.allocate(0);
      for (var i = 0; i < outCount; i++) {
        await yieldTo(job.jobId);
        final src = outCount == total
            ? i
            : (i * (total - 1) / (outCount - 1)).round().clamp(0, total - 1);
        if (!tl.render(anim, src, buffer, px)) {
          throw StateError('render failed at frame $src');
        }
        frames.setRange(i * frameBytes, (i + 1) * frameBytes, view);
        layout.blit(atlas, i, view);
        final page = layout.pageOf(i);
        if (i == outCount - 1 || layout.pageOf(i + 1) != page) {
          sendPage(job.jobId, page, atlas);
          if (i < outCount - 1) atlas = layout.allocate(page + 1);
        }
      }
    } finally {
      calloc.free(buffer);
      tl.drop(anim);
    }
    toMain.send(RenderDone(job.jobId));

    final path = job.cachePath;
    if (path == null) return;
    try {
      File(path).writeAsBytesSync(TlottieCodec.encode(header, frames));
      toMain.send(const CacheWritten());
    } catch (_) {}
  }

  Future<void> run(int jobId, Future<void> Function() work) async {
    try {
      await work();
    } on _Cancelled {
      return;
    } catch (e) {
      toMain.send(RenderError(jobId, e.toString()));
    } finally {
      cancelled.remove(jobId);
      toMain.send(const WorkerIdle());
    }
  }

  port.listen((message) {
    if (message is CancelJob) {
      cancelled.add(message.jobId);
    } else if (message is LoadJob) {
      run(message.jobId, () => load(message));
    } else if (message is RenderJob) {
      run(message.jobId, () => render(message));
    }
  });
}
