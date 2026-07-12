import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ThemeRevealOverlay {
  static OverlayEntry build({
    required ui.Image snapshot,
    required Offset center,
    required Animation<double> animation,
  }) {
    return OverlayEntry(
      builder: (ctx) {
        final size = MediaQuery.sizeOf(ctx);
        final maxRadius = _maxRadius(center, size);
        return IgnorePointer(
          child: AnimatedBuilder(
            animation: animation,
            builder: (_, __) {
              final t = Curves.easeInOutCubic.transform(
                animation.value.clamp(0.0, 1.0),
              );
              return ClipPath(
                clipper: _RevealClipper(center: center, radius: maxRadius * t),
                child: Opacity(
                  opacity: 1.0 - (t * t * t * t),
                  child: RawImage(
                    image: snapshot,
                    width: size.width,
                    height: size.height,
                    fit: BoxFit.fill,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static double _maxRadius(Offset center, Size size) {
    final dx = math.max(center.dx, size.width - center.dx);
    final dy = math.max(center.dy, size.height - center.dy);
    return math.sqrt(dx * dx + dy * dy);
  }
}

class _RevealClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _RevealClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    final full = Path()..addRect(Offset.zero & size);
    if (radius <= 0) return full;
    final hole = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    return Path.combine(PathOperation.difference, full, hole);
  }

  @override
  bool shouldReclip(covariant _RevealClipper old) =>
      old.center != center || old.radius != radius;
}
