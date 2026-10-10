import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ColorWheelPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;
  final double minBrightness;

  const ColorWheelPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.minBrightness = 0,
  }) : assert(minBrightness >= 0 && minBrightness < 1);

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
    final fraction = (localY / height).clamp(0.0, 1.0);
    _emit(_hsv.withValue(1 - fraction * (1 - widget.minBrightness)));
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
            _ClaimingDragArea(
              onPosition: (local) => _handleWheel(local, wheelSize),
              child: SizedBox(
                width: wheelSize,
                height: wheelSize,
                child: CustomPaint(painter: _WheelPainter(hsv: _hsv)),
              ),
            ),
            _ClaimingDragArea(
              onPosition: (local) => _handleBrightness(local.dy, wheelSize),
              child: Padding(
                padding: const EdgeInsets.only(left: spacing),
                child: SizedBox(
                  width: barWidth,
                  height: wheelSize,
                  child: CustomPaint(
                    painter: _BrightnessBarPainter(
                      hsv: _hsv,
                      minBrightness: widget.minBrightness,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ClaimingDragArea extends StatelessWidget {
  final ValueChanged<Offset> onPosition;
  final Widget child;

  const _ClaimingDragArea({required this.onPosition, required this.child});

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        _ClaimingPanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_ClaimingPanGestureRecognizer>(
              _ClaimingPanGestureRecognizer.new,
              (recognizer) {
                recognizer.onDown = (details) =>
                    onPosition(details.localPosition);
                recognizer.onUpdate = (details) =>
                    onPosition(details.localPosition);
              },
            ),
      },
      child: child,
    );
  }
}

class _ClaimingPanGestureRecognizer extends PanGestureRecognizer {
  _ClaimingPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
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
    canvas.drawCircle(thumb, 10, Paint()..color = hsv.withValue(1).toColor());
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.hsv.hue != hsv.hue ||
      oldDelegate.hsv.saturation != hsv.saturation;
}

class _BrightnessBarPainter extends CustomPainter {
  final HSVColor hsv;
  final double minBrightness;

  const _BrightnessBarPainter({required this.hsv, required this.minBrightness});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width / 2),
    );
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        hsv.withValue(1).toColor(),
        hsv.withValue(minBrightness).toColor(),
      ],
    ).createShader(Offset.zero & size);
    canvas.drawRRect(rrect, Paint()..shader = gradient);

    final fraction = ((1 - hsv.value) / (1 - minBrightness)).clamp(0.0, 1.0);
    final thumb = Offset(size.width / 2, fraction * size.height);
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
      oldDelegate.hsv != hsv || oldDelegate.minBrightness != minBrightness;
}
