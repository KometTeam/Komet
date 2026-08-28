import 'package:flutter/material.dart';
import 'package:qr/qr.dart';

class QrCodeView extends StatefulWidget {
  final String data;
  final double size;
  final Color moduleColor;
  final Widget? center;
  final double centerRatio;

  const QrCodeView({
    super.key,
    required this.data,
    required this.size,
    required this.moduleColor,
    this.center,
    this.centerRatio = 0.24,
  });

  @override
  State<QrCodeView> createState() => _QrCodeViewState();
}

class _QrCodeViewState extends State<QrCodeView> {
  late QrImage _image;

  @override
  void initState() {
    super.initState();
    _encode();
  }

  @override
  void didUpdateWidget(QrCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _encode();
  }

  void _encode() {
    _image = QrImage(
      QrCode(
        payload: QrPayload.fromString(widget.data),
        errorCorrectLevel: QrErrorCorrectLevel.high,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.center;
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(widget.size),
            painter: _QrPainter(
              image: _image,
              color: widget.moduleColor,
              holeRatio: center == null ? 0 : widget.centerRatio,
            ),
          ),
          if (center != null)
            SizedBox.square(
              dimension: widget.size * widget.centerRatio,
              child: center,
            ),
        ],
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrImage image;
  final Color color;
  final double holeRatio;

  const _QrPainter({
    required this.image,
    required this.color,
    required this.holeRatio,
  });

  static const double _bleed = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final cell = size.shortestSide / count;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    final side = count * cell;
    final holeRadius = holeRatio <= 0 ? 0.0 : side * holeRatio / 2 + cell;

    bool isFinder(int row, int col) {
      final top = row < 7;
      final bottom = row >= count - 7;
      final left = col < 7;
      final right = col >= count - 7;
      return (top && left) || (top && right) || (bottom && left);
    }

    bool isDark(int row, int col) {
      if (row < 0 || col < 0 || row >= count || col >= count) return false;
      if (isFinder(row, col)) return false;
      if (holeRadius > 0) {
        final dx = (col + 0.5) * cell - side / 2;
        final dy = (row + 0.5) * cell - side / 2;
        if (dx * dx + dy * dy <= holeRadius * holeRadius) return false;
      }
      return image.isDark(row, col);
    }

    final radius = cell / 2;
    final path = Path()..fillType = PathFillType.nonZero;

    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (!isDark(row, col)) continue;
        final up = isDark(row - 1, col);
        final down = isDark(row + 1, col);
        final left = isDark(row, col - 1);
        final right = isDark(row, col + 1);
        final rect = Rect.fromLTWH(
          col * cell - _bleed,
          row * cell - _bleed,
          cell + _bleed * 2,
          cell + _bleed * 2,
        );
        path.addRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: Radius.circular(up || left ? 0 : radius),
            topRight: Radius.circular(up || right ? 0 : radius),
            bottomLeft: Radius.circular(down || left ? 0 : radius),
            bottomRight: Radius.circular(down || right ? 0 : radius),
          ),
        );
      }
    }
    canvas.drawPath(path, paint);

    _paintFinder(canvas, paint, cell, 0, 0);
    _paintFinder(canvas, paint, cell, 0, count - 7);
    _paintFinder(canvas, paint, cell, count - 7, 0);
  }

  void _paintFinder(
    Canvas canvas,
    Paint paint,
    double cell,
    int row,
    int col,
  ) {
    final outer = Rect.fromLTWH(col * cell, row * cell, cell * 7, cell * 7);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(RRect.fromRectAndRadius(outer, Radius.circular(cell * 2)))
      ..addRRect(
        RRect.fromRectAndRadius(
          outer.deflate(cell),
          Radius.circular(cell * 1.4),
        ),
      );
    canvas.drawPath(ring, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        outer.deflate(cell * 2),
        Radius.circular(cell * 1.1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.color != color ||
      oldDelegate.holeRatio != holeRatio;
}
