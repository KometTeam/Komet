import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/config/app_motion.dart';
import '../../core/config/chat_wallpaper_themes.dart';
import '../../core/storage/chat_wallpaper_store.dart';

void precacheWallpaperPattern(ChatWallpaper? wallpaper) {
  final themeId = wallpaper?.themeId;
  if (themeId != null) precacheWallpaperTheme(themeId);
}

void precacheWallpaperTheme(String themeId) {
  final asset = chatWallpaperThemeById(themeId)?.pattern?.asset;
  if (asset == null) return;
  unawaited(WallpaperPatternLayer.load(asset).then((_) {}, onError: (_) {}));
}

class ThemeWallpaper extends StatelessWidget {
  const ThemeWallpaper({
    super.key,
    required this.theme,
    this.patternScale = 1,
    this.pinned = false,
  });

  final ChatWallpaperTheme theme;
  final double patternScale;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final pattern = theme.pattern;
    final background = DecoratedBox(
      decoration: BoxDecoration(gradient: theme.gradient),
      child: const SizedBox.expand(),
    );
    final layer = pattern == null
        ? background
        : Stack(
            fit: StackFit.expand,
            children: [
              background,
              WallpaperPatternLayer(pattern: pattern, scale: patternScale),
            ],
          );
    if (!pinned) return layer;
    final screen = MediaQuery.sizeOf(context);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        minWidth: screen.width,
        maxWidth: screen.width,
        minHeight: screen.height,
        maxHeight: screen.height,
        child: RepaintBoundary(child: layer),
      ),
    );
  }
}

class WallpaperPatternLayer extends StatefulWidget {
  const WallpaperPatternLayer({
    super.key,
    required this.pattern,
    this.scale = 1,
  });

  final WallpaperPattern pattern;
  final double scale;

  static final Map<String, PictureInfo> _tiles = {};
  static final Map<String, Future<PictureInfo>> _loading = {};

  static Future<PictureInfo> load(String asset) {
    final ready = _tiles[asset];
    if (ready != null) return Future.value(ready);
    return _loading.putIfAbsent(asset, () async {
      try {
        final info = await vg.loadPicture(SvgAssetLoader(asset), null);
        _tiles[asset] = info;
        return info;
      } finally {
        _loading.remove(asset);
      }
    });
  }

  @override
  State<WallpaperPatternLayer> createState() => _WallpaperPatternLayerState();
}

class _WallpaperPatternLayerState extends State<WallpaperPatternLayer> {
  PictureInfo? _tile;
  ui.Image? _image;
  String? _imageKey;

  @override
  void initState() {
    super.initState();
    _resolveTile();
  }

  @override
  void didUpdateWidget(WallpaperPatternLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pattern.asset != widget.pattern.asset) _resolveTile();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _resolveTile() {
    final asset = widget.pattern.asset;
    _tile = WallpaperPatternLayer._tiles[asset];
    if (_tile != null) return;
    WallpaperPatternLayer.load(asset).then((info) {
      if (!mounted || widget.pattern.asset != asset) return;
      setState(() => _tile = info);
    }, onError: (Object _) {});
  }

  _PatternRaster _rasterFor(PictureInfo tile, Size size, double ratio) =>
      _PatternRaster(
        tile: tile,
        pattern: widget.pattern,
        size: _PatternRaster.bucketOf(size),
        devicePixelRatio: ratio,
        scale: widget.scale,
      );

  ui.Image _imageFor(_PatternRaster raster) {
    final image = _image;
    if (image != null && _imageKey == raster.key) return image;
    image?.dispose();
    _imageKey = raster.key;
    return _image = raster.image();
  }

  @override
  Widget build(BuildContext context) {
    final tile = _tile;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return AnimatedOpacity(
      opacity: tile == null ? 0 : 1,
      duration: AppMotion.of(const Duration(milliseconds: 220)),
      child: tile == null
          ? const SizedBox.expand()
          : LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                if (!size.isFinite || size.isEmpty) {
                  return const SizedBox.shrink();
                }
                final raster = _rasterFor(tile, size, devicePixelRatio);
                return RawImage(
                  image: _imageFor(raster),
                  width: size.width,
                  height: size.height,
                  scale: raster.ratio,
                  fit: BoxFit.none,
                  alignment: Alignment.topCenter,
                );
              },
            ),
    );
  }
}

class _PatternRaster {
  _PatternRaster({
    required this.tile,
    required this.pattern,
    required this.size,
    required double devicePixelRatio,
    required this.scale,
  }) : ratio = math.min(devicePixelRatio, _maxSide / size.longestSide);

  static const double _maxSide = 3200;
  static const double _bucket = 128;
  static const int _budgetBytes = 24 * 1024 * 1024;
  static const Alignment _glowCenter = Alignment(0.8, -0.72);
  static final LinkedHashMap<String, ui.Image> _cache = LinkedHashMap();
  static int _bytes = 0;
  static _RasterMemoryObserver? _observer;

  static int _sizeOf(ui.Image image) => image.width * image.height * 4;

  static Size bucketOf(Size size) => Size(
    (size.width / _bucket).ceil() * _bucket,
    (size.height / _bucket).ceil() * _bucket,
  );

  static void clear() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _bytes = 0;
  }

  static void _remember(String key, ui.Image image) {
    _observer ??= _RasterMemoryObserver()..attach();
    _cache[key] = image;
    _bytes += _sizeOf(image);
    while (_bytes > _budgetBytes && _cache.length > 1) {
      final oldest = _cache.remove(_cache.keys.first)!;
      _bytes -= _sizeOf(oldest);
      oldest.dispose();
    }
  }

  final PictureInfo tile;
  final WallpaperPattern pattern;
  final Size size;
  final double scale;
  final double ratio;

  int get _width => (size.width * ratio).ceil();
  int get _height => (size.height * ratio).ceil();

  String get key =>
      '${pattern.asset}|$_width|$_height|$scale|'
      '${pattern.inkStart.toARGB32()}|${pattern.inkEnd.toARGB32()}|'
      '${pattern.glow.toARGB32()}';

  ui.Image image() {
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached.clone();
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    _paint(canvas);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_width, _height);
    picture.dispose();
    _remember(key, image);
    return image.clone();
  }

  void _paint(Canvas canvas) {
    final rect = Offset.zero & size;
    final ink = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [pattern.inkStart, pattern.inkEnd],
      ).createShader(rect);
    final glow = Paint()
      ..shader = RadialGradient(
        center: _glowCenter,
        radius: 0.95,
        colors: [pattern.glow, pattern.glow.withValues(alpha: 0)],
      ).createShader(rect);

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, ink);
    canvas.drawRect(rect, glow);
    canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstIn);
    final width = tile.size.width * scale;
    final height = tile.size.height * scale;
    final originX = (size.width - width) / 2;
    final startX = originX - (originX / width).ceil() * width;
    for (var y = 0.0; y < size.height; y += height) {
      for (var x = startX; x < size.width; x += width) {
        canvas.save();
        canvas.translate(x, y);
        canvas.scale(scale);
        canvas.drawPicture(tile.picture);
        canvas.restore();
      }
    }
    canvas.restore();
    canvas.restore();
  }
}

class _RasterMemoryObserver with WidgetsBindingObserver {
  void attach() => WidgetsBinding.instance.addObserver(this);

  @override
  void didHaveMemoryPressure() => _PatternRaster.clear();
}
