import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/config/app_frost.dart';
import '../../core/config/app_liquid_glass.dart';
import '../../core/config/app_visual_style.dart';

class LiquidGlass {
  static const String _asset = 'shaders/liquid_glass.frag';

  static ui.FragmentProgram? _program;
  static bool _loadAttempted = false;

  static bool get isSupported => _program != null;

  static bool get active =>
      isSupported && AppVisualStyle.current.value == VisualStyle.liquidGlass;

  static Future<void> load() async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    if (!AppLiquidGlass.enabled) return;
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(_asset);
    } catch (_) {
      _program = null;
    }
  }
}

class GlassSurface extends StatelessWidget {
  final bool liquid;
  final BorderRadius borderRadius;
  final Color frostTint;
  final double frostSigma;
  final Color liquidTint;
  final BoxBorder? border;
  final BackdropKey? backdropKey;
  final Widget child;

  const GlassSurface({
    super.key,
    this.liquid = false,
    this.borderRadius = BorderRadius.zero,
    required this.frostTint,
    this.frostSigma = AppFrost.sigma,
    this.liquidTint = Colors.transparent,
    this.border,
    this.backdropKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final glass = liquid && LiquidGlass.isSupported;
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: glass ? null : frostTint,
        border: border,
      ),
      child: child,
    );
    if (glass) {
      return LiquidGlassSurface(
        borderRadius: borderRadius,
        tint: liquidTint,
        child: decorated,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: frostSigma, sigmaY: frostSigma),
        backdropGroupKey: backdropKey,
        child: decorated,
      ),
    );
  }
}

class LiquidGlassSurface extends StatelessWidget {
  final BorderRadius borderRadius;
  final Color tint;
  final double blurSigma;
  final double spread;
  final double refraction;
  final double chroma;
  final double specular;
  final Offset light;
  final double tintFeather;
  final double rimWidth;
  final Widget child;

  const LiquidGlassSurface({
    super.key,
    required this.borderRadius,
    required this.tint,
    this.blurSigma = AppLiquidGlass.blurSigma,
    this.spread = AppLiquidGlass.spread,
    this.refraction = AppLiquidGlass.refraction,
    this.chroma = AppLiquidGlass.chroma,
    this.specular = AppLiquidGlass.specular,
    this.light = AppLiquidGlass.light,
    this.tintFeather = AppLiquidGlass.tintFeather,
    this.rimWidth = AppLiquidGlass.rimWidth,
    this.child = const SizedBox.expand(),
  });

  @override
  Widget build(BuildContext context) {
    if (!LiquidGlass.isSupported) return child;
    return _LiquidGlassBackdrop(
      borderRadius: borderRadius,
      tint: tint,
      blurSigma: blurSigma,
      spread: spread,
      refraction: refraction,
      chroma: chroma,
      specular: specular,
      light: light,
      tintFeather: tintFeather,
      rimWidth: rimWidth,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      child: child,
    );
  }
}

class _LiquidGlassBackdrop extends SingleChildRenderObjectWidget {
  final BorderRadius borderRadius;
  final Color tint;
  final double blurSigma;
  final double spread;
  final double refraction;
  final double chroma;
  final double specular;
  final Offset light;
  final double tintFeather;
  final double rimWidth;
  final double devicePixelRatio;

  const _LiquidGlassBackdrop({
    required this.borderRadius,
    required this.tint,
    required this.blurSigma,
    required this.spread,
    required this.refraction,
    required this.chroma,
    required this.specular,
    required this.light,
    required this.tintFeather,
    required this.rimWidth,
    required this.devicePixelRatio,
    required super.child,
  });

  @override
  _RenderLiquidGlass createRenderObject(BuildContext context) {
    return _RenderLiquidGlass(
      borderRadius: borderRadius,
      tint: tint,
      blurSigma: blurSigma,
      spread: spread,
      refraction: refraction,
      chroma: chroma,
      specular: specular,
      light: light,
      tintFeather: tintFeather,
      rimWidth: rimWidth,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLiquidGlass renderObject,
  ) {
    renderObject
      ..borderRadius = borderRadius
      ..tint = tint
      ..blurSigma = blurSigma
      ..spread = spread
      ..refraction = refraction
      ..chroma = chroma
      ..specular = specular
      ..light = light
      ..tintFeather = tintFeather
      ..rimWidth = rimWidth
      ..devicePixelRatio = devicePixelRatio;
  }
}

class _RenderLiquidGlass extends RenderProxyBox {
  _RenderLiquidGlass({
    required BorderRadius borderRadius,
    required Color tint,
    required double blurSigma,
    required double spread,
    required double refraction,
    required double chroma,
    required double specular,
    required Offset light,
    required double tintFeather,
    required double rimWidth,
    required double devicePixelRatio,
  }) : _borderRadius = borderRadius,
       _tint = tint,
       _blurSigma = blurSigma,
       _spread = spread,
       _refraction = refraction,
       _chroma = chroma,
       _specular = specular,
       _light = light,
       _tintFeather = tintFeather,
       _rimWidth = rimWidth,
       _devicePixelRatio = devicePixelRatio;

  final LayerHandle<ClipRRectLayer> _blurClipHandle =
      LayerHandle<ClipRRectLayer>();
  final LayerHandle<BackdropFilterLayer> _blurHandle =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<ClipRRectLayer> _clipHandle = LayerHandle<ClipRRectLayer>();
  final LayerHandle<BackdropFilterLayer> _backdropHandle =
      LayerHandle<BackdropFilterLayer>();

  ui.FragmentShader? _shader;

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (_borderRadius == value) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  Color _tint;
  set tint(Color value) {
    if (_tint == value) return;
    _tint = value;
    markNeedsPaint();
  }

  double _blurSigma;
  set blurSigma(double value) {
    if (_blurSigma == value) return;
    _blurSigma = value;
    markNeedsPaint();
  }

  double _spread;
  set spread(double value) {
    if (_spread == value) return;
    _spread = value;
    markNeedsPaint();
  }

  double _refraction;
  set refraction(double value) {
    if (_refraction == value) return;
    _refraction = value;
    markNeedsPaint();
  }

  double _chroma;
  set chroma(double value) {
    if (_chroma == value) return;
    _chroma = value;
    markNeedsPaint();
  }

  double _specular;
  set specular(double value) {
    if (_specular == value) return;
    _specular = value;
    markNeedsPaint();
  }

  Offset _light;
  set light(Offset value) {
    if (_light == value) return;
    _light = value;
    markNeedsPaint();
  }

  double _tintFeather;
  set tintFeather(double value) {
    if (_tintFeather == value) return;
    _tintFeather = value;
    markNeedsPaint();
  }

  double _rimWidth;
  set rimWidth(double value) {
    if (_rimWidth == value) return;
    _rimWidth = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (_devicePixelRatio == value) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void dispose() {
    _blurClipHandle.layer = null;
    _blurHandle.layer = null;
    _clipHandle.layer = null;
    _backdropHandle.layer = null;
    _shader?.dispose();
    _shader = null;
    super.dispose();
  }

  ui.ImageFilter? _buildFilter() {
    final program = LiquidGlass._program;
    if (program == null) return null;

    final shader = _shader ??= program.fragmentShader();
    final dpr = _devicePixelRatio;
    final topLeft = localToGlobal(Offset.zero);
    final left = (topLeft.dx * dpr).roundToDouble();
    final top = (topLeft.dy * dpr).roundToDouble();
    final width = (size.width * dpr).roundToDouble();
    final height = (size.height * dpr).roundToDouble();
    final radius = _borderRadius.topLeft.x * dpr;

    shader
      ..setFloat(2, left)
      ..setFloat(3, top)
      ..setFloat(4, width)
      ..setFloat(5, height)
      ..setFloat(6, radius)
      ..setFloat(7, _spread)
      ..setFloat(8, _refraction * dpr)
      ..setFloat(9, _chroma)
      ..setFloat(10, _specular)
      ..setFloat(11, _tint.r)
      ..setFloat(12, _tint.g)
      ..setFloat(13, _tint.b)
      ..setFloat(14, _tint.a)
      ..setFloat(15, _light.dx)
      ..setFloat(16, _light.dy)
      ..setFloat(17, _tintFeather * dpr)
      ..setFloat(18, _rimWidth * dpr);

    return ui.ImageFilter.shader(shader);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final filter = size.isEmpty ? null : _buildFilter();
    if (filter == null) {
      _blurClipHandle.layer = null;
      _blurHandle.layer = null;
      _clipHandle.layer = null;
      _backdropHandle.layer = null;
      super.paint(context, offset);
      return;
    }

    final bounds = Offset.zero & size;
    final shape = _borderRadius.toRRect(bounds);

    if (_blurSigma > 0) {
      _blurClipHandle.layer = context.pushClipRRect(
        needsCompositing,
        offset,
        bounds,
        shape,
        (PaintingContext innerContext, Offset innerOffset) {
          final blur = _blurHandle.layer ??= BackdropFilterLayer();
          blur.filter = ui.ImageFilter.blur(
            sigmaX: _blurSigma,
            sigmaY: _blurSigma,
            tileMode: TileMode.mirror,
          );
          innerContext.pushLayer(blur, (_, _) {}, innerOffset);
        },
        oldLayer: _blurClipHandle.layer,
      );
    } else {
      _blurClipHandle.layer = null;
      _blurHandle.layer = null;
    }

    _clipHandle.layer = context.pushClipRRect(
      needsCompositing,
      offset,
      bounds,
      shape,
      (PaintingContext innerContext, Offset innerOffset) {
        final backdrop = _backdropHandle.layer ??= BackdropFilterLayer();
        backdrop.filter = filter;
        innerContext.pushLayer(backdrop, super.paint, innerOffset);
      },
      oldLayer: _clipHandle.layer,
    );
  }
}
