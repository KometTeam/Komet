import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TiledSvgPattern extends StatefulWidget {
  final String asset;
  final Color color;
  final double opacity;
  final double tileSize;

  const TiledSvgPattern({
    super.key,
    required this.asset,
    required this.color,
    this.opacity = 0.12,
    this.tileSize = 120,
  });

  @override
  State<TiledSvgPattern> createState() => _TiledSvgPatternState();
}

class _TiledSvgPatternState extends State<TiledSvgPattern> {
  static final Map<String, ui.Image> _cache = {};
  static final Map<String, Future<ui.Image>> _pending = {};

  ui.Image? _image;
  double _dpr = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1;
    if (dpr != _dpr || _image == null) {
      _dpr = dpr;
      _resolve();
    }
  }

  @override
  void didUpdateWidget(TiledSvgPattern old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset || old.tileSize != widget.tileSize) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final px = (widget.tileSize * _dpr).clamp(1, 4096).round();
    final key = '${widget.asset}@$px';
    final cached = _cache[key];
    if (cached != null) {
      if (_image != cached) setState(() => _image = cached);
      return;
    }
    final future = _pending.putIfAbsent(key, () => _rasterize(widget.asset, px));
    try {
      final image = await future;
      _cache[key] = image;
      _pending.remove(key);
      if (mounted) setState(() => _image = image);
    } catch (_) {
      _pending.remove(key);
    }
  }

  static Future<ui.Image> _rasterize(String asset, int px) async {
    final info = await vg.loadPicture(SvgAssetLoader(asset), null);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = info.size;
    if (size.width > 0 && size.height > 0) {
      canvas.scale(px / size.width, px / size.height);
    }
    canvas.drawPicture(info.picture);
    final picture = recorder.endRecording();
    final image = await picture.toImage(px, px);
    info.picture.dispose();
    picture.dispose();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: _PatternPainter(
        image: image,
        color: widget.color.withValues(alpha: widget.opacity),
        tileSize: widget.tileSize,
        dpr: _dpr,
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final ui.Image image;
  final Color color;
  final double tileSize;
  final double dpr;

  const _PatternPainter({
    required this.image,
    required this.color,
    required this.tileSize,
    required this.dpr,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = 1 / dpr;
    final matrix = Matrix4.identity()..scaleByDouble(s, s, 1, 1);
    final paint = Paint()
      ..shader = ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        matrix.storage,
      )
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.image != image ||
      old.color != color ||
      old.tileSize != tileSize ||
      old.dpr != dpr;
}
