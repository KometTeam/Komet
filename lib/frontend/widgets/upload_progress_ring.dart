import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class UploadProgressRing extends StatelessWidget {
  final ValueListenable<List<double>> progress;
  final Color color;
  final Color? trackColor;
  final double size;
  final double strokeWidth;
  final double iconSize;
  final EdgeInsets padding;

  const UploadProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.trackColor,
    this.size = 54,
    this.strokeWidth = 3,
    this.iconSize = 22,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<double>>(
      valueListenable: progress,
      builder: (context, values, _) {
        final value = values.isEmpty
            ? 0.0
            : values.reduce((a, b) => a + b) / values.length;
        final done = value >= 1.0;
        return SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: padding,
                child: SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: value.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    builder: (context, shown, _) => CircularProgressIndicator(
                      value: done ? null : shown,
                      strokeWidth: strokeWidth,
                      backgroundColor:
                          trackColor ?? color.withValues(alpha: 0.25),
                      color: color,
                    ),
                  ),
                ),
              ),
              Icon(Symbols.close, size: iconSize, color: color),
            ],
          ),
        );
      },
    );
  }
}
