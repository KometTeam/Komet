import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform, pid;
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:komet_tlottie/komet_tlottie.dart';

import '../../utils/logger.dart';
import 'tlottie_atlas.dart';
import 'tlottie_disk_cache.dart';
import 'tlottie_frame.dart';
import 'tlottie_worker.dart';

// #***! один анимированный стикер, кадры готовыми ui.Image
class TlottieClip {
  TlottieClip({required this.key, required this.px});

  final String key;
  final int px;

  int frameCount = 0;
  int durationMs = 1000;
  double frameRate = 60;

  AtlasLayout? _layout;
  List<ui.Image?> _pages = const [];
  bool _disposed = false;

  // #***! ready это сколько кадров подряд готово, виджет подписан
  final ValueNotifier<int> ready = ValueNotifier(0);

  bool complete = false;
  int bytes = 0;
  int lastUsed = 0;
  int active = 0;

  bool get playable => frameCount > 0;

  // #***! кадра нет, показываем последний готовый чтоб не мигало
  TlottieFrame? frameAt(int index) {
    final layout = _layout;
    final readyCount = ready.value;
    if (layout == null || readyCount == 0) return null;
    final frame = index < 0 ? 0 : (index < readyCount ? index : readyCount - 1);
    final image = _pages[layout.pageOf(frame)];
    if (image == null) return null;
    return TlottieFrame(
      image,
      ui.Rect.fromLTWH(
        layout.leftOf(frame).toDouble(),
        layout.topOf(frame).toDouble(),
        px.toDouble(),
        px.toDouble(),
      ),
    );
  }

  void _allocate(int count) {
    frameCount = count;
    final layout = _layout = AtlasLayout(px: px, frameCount: count);
    _pages = List<ui.Image?>.filled(layout.pageCount, null);
  }

  bool _setPage(int page, ui.Image image) {
    final layout = _layout;
    if (_disposed || layout == null || page < 0 || page >= _pages.length) {
      image.dispose();
      return false;
    }
    _pages[page]?.dispose();
    _pages[page] = image;
    bytes += layout.bytesOf(page);
    var r = 0;
    for (var p = 0; p < _pages.length && _pages[p] != null; p++) {
      r += layout.framesOn(p);
    }
    if (r != ready.value) ready.value = r;
    return true;
  }

  void dispose() {
    _disposed = true;
    for (final img in _pages) {
      img?.dispose();
    }
    _pages = const [];
    bytes = 0;
    ready.dispose();
  }
}

class _Job {
  _Job(this.clip, this.url, this.cachePath, {required this.keep});

  final TlottieClip clip;
  final String url;
  final String? cachePath;
  final Completer<TlottieClip?> completer = Completer();
  bool keep;
  Object? task;
  _Worker? worker;
}

class _Worker {
  _Worker(this.isolate, this.port, this.inbox, this.exit);

  final Isolate isolate;
  final SendPort port;
  final ReceivePort inbox;
  final ReceivePort exit;
  int? jobId;
}

// #***! движок анимированных стикеров, пул изолятов и кэш
class TlottieEngine {
  TlottieEngine._();
  static final TlottieEngine instance = TlottieEngine._();

  static String? debugLibraryPath;

  // #***! под кадры в памяти 192 МБ, дальше LRU
  static const int _maxBytes = 192 * 1024 * 1024;
  static const int _maxConcurrentPageDecodes = 2;
  static const Duration _stalePagesAge = Duration(days: 1);

  // #***! _loading схлопывает параллельные запросы одного стикера
  final Map<String, TlottieClip> _clips = {};
  final Map<String, Future<TlottieClip?>> _loading = {};
  final Map<int, _Job> _jobs = {};
  final Map<String, int> _jobByKey = {};
  final Set<TlottieClip> _retired = {};

  final List<_Worker> _workers = [];
  final Queue<int> _loadQueue = Queue();
  final Queue<int> _renderQueue = Queue();
  Future<void>? _poolFuture;
  late final String _pagesDir =
      '${Directory.systemTemp.path}/tlottie_pages/$pid';

  int _totalBytes = 0;
  int _clock = 0;
  int _nextJobId = 1;

  int _activePageDecodes = 0;
  final Queue<Future<void> Function()> _pageDecodeQueue = Queue();

  bool? _available;

  int _tick() => ++_clock;
  String _keyFor(String url, int px) => '$url@$px';

  // #***! без нативки движок недоступен
  bool get available =>
      _available ??= TlottieBindings.open(path: debugLibraryPath) != null;

  // #***! пул изолятов поднимается при первом стикере
  Future<void> _ensurePool() => _poolFuture ??= () async {
    await _prunePagesDir();
    final count = (Platform.numberOfProcessors - 1).clamp(1, 3);
    for (var i = 0; i < count; i++) {
      _workers.add(await _spawnWorker());
    }
  }();

  Future<void> _prunePagesDir() async {
    try {
      final own = Directory(_pagesDir);
      if (await own.exists()) await own.delete(recursive: true);
      final root = own.parent;
      if (!await root.exists()) return;
      final now = DateTime.now();
      await for (final entry in root.list()) {
        final stat = await entry.stat();
        if (now.difference(stat.modified) > _stalePagesAge) {
          await entry.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  Future<_Worker> _spawnWorker() async {
    final inbox = ReceivePort();
    final exit = ReceivePort();
    final isolate = await Isolate.spawn(
      tlottieWorkerMain,
      WorkerConfig(toMain: inbox.sendPort, pagesDir: _pagesDir),
      onExit: exit.sendPort,
    );
    final messages = inbox.asBroadcastStream();
    final port = await messages.first as SendPort;
    final worker = _Worker(isolate, port, inbox, exit);
    messages.listen((message) => _onWorkerMessage(worker, message));
    exit.listen((_) => unawaited(_onWorkerExit(worker)));
    return worker;
  }

  Future<void> _onWorkerExit(_Worker worker) async {
    worker.inbox.close();
    worker.exit.close();
    final jobId = worker.jobId;
    worker.jobId = null;
    if (jobId != null) _fail(jobId, 'worker exited');
    final index = _workers.indexOf(worker);
    if (index < 0) return;
    logger.w('tlottie worker exited, respawning');
    _workers[index] = await _spawnWorker();
    _dispatch();
  }

  void _enqueue(int jobId, Object task) {
    final job = _jobs[jobId];
    if (job == null) return;
    job.task = task;
    (task is LoadJob ? _loadQueue : _renderQueue).add(jobId);
    if (_workers.isEmpty) {
      unawaited(_ensurePool().then((_) => _dispatch()));
    } else {
      _dispatch();
    }
  }

  void _dispatch() {
    for (final worker in _workers) {
      if (worker.jobId != null) continue;
      final jobId = _nextQueued();
      if (jobId == null) return;
      final job = _jobs[jobId]!;
      final task = job.task!;
      job
        ..task = null
        ..worker = worker;
      worker.jobId = jobId;
      worker.port.send(task);
    }
  }

  int? _nextQueued() {
    for (final queue in [_loadQueue, _renderQueue]) {
      while (queue.isNotEmpty) {
        final jobId = queue.removeFirst();
        if (_jobs[jobId]?.task != null) return jobId;
      }
    }
    return null;
  }

  // #***! роутер сообщений от воркеров
  void _onWorkerMessage(_Worker worker, dynamic message) {
    if (message is WorkerIdle) {
      final job = _jobs[worker.jobId];
      if (identical(job?.worker, worker)) job!.worker = null;
      worker.jobId = null;
      _dispatch();
    } else if (message is ClipMeta) {
      _onMeta(message);
    } else if (message is RenderedPage) {
      _onPage(message);
    } else if (message is RenderDone) {
      _onDone(message);
    } else if (message is LoadMiss) {
      unawaited(_onMiss(message));
    } else if (message is CacheWritten) {
      TlottieDiskCache.instance.noteWritten();
    } else if (message is RenderError) {
      _onError(message);
    }
  }

  void _onMeta(ClipMeta meta) {
    final job = _jobs[meta.jobId];
    if (job == null) return;
    final clip = job.clip
      ..frameRate = meta.frameRate
      ..durationMs = meta.durationMs;
    clip._allocate(meta.totalFrame);
    if (!job.completer.isCompleted) job.completer.complete(clip);
  }

  void _onPage(RenderedPage message) {
    final job = _jobs[message.jobId];
    final layout = job?.clip._layout;
    if (job == null || layout == null) {
      _dropPageFile(message.path);
      return;
    }
    final clip = job.clip;
    final page = message.page;
    _schedulePageDecode(() async {
      try {
        ui.Image? image;
        for (var attempt = 0; image == null && attempt < 2; attempt++) {
          try {
            image = await _decodePage(
              message.path,
              layout.widthOf(page),
              layout.heightOf(page),
            );
          } catch (e) {
            if (attempt == 1) {
              logger.w('tlottie page decode failed (${job.url}): $e');
            }
          }
        }
        if (image == null) {
          _detach(clip);
          return;
        }
        if (!identical(_clips[clip.key], clip)) {
          image.dispose();
          return;
        }
        if (clip._setPage(page, image)) {
          _totalBytes += layout.bytesOf(page);
          _evictIfNeeded();
        }
      } finally {
        _dropPageFile(message.path);
        _releasePageDecode();
      }
    });
  }

  void _dropPageFile(String path) {
    unawaited(File(path).delete().then((_) {}, onError: (_) {}));
  }

  Future<ui.Image> _decodePage(String path, int width, int height) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      pixelFormat: ui.PixelFormat.bgra8888,
    );
    try {
      final codec = await descriptor.instantiateCodec();
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }

  void _schedulePageDecode(Future<void> Function() decode) {
    if (_activePageDecodes < _maxConcurrentPageDecodes) {
      _activePageDecodes++;
      unawaited(decode());
    } else {
      _pageDecodeQueue.add(decode);
    }
  }

  void _releasePageDecode() {
    if (_pageDecodeQueue.isNotEmpty) {
      unawaited(_pageDecodeQueue.removeFirst()());
    } else {
      _activePageDecodes--;
    }
  }

  void _onDone(RenderDone done) {
    final job = _forget(done.jobId);
    job?.clip.complete = true;
  }

  Future<void> _onMiss(LoadMiss miss) async {
    final job = _jobs[miss.jobId];
    if (job == null) return;
    final json = await _fetchJson(job.url);
    if (!identical(_jobs[miss.jobId], job)) return;
    if (json == null) {
      _fail(miss.jobId, 'json unavailable');
      return;
    }
    _enqueueRender(miss.jobId, job, json);
  }

  void _enqueueRender(int jobId, _Job job, Uint8List json) {
    _enqueue(
      jobId,
      RenderJob(
        jobId: jobId,
        json: json,
        px: job.clip.px,
        cachePath: job.cachePath,
        libPath: debugLibraryPath,
      ),
    );
  }

  void _onError(RenderError error) {
    final job = _jobs[error.jobId];
    if (job == null) return;
    logger.w('tlottie render failed (${job.url}): ${error.message}');
    _fail(error.jobId, error.message);
  }

  _Job? _forget(int jobId) {
    final job = _jobs.remove(jobId);
    if (job != null && _jobByKey[job.clip.key] == jobId) {
      _jobByKey.remove(job.clip.key);
    }
    return job;
  }

  void _fail(int jobId, String reason) {
    final job = _forget(jobId);
    if (job == null) return;
    if (!job.completer.isCompleted) job.completer.complete(null);
    if (job.clip.frameCount == 0) {
      _clips.remove(job.clip.key);
      job.clip.dispose();
    }
  }

  void _cancel(int jobId) {
    final job = _forget(jobId);
    if (job == null) return;
    job.worker?.port.send(CancelJob(jobId));
    if (!job.completer.isCompleted) job.completer.complete(null);
    final clip = job.clip;
    if (identical(_clips[clip.key], clip)) _clips.remove(clip.key);
    if (clip.active <= 0) _dispose(clip);
  }

  void _detach(TlottieClip clip) {
    if (!identical(_clips[clip.key], clip)) return;
    _clips.remove(clip.key);
    final jobId = _jobByKey[clip.key];
    if (jobId != null && identical(_jobs[jobId]?.clip, clip)) _cancel(jobId);
    if (clip.active <= 0) {
      _dispose(clip);
    } else {
      _retired.add(clip);
    }
  }

  void _dispose(TlottieClip clip) {
    _retired.remove(clip);
    _totalBytes -= clip.bytes;
    clip.dispose();
  }

  // #***! кэш в памяти, потом диск, потом рендер
  Future<TlottieClip?> acquire(String url, int px, {String? inlineJson}) async {
    if (!available) return null;
    final cached = _clips[_keyFor(url, px)];
    if (cached != null) return _retain(cached);
    final clip = await _start(url, px, inlineJson, keep: false);
    return clip == null ? null : _retain(clip);
  }

  TlottieClip _retain(TlottieClip clip) {
    clip.lastUsed = _tick();
    clip.active++;
    return clip;
  }

  Future<TlottieClip?> _start(
    String url,
    int px,
    String? inlineJson, {
    required bool keep,
  }) {
    final key = _keyFor(url, px);
    final cached = _clips[key];
    if (cached != null) {
      if (keep) _jobs[_jobByKey[key]]?.keep = true;
      return Future.value(cached);
    }
    final pending = _loading[key];
    if (pending != null) return pending;
    final future = _load(url, px, key, inlineJson, keep: keep);
    _loading[key] = future;
    return future.whenComplete(() => _loading.remove(key));
  }

  Future<TlottieClip?> _load(
    String url,
    int px,
    String key,
    String? inlineJson, {
    required bool keep,
  }) async {
    String? cachePath;
    try {
      cachePath = await TlottieDiskCache.instance.pathFor(url, px);
    } catch (e) {
      logger.w('tlottie disk cache unavailable: $e');
    }
    final clip = TlottieClip(key: key, px: px);
    _clips[key] = clip;
    final jobId = _nextJobId++;
    final job = _Job(clip, url, cachePath, keep: keep);
    _jobs[jobId] = job;
    _jobByKey[key] = jobId;

    if (inlineJson != null) {
      _enqueueRender(jobId, job, utf8.encode(inlineJson));
    } else if (cachePath == null) {
      unawaited(_onMiss(LoadMiss(jobId)));
    } else {
      _enqueue(jobId, LoadJob(jobId: jobId, path: cachePath, px: px));
    }
    return job.completer.future;
  }

  // #***! джейсон анимации качаем обычным кэшем файлов
  Future<Uint8List?> _fetchJson(String url) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(url);
      return await file.readAsBytes();
    } catch (e) {
      logger.w('tlottie fetch failed ($url): $e');
      return null;
    }
  }

  // #***! прогрев, рендерим пока стикер ещё не на экране
  Future<void> prewarm(String url, int px) async {
    if (!available) return;
    await _start(url, px, null, keep: true);
  }

  // #***! клип живёт пока его кто то использует
  void release(TlottieClip clip) {
    if (clip.active > 0) clip.active--;
    clip.lastUsed = _tick();
    if (clip.active <= 0) {
      if (_retired.contains(clip)) {
        _dispose(clip);
        return;
      }
      final jobId = _jobByKey[clip.key];
      final job = jobId == null ? null : _jobs[jobId];
      if (job != null && identical(job.clip, clip) && !job.keep) {
        _cancel(jobId!);
        return;
      }
    }
    _evictIfNeeded();
  }

  // #***! LRU когда кадры в памяти перевалили за лимит
  void _evictIfNeeded() {
    if (_totalBytes <= _maxBytes) return;
    final candidates =
        _clips.values
            .where((c) => c.active <= 0 && !_loading.containsKey(c.key))
            .toList()
          ..sort((a, b) => a.lastUsed.compareTo(b.lastUsed));
    for (final clip in candidates) {
      if (_totalBytes <= _maxBytes) break;
      _clips.remove(clip.key);
      final jobId = _jobByKey[clip.key];
      if (jobId != null && identical(_jobs[jobId]?.clip, clip)) {
        _cancel(jobId);
      } else {
        _dispose(clip);
      }
    }
  }
}
