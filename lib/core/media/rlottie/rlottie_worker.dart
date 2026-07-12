import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'rlottie_ffi.dart';

class RenderJob {
  const RenderJob({
    required this.jobId,
    required this.json,
    required this.cacheKey,
    required this.px,
    this.libPath,
  });

  final int jobId;
  final String json;
  final String cacheKey;
  final int px;
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

class RenderedFrame {
  const RenderedFrame({
    required this.jobId,
    required this.index,
    required this.data,
    required this.px,
  });

  final int jobId;
  final int index;
  final TransferableTypedData data;
  final int px;
}

class RenderDone {
  const RenderDone(this.jobId);
  final int jobId;
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

void rlottieWorkerMain(SendPort toMain) {
  final port = ReceivePort();
  toMain.send(port.sendPort);

  final cancelled = <int>{};
  RlottieBindings? bindings;
  String? boundLibPath;

  port.listen((message) {
    if (message is CancelJob) {
      cancelled.add(message.jobId);
      return;
    }
    if (message is! RenderJob) return;

    final job = message;
    cancelled.remove(job.jobId);

    if (bindings == null || boundLibPath != job.libPath) {
      bindings = RlottieBindings.open(path: job.libPath);
      boundLibPath = job.libPath;
    }
    final rl = bindings;
    if (rl == null) {
      toMain.send(RenderError(job.jobId, 'rlottie unavailable'));
      return;
    }

    final anim = rl.loadFromData(job.json, job.cacheKey);
    if (anim == null) {
      toMain.send(RenderError(job.jobId, 'parse failed'));
      return;
    }

    try {
      final total = rl.totalFrame(anim);
      final fps = rl.frameRate(anim);
      final durationMs = fps <= 0 ? 1000 : (total / fps * 1000).round();

      var outCount = total;
      if (fps > _maxCacheFps && total > 1) {
        outCount = (durationMs / 1000.0 * _maxCacheFps).round().clamp(2, total);
      }
      final outFps = durationMs <= 0 ? fps : outCount * 1000.0 / durationMs;
      toMain.send(ClipMeta(
        jobId: job.jobId,
        totalFrame: outCount,
        frameRate: outFps,
        durationMs: durationMs,
      ));

      final px = job.px;
      final buffer = calloc<Uint32>(px * px);
      final byteView = buffer.cast<Uint8>().asTypedList(px * px * 4);
      try {
        for (var i = 0; i < outCount; i++) {
          if (cancelled.contains(job.jobId)) break;
          final src = outCount == total
              ? i
              : (i * (total - 1) / (outCount - 1)).round().clamp(0, total - 1);
          rl.render(anim, src, buffer, px);
          toMain.send(RenderedFrame(
            jobId: job.jobId,
            index: i,
            data: TransferableTypedData.fromList([Uint8List.fromList(byteView)]),
            px: px,
          ));
        }
      } finally {
        calloc.free(buffer);
      }
      toMain.send(RenderDone(job.jobId));
    } catch (e) {
      toMain.send(RenderError(job.jobId, e.toString()));
    } finally {
      rl.destroy(anim);
      cancelled.remove(job.jobId);
    }
  });
}

