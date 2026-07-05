import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedLottieIcon extends StatefulWidget {
  final String asset;
  final Color color;
  final double size;
  final bool active;
  final bool animateOnMount;

  const AnimatedLottieIcon({
    super.key,
    required this.asset,
    required this.color,
    required this.size,
    this.active = false,
    this.animateOnMount = false,
  });

  @override
  State<AnimatedLottieIcon> createState() => _AnimatedLottieIconState();
}

class _AnimatedLottieIconState extends State<AnimatedLottieIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.active && widget.animateOnMount) {
      _controller.forward(from: 0);
    } else {
      _controller.value = widget.active ? 1.0 : 0.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedLottieIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
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
    return SizedBox.square(
      dimension: widget.size,
      child: Lottie.asset(
        widget.asset,
        controller: _controller,
        fit: BoxFit.contain,
        delegates: LottieDelegates(
          values: [
            ValueDelegate.color(const ['**'], value: widget.color),
            ValueDelegate.strokeColor(const ['**'], value: widget.color),
          ],
        ),
        onLoaded: (composition) {
          _controller.duration = composition.duration;
        },
      ),
    );
  }
}
