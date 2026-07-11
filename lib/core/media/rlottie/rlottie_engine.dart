import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../../utils/logger.dart';
import 'rlottie_disk_cache.dart';
import 'rlottie_ffi.dart';
import 'rlottie_worker.dart';

class RlottieClip {
  RlottieClip({required this.key, required this.px});

  final String key;
  final int px;

  int frameCount = 0;
  int durationMs = 1000;
  double frameRate = 60;

  List<ui.Image?> _images = const [];
  ui.Image? _lastImage;

  final ValueNotifier<int> ready = ValueNotifier(0);

  bool complete = false;
  int bytes = 0;
  int lastUsed = 0;
  int active = 0;

  bool get playable => frameCount > 0;

  ui.Image? frameAt(int index) {
    if (index < 0 || index >= _images.length) return _lastImage;
    return _images[index] ?? _lastImage;
  }

  void _allocate(int count) {
    _images = List<ui.Image?>.filled(count, null);
  }

  void _setFrame(int index, ui.Image image) {
    if (index < 0 || index >= _images.length) {
      image.dispose();
      return;
    }
    _images[index] = image;
    _lastImage = image;
    bytes += px * px * 4;
    var r = ready.value;
    while (r < _images.length && _images[r] != null) {
      r++;
    }
    if (r != ready.value) ready.value = r;
  }

  void dispose() {
    for (final img in _images) {
      img?.dispose();
    }
    _images = const [];
    _lastImage = null;
    bytes = 0;
    ready.dispose();
  }
}

class _Job {
  _Job(this.clip, this.url, this.completer);
  final RlottieClip clip;
  final String url;
  final Completer<RlottieClip?> completer;
  List<Uint8List?> rawFrames = const [];
}

class RlottieEngine {
  RlottieEngine._();
  static final RlottieEngine instance = RlottieEngine._();

  static String? debugLibraryPath;

  static const int _maxBytes = 192 * 1024 * 1024;
  static const int _modelCacheBytes = 20 * 1024 * 1024;

  final Map<String, RlottieClip> _clips = {};
  final Map<String, Future<RlottieClip?>> _loading = {};
  final Map<int, _Job> _jobs = {};

  int _totalBytes = 0;
  int _clock = 0;
  int _nextJobId = 1;
  int _rrIndex = 0;

  bool? _available;
  Future<List<SendPort>>? _poolFuture;

  int _tick() => ++_clock;
  String _keyFor(String url, int px) => '$url@$px';

  bool get available {
    return _available ??= () {
      final bindings = RlottieBindings.open(path: debugLibraryPath);
      if (bindings == null) return false;
      bindings.configureModelCache(_modelCacheBytes);
      return true;
    }();
  }

  Future<SendPort> _worker() async {
    final pool = await (_poolFuture ??= _spawnPool());
    return pool[_rrIndex++ % pool.length];
  }

  Future<List<SendPort>> _spawnPool() async {
    final count = (Platform.numberOfProcessors - 1).clamp(1, 3);
    final ports = <SendPort>[];
    for (var i = 0; i < count; i++) {
      final receive = ReceivePort();
      await Isolate.spawn(rlottieWorkerMain, receive.sendPort);
      final broadcast = receive.asBroadcastStream();
      final port = await broadcast.first as SendPort;
      broadcast.listen(_onWorkerMessage);
      ports.add(port);
    }
    return ports;
  }

  void _onWorkerMessage(dynamic message) {
    if (message is ClipMeta) {
      _onMeta(message);
    } else if (message is RenderedFrame) {
      _onFrame(message);
    } else if (message is RenderDone) {
      _onDone(message);
    } else if (message is RenderError) {
      _onError(message);
    }
  }

  void _onMeta(ClipMeta meta) {
    final job = _jobs[meta.jobId];
    if (job == null) return;
    final clip = job.clip
      ..frameCount = meta.totalFrame
      ..frameRate = meta.frameRate
      ..durationMs = meta.durationMs;
    clip._allocate(meta.totalFrame);
    job.rawFrames = List<Uint8List?>.filled(meta.totalFrame, null);
    if (!job.completer.isCompleted) {
      job.completer.complete(clip);
    }
  }

  void _onFrame(RenderedFrame frame) {
    final job = _jobs[frame.jobId];
    if (job == null) return;
    final bytes = frame.data.materialize().asUint8List();
    if (frame.index < job.rawFrames.length) {
      job.rawFrames[frame.index] = bytes;
    }
    ui.decodeImageFromPixels(
      bytes,
      frame.px,
      frame.px,
      ui.PixelFormat.bgra8888,
      (image) {
        job.clip._setFrame(frame.index, image);
        _totalBytes += frame.px * frame.px * 4;
        _evictIfNeeded();
      },
    );
  }

  void _onDone(RenderDone done) {
    final job = _jobs.remove(done.jobId);
    if (job == null) return;
    final clip = job.clip..complete = true;
    final raw = job.rawFrames;
    if (raw.length == clip.frameCount && !raw.contains(null)) {
      unawaited(RlottieDiskCache.instance.store(
        url: job.url,
        px: clip.px,
        frameCount: clip.frameCount,
        frameRate: clip.frameRate,
        durationMs: clip.durationMs,
        frames: raw.cast<Uint8List>(),
      ));
    }
    job.rawFrames = const [];
  }

  void _onError(RenderError error) {
    final job = _jobs.remove(error.jobId);
    if (job == null) return;
    logger.w('rlottie render failed (${job.url}): ${error.message}');
    if (!job.completer.isCompleted) job.completer.complete(null);
    if (job.clip.frameCount == 0) {
      _clips.remove(job.clip.key);
      job.clip.dispose();
    }
  }

  Future<RlottieClip?> acquire(String url, int px, {String? inlineJson}) async {
    if (!available) return null;
    final key = _keyFor(url, px);

    final cached = _clips[key];
    if (cached != null) {
      cached.lastUsed = _tick();
      cached.active++;
      return cached;
    }
    final pending = _loading[key];
    if (pending != null) {
      final clip = await pending;
      if (clip != null) {
        clip.lastUsed = _tick();
        clip.active++;
      }
      return clip;
    }

    final future = _load(url, px, key, inlineJson);
    _loading[key] = future;
    final clip = await future;
    _loading.remove(key);
    if (clip != null) {
      clip.lastUsed = _tick();
      clip.active++;
    }
    return clip;
  }

  Future<RlottieClip?> _load(
      String url, int px, String key, String? inlineJson) async {
    if (inlineJson == null) {
      final disk = await RlottieDiskCache.instance.load(url, px);
      if (disk != null) {
        final clip = RlottieClip(key: key, px: px)
          ..frameCount = disk.frameCount
          ..frameRate = disk.frameRate
          ..durationMs = disk.durationMs;
        clip._allocate(disk.frameCount);
        _clips[key] = clip;
        unawaited(_decodeDiskProgressive(clip, disk));
        return clip;
      }
    }

    final json = inlineJson ?? await _fetchJson(url);
    if (json == null) return null;

    final clip = RlottieClip(key: key, px: px);
    _clips[key] = clip;
    final jobId = _nextJobId++;
    final completer = Completer<RlottieClip?>();
    _jobs[jobId] = _Job(clip, url, completer);

    final port = await _worker();
    port.send(RenderJob(
      jobId: jobId,
      json: json,
      cacheKey: url,
      px: px,
      libPath: debugLibraryPath,
    ));
    return completer.future;
  }

  Future<void> _decodeDiskProgressive(RlottieClip clip, DiskClip disk) async {
    for (var i = 0; i < disk.frameCount; i++) {
      if (!identical(_clips[clip.key], clip)) return;
      final image = await _decode(disk.frames[i], clip.px);
      if (!identical(_clips[clip.key], clip)) {
        image.dispose();
        return;
      }
      clip._setFrame(i, image);
      _totalBytes += clip.px * clip.px * 4;
    }
    clip.complete = true;
    _evictIfNeeded();
  }

  Future<ui.Image> _decode(Uint8List bgra, int px) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        bgra, px, px, ui.PixelFormat.bgra8888, completer.complete);
    return completer.future;
  }

  Future<String?> _fetchJson(String url) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(url);
      return await file.readAsString();
    } catch (e) {
      logger.w('rlottie fetch failed ($url): $e');
      return null;
    }
  }

  Future<void> prewarm(String url, int px) async {
    if (!available) return;
    final clip = await acquire(url, px);
    if (clip != null) release(clip);
  }

  void release(RlottieClip clip) {
    if (clip.active > 0) clip.active--;
    clip.lastUsed = _tick();
    _evictIfNeeded();
  }

  void _evictIfNeeded() {
    if (_totalBytes <= _maxBytes) return;
    final candidates = _clips.values.where((c) => c.active <= 0).toList()
      ..sort((a, b) => a.lastUsed.compareTo(b.lastUsed));
    for (final clip in candidates) {
      if (_totalBytes <= _maxBytes) break;
      _totalBytes -= clip.bytes;
      _clips.remove(clip.key);
      clip.dispose();
    }
  }
}
