import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:komet/core/config/chat_wallpaper_themes.dart';
import 'package:komet/core/storage/chat_wallpaper_store.dart';
import 'package:komet/frontend/widgets/mesh_gradient_background.dart';

class WallpaperImages {
  WallpaperImages._();

  static const int _recentCapacity = 2;

  static _HeldImage? _global;
  static final List<_HeldImage> _recent = [];

  static ImageProvider providerFor(String path) => FileImage(File(path));

  static void holdGlobal(ChatWallpaper? wallpaper) {
    final path = wallpaper?.imagePath;
    if (_global?.path == path) return;
    _global?.release();
    _global = path == null ? null : _HeldImage(path);
  }

  static void holdRecent(String path) {
    if (_global?.path == path) return;
    final index = _recent.indexWhere((held) => held.path == path);
    if (index >= 0) {
      _recent.add(_recent.removeAt(index));
      return;
    }
    _recent.add(_HeldImage(path));
    while (_recent.length > _recentCapacity) {
      _recent.removeAt(0).release();
    }
  }
}

class _HeldImage {
  final String path;
  final ImageStream _stream;
  final ImageStreamListener _listener = ImageStreamListener(
    (_, _) {},
    onError: (_, _) {},
  );

  _HeldImage(this.path)
    : _stream = WallpaperImages.providerFor(
        path,
      ).resolve(ImageConfiguration.empty) {
    _stream.addListener(_listener);
  }

  void release() => _stream.removeListener(_listener);
}

class ChatWallpaperView extends StatelessWidget {
  final ChatWallpaper wallpaper;

  const ChatWallpaperView({super.key, required this.wallpaper});

  @override
  Widget build(BuildContext context) => RepaintBoundary(child: _buildLayer());

  Widget _buildLayer() {
    if (wallpaper.isImage) {
      final path = wallpaper.imagePath;
      if (path == null) return const SizedBox.shrink();
      return WallpaperImageLayer(
        image: WallpaperImages.providerFor(path),
        dim: wallpaper.dim,
        blur: wallpaper.blur,
        motion: wallpaper.motion,
        offsetX: wallpaper.offsetX,
      );
    }
    if (wallpaper.isGradient) {
      final colors = wallpaper.gradientColors;
      if (colors == null || colors.isEmpty) return const SizedBox.shrink();
      return MeshGradientBackground(
        colors: colors,
        animate: wallpaper.gradientAnimated,
        rotation: wallpaper.gradientRotation,
      );
    }
    final theme = chatWallpaperThemeById(wallpaper.themeId);
    if (theme == null) return const SizedBox.shrink();
    return theme.buildBackground();
  }
}

class WallpaperImageLayer extends StatefulWidget {
  final ImageProvider image;
  final double dim;
  final bool blur;
  final bool motion;
  final double offsetX;

  const WallpaperImageLayer({
    super.key,
    required this.image,
    this.dim = 0,
    this.blur = false,
    this.motion = false,
    this.offsetX = 0,
  });

  @override
  State<WallpaperImageLayer> createState() => _WallpaperImageLayerState();
}

class _WallpaperImageLayerState extends State<WallpaperImageLayer>
    with WidgetsBindingObserver {
  static const double _maxShift = 20;
  static const double _motionScale = 1.16;
  static const double _blurSigma = 22;
  static const Duration _transition = Duration(milliseconds: 320);

  final ValueNotifier<Offset> _offset = ValueNotifier(Offset.zero);
  StreamSubscription<AccelerometerEvent>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.motion) _startMotion();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.motion) _startMotion();
    } else {
      _stopMotion();
    }
  }

  @override
  void didUpdateWidget(WallpaperImageLayer old) {
    super.didUpdateWidget(old);
    if (widget.motion && !old.motion) _startMotion();
    if (!widget.motion && old.motion) _stopMotion();
  }

  void _startMotion() {
    _offset.value = Offset.zero;
    _sub ??= accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(_onAccelerometer, onError: (_) {}, cancelOnError: false);
  }

  void _stopMotion() {
    _sub?.cancel();
    _sub = null;
  }

  void _onAccelerometer(AccelerometerEvent event) {
    final targetX = (-event.x / 9.8).clamp(-1.0, 1.0) * _maxShift;
    final targetY = (event.y / 9.8).clamp(-1.0, 1.0) * _maxShift;
    final prev = _offset.value;
    final next = Offset(
      prev.dx + (targetX - prev.dx) * 0.12,
      prev.dy + (targetY - prev.dy) * 0.12,
    );
    if ((next - prev).distance < 0.25) return;
    _offset.value = next;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: widget.image,
      fit: BoxFit.cover,
      alignment: Alignment(widget.offsetX.clamp(-1.0, 1.0), 0),
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(end: widget.blur ? _blurSigma : 0.0),
      duration: _transition,
      curve: Curves.easeInOut,
      child: image,
      builder: (context, sigma, blurChild) {
        final blurred = sigma > 0.05
            ? ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.clamp,
                ),
                child: blurChild,
              )
            : blurChild!;
        return TweenAnimationBuilder<double>(
          tween: Tween(end: widget.motion ? 1.0 : 0.0),
          duration: _transition,
          curve: Curves.easeInOut,
          child: blurred,
          builder: (context, motionT, motionChild) {
            final layer = motionT > 0.001
                ? ValueListenableBuilder<Offset>(
                    valueListenable: _offset,
                    builder: (context, offset, child) => Transform.translate(
                      offset: offset * motionT,
                      child: Transform.scale(
                        scale: 1 + (_motionScale - 1) * motionT,
                        child: child,
                      ),
                    ),
                    child: motionChild,
                  )
                : motionChild!;
            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  layer,
                  if (widget.dim > 0)
                    ColoredBox(
                      color: Colors.black.withValues(alpha: widget.dim),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
