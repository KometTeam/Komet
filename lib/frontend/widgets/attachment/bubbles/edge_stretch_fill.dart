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
    previous?.dispose();
    if (synchronousCall) {
      _info = info;
      return;
    }
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _EdgeStretchPainter(
        image: _info?.image,
        imageAspect: widget.imageAspect,
        fallback: widget.fallback,
      ),
    );
  }
}

class _EdgeStretchPainter extends CustomPainter {
  const _EdgeStretchPainter({
    required this.image,
    required this.imageAspect,
    required this.fallback,
  });

  static const double _stripFraction = 0.02;
  static const Color _shade = Color(0x24000000);

  final ui.Image? image;
  final double imageAspect;
  final Color fallback;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final image = this.image;
    if (image == null || size.isEmpty) {
      canvas.drawRect(bounds, Paint()..color = fallback);
      return;
    }
    final paint = Paint()..filterQuality = FilterQuality.low;
    final iw = image.width.toDouble();
    final ih = image.height.toDouble();
    if (imageAspect < size.width / size.height) {
      final bar = (size.width - size.height * imageAspect) / 2 + 1;
      final strip = math.max(1.0, iw * _stripFraction);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, strip, ih),
        Rect.fromLTWH(0, 0, bar, size.height),
        paint,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(iw - strip, 0, strip, ih),
        Rect.fromLTWH(size.width - bar, 0, bar, size.height),
        paint,
      );
    } else {
      final bar = (size.height - size.width / imageAspect) / 2 + 1;
      final strip = math.max(1.0, ih * _stripFraction);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, iw, strip),
        Rect.fromLTWH(0, 0, size.width, bar),
        paint,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, ih - strip, iw, strip),
        Rect.fromLTWH(0, size.height - bar, size.width, bar),
        paint,
      );
    }
    canvas.drawRect(bounds, Paint()..color = _shade);
  }

  @override
  bool shouldRepaint(_EdgeStretchPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.imageAspect != imageAspect ||
      oldDelegate.fallback != fallback;
}
