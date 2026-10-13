import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class UploadProgressRing extends StatefulWidget {
  final ValueListenable<List<double>> progress;
  final int? slot;
  final Color color;
  final Color? trackColor;
  final double size;
  final double strokeWidth;
  final double iconSize;
  final EdgeInsets padding;
  final VoidCallback? onCancel;
  final bool showCancelIcon;

  const UploadProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.slot,
    this.trackColor,
    this.size = 54,
    this.strokeWidth = 3,
    this.iconSize = 22,
    this.padding = EdgeInsets.zero,
    this.onCancel,
    this.showCancelIcon = true,
  });

  static double fractionOf(List<double> values, int? slot) {
    if (values.isEmpty) return 0;
    if (slot != null) {
      return slot < values.length ? values[slot].clamp(0.0, 1.0) : 1.0;
    }
    return (values.reduce((a, b) => a + b) / values.length).clamp(0.0, 1.0);
  }

  @override
  State<UploadProgressRing> createState() => _UploadProgressRingState();
}

class _UploadProgressRingState extends State<UploadProgressRing>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: _target,
  );

  double get _target =>
      UploadProgressRing.fractionOf(widget.progress.value, widget.slot);

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgress);
    _syncSpin(_target);
  }

  @override
  void didUpdateWidget(UploadProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.progress, widget.progress)) {
      oldWidget.progress.removeListener(_onProgress);
      widget.progress.addListener(_onProgress);
    }
    if (oldWidget.slot != widget.slot ||
        !identical(oldWidget.progress, widget.progress)) {
      _onProgress();
    }
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    _spin.dispose();
    _shown.dispose();
    super.dispose();
  }

  void _onProgress() {
    final target = _target;
    _syncSpin(target);
    if (target < _shown.value) {
      _shown.value = target;
      return;
    }
    _shown.animateTo(target, curve: Curves.easeOut);
  }

  void _syncSpin(double target) {
    if (target >= 1) {
      if (_spin.isAnimating) _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancel = widget.onCancel;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: cancel,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: widget.padding,
                  child: CustomPaint(
                    painter: _RingPainter(
                      spin: _spin,
                      shown: _shown,
                      color: widget.color,
                      track:
                          widget.trackColor ??
                          widget.color.withValues(alpha: 0.25),
                      strokeWidth: widget.strokeWidth,
                    ),
                  ),
                ),
              ),
              if (cancel != null && widget.showCancelIcon)
                Icon(Symbols.close, size: widget.iconSize, color: widget.color),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.spin,
    required this.shown,
    required this.color,
    required this.track,
    required this.strokeWidth,
  }) : super(repaint: Listenable.merge([spin, shown]));

  static const double _minSweep = 0.06;

  final Animation<double> spin;
  final Animation<double> shown;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );
    final fraction = math.max(_minSweep, shown.value);
    canvas.drawArc(
      rect,
      spin.value * 2 * math.pi - math.pi / 2,
      fraction * 2 * math.pi,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.strokeWidth != strokeWidth ||
      !identical(oldDelegate.spin, spin) ||
      !identical(oldDelegate.shown, shown);
}
