import 'package:flutter/material.dart';

class AnimatedTextSwap extends StatefulWidget {
  const AnimatedTextSwap({
    super.key,
    required this.showAlternate,
    required this.child,
    required this.alternate,
    this.duration = const Duration(milliseconds: 260),
    this.curve = Curves.easeOutCubic,
    this.slideExtent = 0.45,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final bool showAlternate;
  final Widget child;
  final Widget alternate;
  final Duration duration;
  final Curve curve;
  final double slideExtent;
  final AlignmentGeometry alignment;

  @override
  State<AnimatedTextSwap> createState() => _AnimatedTextSwapState();
}

class _AnimatedTextSwapState extends State<AnimatedTextSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.showAlternate ? 1 : 0,
    );
    _t = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
      reverseCurve: widget.curve.flipped,
    );
  }

  @override
  void didUpdateWidget(AnimatedTextSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.showAlternate != oldWidget.showAlternate) {
      widget.showAlternate ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final t = _t.value;
        if (t <= 0) return widget.child;
        if (t >= 1) return widget.alternate;
        return buildSwapLayout(
          progress: t,
          outgoing: widget.child,
          incoming: widget.alternate,
          slideExtent: widget.slideExtent,
          alignment: widget.alignment,
        );
      },
    );
  }
}

Widget buildSwapLayout({
  required double progress,
  required Widget outgoing,
  required Widget incoming,
  required double slideExtent,
  required AlignmentGeometry alignment,
}) {
  return Stack(
    alignment: alignment,
    children: [
      Opacity(
        opacity: 1 - progress,
        child: FractionalTranslation(
          translation: Offset(0, -slideExtent * progress),
          child: outgoing,
        ),
      ),
      Opacity(
        opacity: progress,
        child: FractionalTranslation(
          translation: Offset(0, slideExtent * (1 - progress)),
          child: incoming,
        ),
      ),
    ],
  );
}

class AnimatedValueSwap<T> extends StatefulWidget {
  const AnimatedValueSwap({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 260),
    this.curve = Curves.easeOutCubic,
    this.slideExtent = 0.45,
    this.alignment = AlignmentDirectional.center,
  });

  final T value;
  final Widget Function(BuildContext context, T value) builder;
  final Duration duration;
  final Curve curve;
  final double slideExtent;
  final AlignmentGeometry alignment;

  @override
  State<AnimatedValueSwap<T>> createState() => _AnimatedValueSwapState<T>();
}

class _AnimatedValueSwapState<T> extends State<AnimatedValueSwap<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  late T _current = widget.value;
  T? _previous;

  @override
  void didUpdateWidget(AnimatedValueSwap<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.value == _current) return;
    _previous = _current;
    _current = widget.value;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final t = _t.value;
        final previous = _previous;
        final incoming = widget.builder(context, _current);
        if (t >= 1 || previous == null) return incoming;
        return buildSwapLayout(
          progress: t,
          outgoing: widget.builder(context, previous),
          incoming: incoming,
          slideExtent: widget.slideExtent,
          alignment: widget.alignment,
        );
      },
    );
  }
}
