import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LottieSlashIcon extends StatefulWidget {
  const LottieSlashIcon({
    super.key,
    required this.asset,
    required this.slashed,
    required this.color,
    this.size = 24,
    this.duration = const Duration(milliseconds: 320),
  });

  final String asset;
  final bool slashed;
  final Color color;
  final double size;
  final Duration duration;

  @override
  State<LottieSlashIcon> createState() => _LottieSlashIconState();
}

class _LottieSlashIconState extends State<LottieSlashIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.slashed ? 1 : 0,
  );

  @override
  void didUpdateWidget(LottieSlashIcon old) {
    super.didUpdateWidget(old);
    _controller.duration = widget.duration;
    if (widget.slashed == old.slashed) return;
    if (widget.slashed) {
      _controller.forward();
    } else {
      _controller.reverse();
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
          ],
        ),
      ),
    );
  }
}
