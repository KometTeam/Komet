import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lottie/lottie.dart';

import '../../core/media/rlottie/rlottie.dart';

class LottieLoadGovernor {
  LottieLoadGovernor._() {
    _budgetMs = _resolveBudgetMs();
    _avgMs = _budgetMs;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  static final LottieLoadGovernor instance = LottieLoadGovernor._();

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

class LottieScrollScope extends InheritedWidget {
  final ValueListenable<bool> isScrolling;

  const LottieScrollScope({
    super.key,
    required this.isScrolling,
    required super.child,
  });

  static ValueListenable<bool>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LottieScrollScope>()
      ?.isScrolling;

  @override
  bool updateShouldNotify(LottieScrollScope oldWidget) =>
      !identical(oldWidget.isScrolling, isScrolling);
}

class LottiePlayer extends StatefulWidget {
  final String lottieUrl;
  final String? fallbackUrl;
  final double? size;
  final int? memCacheWidth;

  const LottiePlayer({
    super.key,
    required this.lottieUrl,
    this.fallbackUrl,
    this.size,
    this.memCacheWidth,
  });

  @override
  State<LottiePlayer> createState() => _LottiePlayerState();
}

class _LottiePlayerState extends State<LottiePlayer>
    with SingleTickerProviderStateMixin {
  static const int _leadFrames = 6;

  final ValueNotifier<int> _frameIndex = ValueNotifier(0);
  late final Ticker _ticker;
  late final bool _native;
  RlottieClip? _clip;
  ValueListenable<bool>? _scrollState;
  int? _px;
  bool _started = false;
  bool _showedFrames = false;

  bool get _isScrolling => _scrollState?.value ?? false;
  bool get _canLoad =>
      !_isScrolling && !LottieLoadGovernor.instance.throttled.value;

  @override
  void initState() {
    super.initState();
    _native = RlottieEngine.instance.available;
    _ticker = createTicker(_onTick);
    LottieLoadGovernor.instance.throttled.addListener(_onGateChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = LottieScrollScope.of(context);
    if (!identical(state, _scrollState)) {
      _scrollState?.removeListener(_onGateChanged);
      _scrollState = state;
      _scrollState?.addListener(_onGateChanged);
    }
  }

  @override
  void didUpdateWidget(LottiePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lottieUrl != widget.lottieUrl) {
      _ticker.stop();
      _releaseClip();
      _started = false;
      _showedFrames = false;
    }
  }

  @override
  void dispose() {
    LottieLoadGovernor.instance.throttled.removeListener(_onGateChanged);
    _scrollState?.removeListener(_onGateChanged);
    _ticker.dispose();
    _releaseClip();
    _frameIndex.dispose();
    super.dispose();
  }

  void _releaseClip() {
    final clip = _clip;
    if (clip != null) {
      clip.ready.removeListener(_onReady);
      RlottieEngine.instance.release(clip);
      _clip = null;
    }
  }

  void _onTick(Duration elapsed) {
    final clip = _clip;
    if (clip == null || clip.frameCount <= 1) return;
    final periodMs = clip.durationMs;
    if (periodMs <= 0) return;
    final t = (elapsed.inMilliseconds % periodMs) / periodMs;
    final index = (t * (clip.frameCount - 1)).round().clamp(
      0,
      clip.frameCount - 1,
    );
    if (index != _frameIndex.value) _frameIndex.value = index;
  }

  void _onGateChanged() {
    if (!mounted) return;
    if (_isScrolling) {
      if (_ticker.isActive) _ticker.stop();
      return;
    }
    final clip = _clip;
    if (clip != null) {
      _maybeStartTicker(clip);
    } else if (_canLoad && !_started) {
      _startLoad();
    }
  }

  void _onReady() {
    if (!mounted) return;
    final clip = _clip;
    if (clip != null) _maybeStartTicker(clip);
    if (mounted) setState(() {});
  }

  void _maybeStartTicker(RlottieClip clip) {
    if (_isScrolling || clip.frameCount <= 1) return;
    final lead = clip.frameCount < _leadFrames ? clip.frameCount : _leadFrames;
    if (clip.ready.value >= lead && !_ticker.isActive) _ticker.start();
  }

  void _ensure(double box) {
    if (_clip != null) return;
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
    RlottieEngine.instance.acquire(widget.lottieUrl, px).then((clip) {
      if (clip == null) return;
      if (!mounted) {
        RlottieEngine.instance.release(clip);
        return;
      }
      clip.ready.addListener(_onReady);
      setState(() => _clip = clip);
      _maybeStartTicker(clip);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_native) return _nativeFallback();
    return LayoutBuilder(
      builder: (context, constraints) {
        final box =
            widget.size ??
            (constraints.hasBoundedWidth
                ? constraints.biggest.shortestSide
                : 96.0);
        _ensure(box);
        final clip = _clip;
        if (clip == null ||
            clip.ready.value == 0 ||
            (_isScrolling && !_showedFrames)) {
          return _staticFallback(box);
        }
        _showedFrames = true;
        return ValueListenableBuilder<int>(
          valueListenable: _frameIndex,
          builder: (_, index, _) => RawImage(
            image: clip.frameAt(index),
            width: box,
            height: box,
            fit: BoxFit.contain,
          ),
        );
      },
    );
  }

  Widget _nativeFallback() {
    return Lottie.network(
      widget.lottieUrl,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      frameRate: FrameRate.max,
      errorBuilder: (context, _, _) => _staticFallback(widget.size ?? 96.0),
    );
  }

  Widget _staticFallback(double box) {
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

class LottieImage extends StatelessWidget {
  final String? url;
  final String? lottieUrl;
  final double? size;
  final int? memCacheWidth;

  const LottieImage({
    super.key,
    this.url,
    this.lottieUrl,
    this.size,
    this.memCacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (lottieUrl != null && lottieUrl!.isNotEmpty) {
      return LottiePlayer(
        lottieUrl: lottieUrl!,
        fallbackUrl: url,
        size: size,
        memCacheWidth: memCacheWidth,
      );
    }
    return _static();
  }

  Widget _static() {
    final src = url ?? '';
    final blank = SizedBox(width: size, height: size);
    if (src.isEmpty) return blank;
    return CachedNetworkImage(
      imageUrl: src,
      width: size,
      height: size,
      fit: BoxFit.contain,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => blank,
      errorWidget: (_, _, _) => blank,
    );
  }
}
