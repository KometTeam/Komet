import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class EdgeStretchFill extends StatefulWidget {
  const EdgeStretchFill({
    super.key,
    required this.source,
    required this.imageAspect,
    required this.fallback,
  });

  final ImageProvider? source;
  final double imageAspect;
  final Color fallback;

  @override
  State<EdgeStretchFill> createState() => _EdgeStretchFillState();
}

class _EdgeStretchFillState extends State<EdgeStretchFill> {
  ImageStream? _stream;
  ImageProvider? _resolvedSource;
  ImageInfo? _info;
  _EdgeSamples? _samples;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onImage,
    onError: (_, _) {},
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(EdgeStretchFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _resolve();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _samples?.dispose();
    _info?.dispose();
    super.dispose();
  }

  void _resolve() {
    final source = widget.source;
    if (_stream != null && source == _resolvedSource) return;
    _resolvedSource = source;
    _stream?.removeListener(_listener);
    final stream = source?.resolve(createLocalImageConfiguration(context));
    _stream = stream;
    stream?.addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final previous = _info;
    if (previous != null && previous.isCloneOf(info)) {
      info.dispose();
      return;
    }
    if (!synchronousCall && !mounted) {
      info.dispose();
      return;
    }
    previous?.dispose();
    final samples = _EdgeSamples.of(info.image);
    void apply() {
      _samples?.dispose();
      _samples = samples;
      _info = info;
    }

    if (synchronousCall) {
      apply();
    } else {
      setState(apply);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EdgeStretchPainter(
        samples: _samples,
        imageAspect: widget.imageAspect,
        fallback: widget.fallback,
      ),
    );
  }
}

class _EdgeSamples {
  _EdgeSamples._(this.left, this.right, this.top, this.bottom);

  static const int _count = 32;
  static const double _stripFraction = 0.03;

  final ui.Image left;
  final ui.Image right;
  final ui.Image top;
  final ui.Image bottom;

  static _EdgeSamples of(ui.Image image) {
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final column = math.max(1.0, w * _stripFraction);
    final row = math.max(1.0, h * _stripFraction);
    const vertical = Size(1, _count + 0.0);
    const horizontal = Size(_count + 0.0, 1);
    return _EdgeSamples._(
      _sample(image, Rect.fromLTWH(0, 0, column, h), vertical),
      _sample(image, Rect.fromLTWH(w - column, 0, column, h), vertical),
      _sample(image, Rect.fromLTWH(0, 0, w, row), horizontal),
      _sample(image, Rect.fromLTWH(0, h - row, w, row), horizontal),
    );
  }

  static ui.Image _sample(ui.Image image, Rect source, Size target) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      source,
      Offset.zero & target,
      Paint()..filterQuality = FilterQuality.medium,
    );
    return recorder.endRecording().toImageSync(
      target.width.toInt(),
      target.height.toInt(),
    );
  }

  void dispose() {
    left.dispose();
    right.dispose();
    top.dispose();
    bottom.dispose();
  }
}

class _EdgeStretchPainter extends CustomPainter {
  const _EdgeStretchPainter({
    required this.samples,
    required this.imageAspect,
    required this.fallback,
  });

  static const Color _shade = Color(0x40000000);

  final _EdgeSamples? samples;
  final double imageAspect;
  final Color fallback;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final samples = this.samples;
    if (samples == null || size.isEmpty) {
      canvas.drawRect(bounds, Paint()..color = fallback);
      return;
    }
    final paint = Paint()..filterQuality = FilterQuality.low;
    if (imageAspect < size.width / size.height) {
      final bar = (size.width - size.height * imageAspect) / 2 + 1;
      _stretch(
        canvas,
        samples.left,
        Rect.fromLTWH(0, 0, bar, size.height),
        paint,
      );
      _stretch(
        canvas,
        samples.right,
        Rect.fromLTWH(size.width - bar, 0, bar, size.height),
        paint,
      );
    } else {
      final bar = (size.height - size.width / imageAspect) / 2 + 1;
      _stretch(
        canvas,
        samples.top,
        Rect.fromLTWH(0, 0, size.width, bar),
        paint,
      );
      _stretch(
        canvas,
        samples.bottom,
        Rect.fromLTWH(0, size.height - bar, size.width, bar),
        paint,
      );
    }
    canvas.drawRect(bounds, Paint()..color = _shade);
  }

  static void _stretch(
    Canvas canvas,
    ui.Image image,
    Rect target,
    Paint paint,
  ) {
    canvas.drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      target,
      paint,
    );
  }

  @override
  bool shouldRepaint(_EdgeStretchPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.imageAspect != imageAspect ||
      oldDelegate.fallback != fallback;
}
