import 'dart:math' as math;

import 'package:flutter/material.dart';

class LockGlyph extends StatelessWidget {
  final double closed;
  final double size;
  final Color color;
  final Color holeColor;

  const LockGlyph({
    super.key,
    required this.closed,
    required this.size,
    required this.color,
    required this.holeColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LockPainter(
          closed: closed.clamp(0.0, 1.0),
          color: color,
          holeColor: holeColor,
        ),
      ),
    );
  }
}

class _LockPainter extends CustomPainter {
  final double closed;
  final Color color;
  final Color holeColor;

  const _LockPainter({
    required this.closed,
    required this.color,
    required this.holeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final open = 1 - closed;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.18, s * 0.45, s * 0.64, s * 0.47),
      Radius.circular(s * 0.12),
    );
    final stroke = s * 0.09;
    final left = s * 0.32;
    final right = s * 0.68;
    final radius = (right - left) / 2;
    final lift = open * s * 0.14;
    final archY = body.top - s * 0.1 - lift;

    final shackle = Path()
      ..moveTo(left, body.top + s * 0.04)
      ..lineTo(left, archY)
      ..arcTo(
        Rect.fromCircle(center: Offset(left + radius, archY), radius: radius),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(right, body.top + s * 0.04 - open * s * 0.2);

    canvas.save();
    final pivot = Offset(left, body.top);
    canvas
      ..translate(pivot.dx, pivot.dy)
      ..rotate(-open * 0.32)
      ..translate(-pivot.dx, -pivot.dy);
    canvas.drawPath(
      shackle,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();

    canvas.drawRRect(body, Paint()..color = color);

    final hole = Paint()..color = holeColor;
    final center = Offset(s / 2, body.center.dy - s * 0.03);
    canvas.drawCircle(center, s * 0.065, hole);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center.translate(0, s * 0.08),
          width: s * 0.06,
          height: s * 0.13,
        ),
        Radius.circular(s * 0.03),
      ),
      hole,
    );
  }

  @override
  bool shouldRepaint(_LockPainter old) =>
      old.closed != closed || old.color != color || old.holeColor != holeColor;
}
