import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedIconButton extends StatefulWidget {
  final String asset;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;

  const AnimatedIconButton({
    super.key,
    required this.asset,
    this.onPressed,
    this.size = 28,
    this.tooltip,
  });

  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enter() => _controller.forward();

  void _exit() => _controller.reverse();

  void _tapDown() => _controller.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final Widget button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _enter(),
      onExit: (_) => _exit(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: (_) => _tapDown(),
        child: SizedBox.square(
          dimension: widget.size,
          child: Lottie.asset(
            widget.asset,
            controller: _controller,
            fit: BoxFit.contain,
            onLoaded: (composition) {
              _controller.duration = composition.duration;
            },
          ),
        ),
      ),
    );

    final tooltip = widget.tooltip;
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }
}
