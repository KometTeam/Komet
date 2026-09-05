import 'dart:math' as math;

import 'package:flutter/material.dart';

class ColorWheelPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const ColorWheelPicker({super.key, required this.color, required this.onChanged});

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker> {
  late HSVColor _hsv;
  late Color _lastEmitted;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.color);
    _lastEmitted = widget.color;
  }

  @override
  void didUpdateWidget(covariant ColorWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color != _lastEmitted) {
      _hsv = HSVColor.fromColor(widget.color);
      _lastEmitted = widget.color;
    }
  }

  void _emit(HSVColor hsv) {
    setState(() => _hsv = hsv);
    final color = hsv.toColor();
    _lastEmitted = color;
    widget.onChanged(color);
  }

  void _handleWheel(Offset local, double size) {
    final radius = size / 2;
    final dx = local.dx - radius;
    final dy = local.dy - radius;
    final sat = (math.sqrt(dx * dx + dy * dy) / radius).clamp(0.0, 1.0);
    var hue = math.atan2(dy, dx) * 180 / math.pi;
    if (hue < 0) hue += 360;
    _emit(_hsv.withHue(hue).withSaturation(sat));
  }

  void _handleBrightness(double localY, double height) {
    final value = (1 - localY / height).clamp(0.0, 1.0);
    _emit(_hsv.withValue(value));
  }

  @override
  Widget build(BuildContext context) {
    const barWidth = 28.0;
    const spacing = 16.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wheelSize = math.min(
          260.0,
          constraints.maxWidth - barWidth - spacing,
        );

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => _handleWheel(d.localPosition, wheelSize),
              onPanUpdate: (d) => _handleWheel(d.localPosition, wheelSize),
              child: SizedBox(
                width: wheelSize,
                height: wheelSize,
                child: CustomPaint(painter: _WheelPainter(hsv: _hsv)),
              ),
            ),
            const SizedBox(width: spacing),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => _handleBrightness(d.localPosition.dy, wheelSize),
              onPanUpdate: (d) => _handleBrightness(d.localPosition.dy, wheelSize),
              child: SizedBox(
                width: barWidth,
                height: wheelSize,
                child: CustomPaint(painter: _BrightnessBarPainter(hsv: _hsv)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  final HSVColor hsv;

  const _WheelPainter({required this.hsv});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final hueShader = SweepGradient(
      colors: [
        for (var i = 0; i <= 360; i += 30)
          HSVColor.fromAHSV(1, (i % 360).toDouble(), 1, 1).toColor(),
      ],
      stops: [for (var i = 0; i <= 360; i += 30) i / 360],
    ).createShader(rect);
    canvas.drawCircle(center, radius, Paint()..shader = hueShader);

    final satShader = RadialGradient(
      colors: [Colors.white, Colors.white.withValues(alpha: 0)],
    ).createShader(rect);
    canvas.drawCircle(center, radius, Paint()..shader = satShader);

    final angle = hsv.hue * math.pi / 180;
    final thumb = Offset(
      center.dx + hsv.saturation * radius * math.cos(angle),
      center.dy + hsv.saturation * radius * math.sin(angle),
    );
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: thumb, radius: 13)),
      Colors.black,
      2,
      false,
    );
    canvas.drawCircle(thumb, 13, Paint()..color = Colors.white);
    canvas.drawCircle(
      thumb,
      10,
      Paint()..color = hsv.withValue(1).toColor(),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.hsv.hue != hsv.hue || oldDelegate.hsv.saturation != hsv.saturation;
}

class _BrightnessBarPainter extends CustomPainter {
  final HSVColor hsv;

  const _BrightnessBarPainter({required this.hsv});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width / 2),
    );
    final top = hsv.withValue(1).toColor();
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, Colors.black],
    ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, Paint()..shader = gradient);

    final thumbY = (1 - hsv.value) * size.height;
    final thumb = Offset(size.width / 2, thumbY.clamp(0.0, size.height));
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: thumb, radius: 12)),
      Colors.black,
      2,
      false,
    );
    canvas.drawCircle(thumb, 12, Paint()..color = Colors.white);
    canvas.drawCircle(thumb, 9, Paint()..color = hsv.toColor());
  }

  @override
  bool shouldRepaint(_BrightnessBarPainter oldDelegate) =>
      oldDelegate.hsv != hsv;
}
