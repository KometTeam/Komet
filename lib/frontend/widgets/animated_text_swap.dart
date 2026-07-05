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
        return Stack(
          alignment: widget.alignment,
          children: [
            Opacity(
              opacity: 1 - t,
              child: FractionalTranslation(
                translation: Offset(0, -widget.slideExtent * t),
                child: widget.child,
              ),
            ),
            Opacity(
              opacity: t,
              child: FractionalTranslation(
                translation: Offset(0, widget.slideExtent * (1 - t)),
                child: widget.alternate,
              ),
            ),
          ],
        );
      },
    );
  }
}
