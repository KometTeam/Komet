import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker, TickerCallback;

mixin FirstFrameClock<T> on TransitionRoute<T> {
  _FirstFrameTicker? _clock;

  @override
  AnimationController createAnimationController() {
    assert(!debugTransitionCompleted());
    final clock = _clock = _FirstFrameTicker(navigator!);
    return AnimationController(
      duration: transitionDuration,
      reverseDuration: reverseTransitionDuration,
      debugLabel: debugLabel,
      vsync: clock,
    );
  }

  @override
  TickerFuture didPush() {
    _clock?.holdNextStart();
    return super.didPush();
  }
}

class FirstFramePageRoute<T> extends MaterialPageRoute<T>
    with FirstFrameClock<T> {
  FirstFramePageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });
}

class _FirstFrameTicker implements TickerProvider {
  _FirstFrameTicker(this._vsync);

  final TickerProvider _vsync;
  bool _holdNext = false;

  void holdNextStart() => _holdNext = true;

  static const int _warmupFrames = 3;

  @override
  Ticker createTicker(TickerCallback onTick) {
    var last = Duration.zero;
    var lag = Duration.zero;
    var warmup = 0;
    return _vsync.createTicker((elapsed) {
      if (_holdNext) {
        _holdNext = false;
        warmup = _warmupFrames;
        lag = Duration.zero;
      } else if (elapsed < last) {
        warmup = 0;
        lag = Duration.zero;
      } else if (warmup > 0) {
        warmup--;
        lag += _stallBeyondOneFrame(elapsed - last);
      }
      last = elapsed;
      onTick(elapsed - lag);
    });
  }

  static Duration _stallBeyondOneFrame(Duration gap) {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final rate = views.isEmpty ? 0.0 : views.first.display.refreshRate;
    final frame = Duration(
      microseconds: (Duration.microsecondsPerSecond / (rate > 0 ? rate : 60))
          .round(),
    );
    return gap > frame ? gap - frame : Duration.zero;
  }
}
