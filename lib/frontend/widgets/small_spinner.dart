import 'package:flutter/material.dart';
import 'package:m3e_collection/m3e_collection.dart';

class SmallSpinner extends StatelessWidget {
  final double size;
  final Color? color;

  const SmallSpinner({
    super.key,
    this.size = 26,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: ExpressiveLoadingIndicator(
          color: color ?? Theme.of(context).colorScheme.primary,
          constraints: BoxConstraints.tight(const Size.square(48)),
        ),
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
        child: Center(child: SmallSpinner(size: 44, color: Colors.white)),
      ),
    );
  }
}
