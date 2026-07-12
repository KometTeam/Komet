import 'dart:async';
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

class LottieHoldScope extends InheritedWidget {
  final ValueListenable<bool> isHeld;

  const LottieHoldScope({
    super.key,
    required this.isHeld,
    required super.child,
  });

  static ValueListenable<bool>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LottieHoldScope>()
      ?.isHeld;

  @override
  bool updateShouldNotify(LottieHoldScope oldWidget) =>
      !identical(oldWidget.isHeld, isHeld);
}

class LottiePlayer extends StatefulWidget {
  final String lottieUrl;
  final String? fallbackUrl;
  final double? size;
  final int? memCacheWidth;
  final bool shimmer;
  final bool eager;

  const LottiePlayer({
    super.key,
    required this.lottieUrl,
    this.fallbackUrl,
    this.size,
    this.memCacheWidth,
    this.shimmer = true,
    this.eager = false,
  });

  @override
  State<LottiePlayer> createState() => _LottiePlayerState();
}

class _LottiePlayerState extends State<LottiePlayer>
    with SingleTickerProviderStateMixin {
  static const int _leadFrames = 6;
  static const double _slowSpeed = 0.5;
  static const double _rampMs = 200.0;

  final ValueNotifier<int> _frameIndex = ValueNotifier(0);
  late final Ticker _ticker;
  late final bool _native;
  RlottieClip? _clip;
  ValueListenable<bool>? _scrollState;
  ValueListenable<bool>? _holdState;
  int? _px;
  bool _started = false;
  bool _showedFrames = false;
  Timer? _deferTimer;

  static const Duration _maxLoadDefer = Duration(milliseconds: 700);

  double _speed = 1.0;
  double _targetSpeed = 1.0;
  double _playheadMs = 0.0;
  double? _lastElapsedMs;

  bool get _isScrolling => _scrollState?.value ?? false;
  bool get _isHeld => _holdState?.value ?? false;
  bool get _canLoad =>
      !_isScrolling &&
      !_isHeld &&
      (widget.eager || !LottieLoadGovernor.instance.throttled.value);

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
    final hold = LottieHoldScope.of(context);
    if (!identical(hold, _holdState)) {
      _holdState?.removeListener(_onGateChanged);
      _holdState = hold;
      _holdState?.addListener(_onGateChanged);
    }
  }

  @override
  void didUpdateWidget(LottiePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lottieUrl != widget.lottieUrl) {
      _ticker.stop();
      _releaseClip();
      _deferTimer?.cancel();
      _deferTimer = null;
      _started = false;
      _showedFrames = false;
      _playheadMs = 0.0;
      _speed = 1.0;
      _targetSpeed = _isScrolling ? _slowSpeed : 1.0;
      _lastElapsedMs = null;
    }
  }

  @override
  void dispose() {
    _deferTimer?.cancel();
    LottieLoadGovernor.instance.throttled.removeListener(_onGateChanged);
    _scrollState?.removeListener(_onGateChanged);
    _holdState?.removeListener(_onGateChanged);
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

    final nowMs = elapsed.inMicroseconds / 1000.0;
    final last = _lastElapsedMs;
    _lastElapsedMs = nowMs;
    if (last == null) return;
    var dt = nowMs - last;
    if (dt < 0) dt = 0;
    if (dt > 64) dt = 64;

    if (_speed != _targetSpeed) {
      final step = dt / _rampMs * (1.0 - _slowSpeed);
      final diff = _targetSpeed - _speed;
      _speed = diff.abs() <= step ? _targetSpeed : _speed + step * diff.sign;
    }

    _playheadMs = (_playheadMs + dt * _speed) % periodMs;
    final t = _playheadMs / periodMs;
    final index =
        (t * (clip.frameCount - 1)).round().clamp(0, clip.frameCount - 1);
    if (index != _frameIndex.value) _frameIndex.value = index;
  }

  void _onGateChanged() {
    if (!mounted) return;
    _targetSpeed = _isScrolling ? _slowSpeed : 1.0;
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
    if (clip.frameCount <= 1) return;
    final lead = clip.frameCount < _leadFrames ? clip.frameCount : _leadFrames;
    if (clip.ready.value >= lead && !_ticker.isActive) {
      _lastElapsedMs = null;
      _ticker.start();
    }
  }

  void _ensure(double box) {
    if (_clip != null) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final raw = (box * dpr.clamp(1.0, 2.0)).clamp(96.0, 384.0);
    _px = (raw / 32).ceil() * 32;
    if (_started) return;
    if (_canLoad) {
      _startLoad();
    } else if (!_isScrolling && !_isHeld) {
      _deferTimer ??= Timer(_maxLoadDefer, _forceDeferredLoad);
    }
  }

  void _forceDeferredLoad() {
    _deferTimer = null;
    if (mounted && !_started && _clip == null && !_isScrolling && !_isHeld) {
      _startLoad();
    }
  }

  void _startLoad() {
    final px = _px;
    if (_started || px == null) return;
    _deferTimer?.cancel();
    _deferTimer = null;
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
    if (url.isEmpty) {
      return widget.shimmer
          ? LottieShimmer(size: box)
          : SizedBox(width: box, height: box);
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: box,
      height: box,
      fit: BoxFit.contain,
      memCacheWidth: widget.memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => LottieShimmer(size: box),
      errorWidget: (_, _, _) => SizedBox(width: box, height: box),
    );
  }
}

class LottieImage extends StatelessWidget {
  final String? url;
  final String? lottieUrl;
  final double? size;
  final int? memCacheWidth;
  final bool shimmer;
  final bool eager;

  const LottieImage({
    super.key,
    this.url,
    this.lottieUrl,
    this.size,
    this.memCacheWidth,
    this.shimmer = true,
    this.eager = false,
  });

  @override
  Widget build(BuildContext context) {
    if (lottieUrl != null && lottieUrl!.isNotEmpty) {
      return LottiePlayer(
        lottieUrl: lottieUrl!,
        fallbackUrl: url,
        size: size,
        memCacheWidth: memCacheWidth,
        shimmer: shimmer,
        eager: eager,
      );
    }
    return _static();
  }

  Widget _static() {
    final src = url ?? '';
    if (src.isEmpty) return SizedBox(width: size, height: size);
    return CachedNetworkImage(
      imageUrl: src,
      width: size,
      height: size,
      fit: BoxFit.contain,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 120),
      placeholder: (_, _) => LottieShimmer(size: size),
      errorWidget: (_, _, _) => SizedBox(width: size, height: size),
    );
  }
}

class LottieShimmer extends StatefulWidget {
  final double? size;

  const LottieShimmer({super.key, this.size});

  @override
  State<LottieShimmer> createState() => _LottieShimmerState();
}

class _LottieShimmerState extends State<LottieShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurfaceVariant;
    final box = widget.size;
    final inset = box == null ? 2.0 : box * 0.06;
    final radius = box == null ? 8.0 : (box * 0.2).clamp(6.0, 26.0);
    return SizedBox(
      width: box,
      height: box,
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => DecoratedBox(
            decoration: BoxDecoration(
              color: base.withValues(alpha: 0.12 + 0.16 * _controller.value),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
