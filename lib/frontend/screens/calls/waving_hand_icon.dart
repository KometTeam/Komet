import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class WavingHandIcon extends StatefulWidget {
  final bool raised;
  final Color? color;
  final double? size;
  final bool waveOnMount;

  const WavingHandIcon({
    super.key,
    required this.raised,
    this.color,
    this.size,
    this.waveOnMount = false,
  });

  @override
  State<WavingHandIcon> createState() => _WavingHandIconState();
}

class _WavingHandIconState extends State<WavingHandIcon>
    with SingleTickerProviderStateMixin {
  static const Duration _waveDuration = Duration(milliseconds: 900);
  static const Duration _settleDuration = Duration(milliseconds: 260);
  static const double _degree = pi / 180;

  static final Animatable<double> _wave = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0, end: -22 * _degree), weight: 2),
    TweenSequenceItem(
      tween: Tween(begin: -22 * _degree, end: 18 * _degree),
      weight: 3,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 18 * _degree, end: -12 * _degree),
      weight: 3,
    ),
    TweenSequenceItem(
      tween: Tween(begin: -12 * _degree, end: 6 * _degree),
      weight: 2,
    ),
    TweenSequenceItem(tween: Tween(begin: 6 * _degree, end: 0), weight: 2),
  ]).chain(CurveTween(curve: Curves.easeInOut));

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _waveDuration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.raised && widget.waveOnMount) _controller.forward();
  }

  @override
  void didUpdateWidget(WavingHandIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.raised == oldWidget.raised) return;
    if (widget.raised) {
      _controller.forward(from: 0);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final color = widget.color ?? theme.color;
    final size = widget.size ?? theme.size ?? 24;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.raised ? 1 : 0),
      duration: _settleDuration,
      curve: Curves.easeOutBack,
      builder: (context, lift, child) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Transform.translate(
          offset: Offset(0, (1 - lift) * size * 0.08),
          child: Transform.rotate(
            angle: _wave.evaluate(_controller),
            alignment: const Alignment(0.1, 0.85),
            child: Icon(
              Symbols.front_hand,
              size: size,
              color: color,
              fill: lift.clamp(0.0, 1.0),
            ),
          ),
        ),
      ),
    );
  }
}
