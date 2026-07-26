import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef PhotoHeroOrigin = Rect? Function();

Rect? photoHeroRect(GlobalKey? key) =>
    _globalRect(key?.currentContext?.findRenderObject());

Rect? photoHeroRectOf(BuildContext context) =>
    context.mounted ? _globalRect(context.findRenderObject()) : null;

Rect? _globalRect(RenderObject? object) {
  if (object is! RenderBox || !object.attached || !object.hasSize) return null;
  final size = object.size;
  if (size.isEmpty) return null;
  return MatrixUtils.transformRect(
    object.getTransformTo(null),
    Offset.zero & size,
  );
}

Rect _inscribe(Size source, Rect box, {required bool cover}) {
  if (source.isEmpty || box.isEmpty) return box;
  final scaleX = box.width / source.width;
  final scaleY = box.height / source.height;
  final scale = cover ? math.max(scaleX, scaleY) : math.min(scaleX, scaleY);
  return Alignment.center.inscribe(
    Size(source.width * scale, source.height * scale),
    box,
  );
}

class PhotoHeroController {
  PhotoHeroController({
    required this.origin,
    ImageProvider? image,
    this.size,
    this.radius = BorderRadius.zero,
  }) : image = ValueNotifier(image);

  final PhotoHeroOrigin origin;
  final ValueNotifier<ImageProvider?> image;
  final ValueNotifier<bool> flying = ValueNotifier(false);
  final Size? size;
  final BorderRadius radius;
  final GlobalKey areaKey = GlobalKey();

  bool enabled = true;

  Rect? get areaRect => photoHeroRect(areaKey);

  Rect? get originRect => enabled ? origin() : null;

  bool get canFly => image.value != null && originRect != null;

  void dispose() {
    image.dispose();
    flying.dispose();
  }
}

class PhotoHeroRoute<T> extends PageRouteBuilder<T> {
  PhotoHeroRoute({required this.hero, required WidgetBuilder builder})
    : super(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) =>
            PhotoHeroScope(controller: hero, child: builder(context)),
        transitionsBuilder:
            (context, animation, secondaryAnimation, child) =>
                _PhotoHeroTransition(
                  controller: hero,
                  animation: animation,
                  child: child,
                ),
      );

  final PhotoHeroController hero;

  @override
  void dispose() {
    hero.dispose();
    super.dispose();
  }
}

class PhotoHeroScope extends InheritedWidget {
  const PhotoHeroScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final PhotoHeroController controller;

  static PhotoHeroController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PhotoHeroScope>()?.controller;

  @override
  bool updateShouldNotify(PhotoHeroScope oldWidget) =>
      controller != oldWidget.controller;
}

class PhotoHeroTarget extends StatelessWidget {
  const PhotoHeroTarget({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = PhotoHeroScope.maybeOf(context);
    if (controller == null) return child;
    return KeyedSubtree(
      key: controller.areaKey,
      child: ValueListenableBuilder<bool>(
        valueListenable: controller.flying,
        child: child,
        builder: (context, flying, child) =>
            flying ? Opacity(opacity: 0, child: child) : child!,
      ),
    );
  }
}

class _PhotoHeroTransition extends StatefulWidget {
  const _PhotoHeroTransition({
    required this.controller,
    required this.animation,
    required this.child,
  });

  final PhotoHeroController controller;
  final Animation<double> animation;
  final Widget child;

  @override
  State<_PhotoHeroTransition> createState() => _PhotoHeroTransitionState();
}

class _PhotoHeroTransitionState extends State<_PhotoHeroTransition> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _resolvedSize;
  Rect? _from;
  Rect? _area;
  ImageProvider? _flightProvider;
  Widget? _flightImage;

  Size? get _imageSize => widget.controller.size ?? _resolvedSize;

  bool get _flying => widget.controller.flying.value;

  @override
  void initState() {
    super.initState();
    widget.controller.image.addListener(_resolveImage);
    widget.animation.addStatusListener(_onStatusChanged);
    if (widget.animation.status != AnimationStatus.completed) {
      widget.controller.flying.value = widget.controller.canFly;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatusChanged);
    widget.controller.image.removeListener(_resolveImage);
    _detachStream();
    super.dispose();
  }

  void _onStatusChanged(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        _startFlight();
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        _stopFlight();
    }
  }

  void _startFlight() {
    _from = null;
    _area = null;
    _setFlying(widget.controller.canFly);
  }

  void _stopFlight() => _setFlying(false);

  void _setFlying(bool value) {
    if (_flying == value) return;
    widget.controller.flying.value = value;
    if (mounted) setState(() {});
  }

  void _detachStream() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _resolveImage() {
    if (!mounted) return;
    final provider = widget.controller.image.value;
    if (provider == null) return;
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _detachStream();
    final listener = ImageStreamListener((info, synchronous) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      info.dispose();
      if (_resolvedSize == size) return;
      if (_resolvedSize != null && _flying) return;
      if (synchronous) {
        _resolvedSize = size;
      } else if (mounted) {
        setState(() => _resolvedSize = size);
      }
    });
    _listener = listener;
    _stream = stream..addListener(listener);
  }

  Widget _imageWidget(ImageProvider provider) {
    if (!identical(_flightProvider, provider)) {
      _flightProvider = provider;
      _flightImage = Image(
        image: provider,
        fit: BoxFit.fill,
        gaplessPlayback: true,
      );
    }
    return _flightImage!;
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.controller.image.value;
    if (!_flying || provider == null) {
      return FadeTransition(opacity: widget.animation, child: widget.child);
    }
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: widget.animation,
              child: _imageWidget(provider),
              builder: (context, child) => _layoutFlight(child!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _layoutFlight(Widget image) {
    final from = _from ??= widget.controller.originRect;
    if (from == null) return const SizedBox.shrink();
    final area = _area ??= widget.controller.areaRect;
    final imageSize = _imageSize;
    if (area == null || imageSize == null) {
      return _position(image, from, from, 1);
    }
    final t = Curves.fastOutSlowIn.transform(
      widget.animation.value.clamp(0.0, 1.0),
    );
    final target = _inscribe(imageSize, area, cover: false);
    return _position(
      image,
      Rect.lerp(from, target, t)!,
      Rect.lerp(_inscribe(imageSize, from, cover: true), target, t)!,
      1 - t,
    );
  }

  Widget _position(Widget image, Rect clip, Rect rect, double radiusT) {
    final radius = widget.controller.radius * radiusT;
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: rect.left - clip.left,
          top: rect.top - clip.top,
          width: rect.width,
          height: rect.height,
          child: image,
        ),
      ],
    );
    return Stack(
      children: [
        Positioned.fromRect(
          rect: clip,
          child: radius == BorderRadius.zero
              ? ClipRect(child: content)
              : ClipRRect(borderRadius: radius, child: content),
        ),
      ],
    );
  }
}
