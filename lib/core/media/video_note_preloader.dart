import 'dart:async';
import 'dart:collection';
import 'dart:io';

import '../utils/media_cache.dart';

class VideoNotePreloader {
  static const int autoLoadMaxMs = 30000;
  static const int _maxConcurrent = 2;

  static int _running = 0;
  static final Queue<_PreloadJob> _queue = Queue();

  static bool autoLoads(int? durationMs) =>
      durationMs != null && durationMs > 0 && durationMs <= autoLoadMaxMs;

  static Future<File?> load(
    String cacheName,
    Future<String?> Function() resolveUrl, {
    bool priority = false,
    void Function(double progress)? onProgress,
    bool Function()? cancelled,
  }) async {
    final cached = await MediaCache.existing(cacheName);
    if (cached != null) return cached;

    final job = _PreloadJob(cacheName, resolveUrl, onProgress, cancelled);
    if (priority) {
      _queue.addFirst(job);
    } else {
      _queue.addLast(job);
    }
    _pump();
    return job.result.future;
  }

  static void _pump() {
    while (_running < _maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _running++;
      _run(job).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }

  static Future<void> _run(_PreloadJob job) async {
    if (job.cancelled?.call() ?? false) {
      job.result.complete(null);
      return;
    }
    File? file;
    try {
      final url = await job.resolveUrl();
      if (url != null && url.isNotEmpty) {
        file = await MediaCache.getOrDownload(
          job.cacheName,
          url,
          onProgress: job.onProgress,
        );
      }
    } catch (_) {
      file = null;
    }
    if (!job.result.isCompleted) job.result.complete(file);
  }
}

class _PreloadJob {
  _PreloadJob(this.cacheName, this.resolveUrl, this.onProgress, this.cancelled);

  final String cacheName;
  final Future<String?> Function() resolveUrl;
  final void Function(double progress)? onProgress;
  final bool Function()? cancelled;
  final Completer<File?> result = Completer<File?>();
}
