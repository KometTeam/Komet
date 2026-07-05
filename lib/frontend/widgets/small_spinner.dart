import 'package:flutter/material.dart';

class SmallSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;

  const SmallSpinner({
    super.key,
    this.size = 26,
    this.strokeWidth = 2.4,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class BusyOverlay extends StatelessWidget {
  const BusyOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}
