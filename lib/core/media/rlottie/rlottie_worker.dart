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
      toMain.send(ClipMeta(
        jobId: job.jobId,
        totalFrame: total,
        frameRate: fps,
        durationMs: durationMs,
      ));

      final px = job.px;
      final buffer = calloc<Uint32>(px * px);
      try {
        for (var i = 0; i < total; i++) {
          if (cancelled.contains(job.jobId)) break;
          rl.render(anim, i, buffer, px);
          final rgba = _bgraToRgba(buffer, px * px);
          toMain.send(RenderedFrame(
            jobId: job.jobId,
            index: i,
            data: TransferableTypedData.fromList([rgba]),
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

Uint8List _bgraToRgba(Pointer<Uint32> buffer, int pixels) {
  final src = buffer.asTypedList(pixels);
  final out = Uint8List(pixels * 4);
  for (var i = 0; i < pixels; i++) {
    final v = src[i];
    final o = i * 4;
    out[o] = (v >> 16) & 0xff;
    out[o + 1] = (v >> 8) & 0xff;
    out[o + 2] = v & 0xff;
    out[o + 3] = (v >> 24) & 0xff;
  }
  return out;
}
