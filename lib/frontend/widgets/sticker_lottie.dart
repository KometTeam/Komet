import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';

class StickerLoadGovernor {
  StickerLoadGovernor._() {
    _budgetMs = _resolveBudgetMs();
    _avgMs = _budgetMs;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static final StickerLoadGovernor instance = StickerLoadGovernor._();

  final ValueNotifier<bool> throttled = ValueNotifier(false);
  double _budgetMs = 1000 / 60;
  double _avgMs = 1000 / 60;

  static double _resolveBudgetMs() {
    final displays = ui.PlatformDispatcher.instance.displays;
    var hz = displays.isEmpty ? 60.0 : displays.first.refreshRate;
    if (!hz.isFinite || hz < 30) hz = 60;
    return 1000 / hz;
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final build = t.buildDuration.inMicroseconds;
      final raster = t.rasterDuration.inMicroseconds;
      final ms = (build > raster ? build : raster) / 1000.0;
      _avgMs = _avgMs * 0.6 + ms * 0.4;
    }
    final enterMs = _budgetMs * 1.5;
    final exitMs = _budgetMs * 0.8;
    if (!throttled.value && _avgMs > enterMs) {
      throttled.value = true;
    } else if (throttled.value && _avgMs < exitMs) {
      throttled.value = false;
    }
  }
}

class _StickerFrames {
  final LottieDrawable drawable;
  final int frameCount;
  final Duration duration;
  final int pxSize;
  final List<ui.Image?> _images;
  ui.Image? _lastImage;
  int bytes = 0;
  int lastUsed = 0;
  int active = 0;

  _StickerFrames({
    required this.drawable,
    required this.frameCount,
    required this.duration,
    required this.pxSize,
  }) : _images = List<ui.Image?>.filled(frameCount, null);

  ui.Image frameAt(int index) {
    final existing = _images[index];
    if (existing != null) {
      _lastImage = existing;
      return existing;
    }

    final last = _lastImage;
    if (last != null && StickerLoadGovernor.instance.throttled.value) {
      return last;
    }

    final progress = frameCount <= 1 ? 0.0 : index / (frameCount - 1);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    drawable.setProgress(progress);
    drawable.draw(
      canvas,
      Rect.fromLTWH(0, 0, pxSize.toDouble(), pxSize.toDouble()),
      fit: BoxFit.contain,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(pxSize, pxSize);
    picture.dispose();

    _images[index] = image;
    _lastImage = image;
    final added = pxSize * pxSize * 4;
    bytes += added;
    _StickerFrameCache.instance._onBytesAdded(added);
    return image;
  }

  void dispose() {
    for (final image in _images) {
      image?.dispose();
    }
    _images.fillRange(0, _images.length, null);
    _lastImage = null;
    bytes = 0;
  }
}

class _StickerFrameCache {
  _StickerFrameCache._();
  static final _StickerFrameCache instance = _StickerFrameCache._();

  static const int _maxBytes = 384 * 1024 * 1024;
  static const double _fps = 30;

  final Map<String, _StickerFrames> _entries = {};
  final Map<String, Future<_StickerFrames?>> _loading = {};
  int _totalBytes = 0;
  int _clock = 0;

  int _tick() => ++_clock;

  Future<_StickerFrames?> acquire(String url, int pxSize) async {
    final key = '$url@$pxSize';
    final cached = _entries[key];
    if (cached != null) {
      cached.lastUsed = _tick();
      cached.active++;
      return cached;
    }
    final pending = _loading[key];
    if (pending != null) {
      final entry = await pending;
      if (entry != null) {
        entry.lastUsed = _tick();
        entry.active++;
      }
      return entry;
    }
    final future = _load(url, pxSize, key);
    _loading[key] = future;
    final entry = await future;
    _loading.remove(key);
    if (entry != null) {
      entry.lastUsed = _tick();
      entry.active++;
    }
    return entry;
  }

  void release(_StickerFrames frames) {
    if (frames.active > 0) frames.active--;
    frames.lastUsed = _tick();
    _evictIfNeeded();
  }

  Future<_StickerFrames?> _load(String url, int pxSize, String key) async {
    try {
      final composition = await NetworkLottie(
        url,
        backgroundLoading: true,
      ).load();
      final durationMs = composition.duration.inMilliseconds;
      var frameCount = (durationMs / 1000 * _fps).round();
      frameCount = frameCount.clamp(1, 120);
      final entry = _StickerFrames(
        drawable: LottieDrawable(composition),
        frameCount: frameCount,
        duration: durationMs <= 0
            ? const Duration(seconds: 1)
            : composition.duration,
        pxSize: pxSize,
      );
      _entries[key] = entry;
      return entry;
    } catch (_) {
      return null;
    }
  }

  void _onBytesAdded(int bytes) {
    _totalBytes += bytes;
    _evictIfNeeded();
  }

  void _evictIfNeeded() {
    if (_totalBytes <= _maxBytes) return;
    final candidates =
        _entries.entries.where((e) => e.value.active <= 0).toList()
          ..sort((a, b) => a.value.lastUsed.compareTo(b.value.lastUsed));
    for (final candidate in candidates) {
      if (_totalBytes <= _maxBytes) break;
      _totalBytes -= candidate.value.bytes;
      candidate.value.dispose();
      _entries.remove(candidate.key);
    }
  }
}

class StickerScrollScope extends InheritedWidget {
  final ValueListenable<bool> isScrolling;

  const StickerScrollScope({
    super.key,
    required this.isScrolling,
    required super.child,
  });

  static ValueListenable<bool>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<StickerScrollScope>()
      ?.isScrolling;

  @override
  bool updateShouldNotify(StickerScrollScope oldWidget) =>
      !identical(oldWidget.isScrolling, isScrolling);
}

class StickerLottie extends StatefulWidget {
  final String lottieUrl;
  final String? fallbackUrl;
  final double? size;
  final int? memCacheWidth;

  const StickerLottie({
    super.key,
    required this.lottieUrl,
    this.fallbackUrl,
    this.size,
    this.memCacheWidth,
  });

  @override
  State<StickerLottie> createState() => _StickerLottieState();
}

class _StickerLottieState extends State<StickerLottie>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _frameIndex = ValueNotifier(0);
  late final Ticker _ticker;
  _StickerFrames? _frames;
  ValueListenable<bool>? _scrollState;
  int? _px;
  bool _started = false;
  bool _showedFrames = false;

  bool get _isScrolling => _scrollState?.value ?? false;
  bool get _canLoad =>
      !_isScrolling && !StickerLoadGovernor.instance.throttled.value;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    StickerLoadGovernor.instance.throttled.addListener(_onGateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = StickerScrollScope.of(context);
    if (!identical(state, _scrollState)) {
      _scrollState?.removeListener(_onGateChanged);
      _scrollState = state;
      _scrollState?.addListener(_onGateChanged);
    }
  }

  @override
  void didUpdateWidget(StickerLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lottieUrl != widget.lottieUrl) {
      _ticker.stop();
      final previous = _frames;
      if (previous != null) _StickerFrameCache.instance.release(previous);
      _frames = null;
      _started = false;
      _showedFrames = false;
    }
  }

  @override
  void dispose() {
    StickerLoadGovernor.instance.throttled.removeListener(_onGateChanged);
    _scrollState?.removeListener(_onGateChanged);
    _ticker.dispose();
    final frames = _frames;
    if (frames != null) _StickerFrameCache.instance.release(frames);
    _frameIndex.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final frames = _frames;
    if (frames == null || frames.frameCount <= 1) return;
    final periodMs = frames.duration.inMilliseconds;
    if (periodMs <= 0) return;
    final t = (elapsed.inMilliseconds % periodMs) / periodMs;
    final index = (t * (frames.frameCount - 1)).round().clamp(
      0,
      frames.frameCount - 1,
    );
    if (index != _frameIndex.value) _frameIndex.value = index;
  }

  void _onGateChanged() {
    if (!mounted) return;
    if (_isScrolling) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    final frames = _frames;
    if (frames != null) {
      if (!_ticker.isActive && frames.frameCount > 1) _ticker.start();
    } else if (_canLoad && !_started) {
      _startLoad();
    }
  }

  void _ensure(double box) {
    if (_frames != null) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final raw = (box * dpr.clamp(1.0, 2.0)).clamp(96.0, 512.0);
    _px = (raw / 32).ceil() * 32;
    if (_started || !_canLoad) return;
    _startLoad();
  }

  void _startLoad() {
    final px = _px;
    if (_started || px == null) return;
    _started = true;
    _StickerFrameCache.instance.acquire(widget.lottieUrl, px).then((frames) {
      if (frames == null) return;
      if (!mounted) {
        _StickerFrameCache.instance.release(frames);
        return;
      }
      setState(() => _frames = frames);
      if (!_isScrolling && frames.frameCount > 1) _ticker.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box =
            widget.size ??
            (constraints.hasBoundedWidth
                ? constraints.biggest.shortestSide
                : 96.0);
        _ensure(box);
        final frames = _frames;
        if (frames == null || (_isScrolling && !_showedFrames)) {
          return _fallback(box);
        }
        _showedFrames = true;
        return ValueListenableBuilder<int>(
          valueListenable: _frameIndex,
          builder: (_, index, _) => RawImage(
            image: frames.frameAt(index),
            width: box,
            height: box,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }

  Widget _fallback(double box) {
    final url = widget.fallbackUrl ?? '';
    final blank = SizedBox(width: box, height: box);
    if (url.isEmpty) return blank;
    return CachedNetworkImage(
      imageUrl: url,
      width: box,
      height: box,
      fit: BoxFit.contain,
      memCacheWidth: widget.memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => blank,
      errorWidget: (_, _, _) => blank,
    );
  }
}
