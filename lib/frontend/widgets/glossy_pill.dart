import 'dart:async' show Timer;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/config/app_pill_gradient.dart';
import '../../core/config/app_visual_style.dart';
import 'liquid_glass.dart';

class _GlossyParts {
  final bool dark;
  final Gradient fill;
  final Border rim;
  final Gradient topSheen;
  final Gradient bottomShade;

  const _GlossyParts({
    required this.dark,
    required this.fill,
    required this.rim,
    required this.topSheen,
    required this.bottomShade,
  });
}

class GlossyDecor {
  static final Map<Color, _GlossyParts> _cache = {};

  static _GlossyParts _parts(Color base) {
    final cached = _cache[base];
    if (cached != null) return cached;
    if (_cache.length > 64) _cache.clear();
    final hsl = HSLColor.fromColor(base);
    final dark = hsl.lightness < 0.5;
    Color shift(double d) =>
        hsl.withLightness((hsl.lightness + d).clamp(0.0, 1.0)).toColor();
    final parts = _GlossyParts(
      dark: dark,
      fill: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [shift(dark ? 0.06 : 0.05), base, shift(dark ? -0.05 : -0.07)],
        stops: const [0.0, 0.5, 1.0],
      ),
      rim: Border.all(
        color: Colors.white.withValues(alpha: dark ? 0.08 : 0.6),
        width: 0.8,
      ),
      topSheen: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: dark ? 0.11 : 0.45),
          Colors.white.withValues(alpha: 0.0),
        ],
      ),
      bottomShade: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [
          Colors.black.withValues(alpha: dark ? 0.2 : 0.07),
          Colors.black.withValues(alpha: 0.0),
        ],
      ),
    );
    _cache[base] = parts;
    return parts;
  }

  static bool isDark(Color base) => _parts(base).dark;
  static Gradient fillGradient(Color base) => _parts(base).fill;
  static Border rimBorder(Color base) => _parts(base).rim;
  static Gradient topSheen(Color base) => _parts(base).topSheen;
  static Gradient bottomShade(Color base) => _parts(base).bottomShade;

  static BoxShadow dropShadow(Color base, double depth) {
    final dark = _parts(base).dark;
    return BoxShadow(
      color: Colors.black.withValues(alpha: dark ? 0.5 : 0.22),
      blurRadius: depth * 1.6,
      spreadRadius: -depth * 0.3,
      offset: Offset(0, depth * 0.6),
    );
  }
}

class GlossyPill extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double depth;
  final bool elevated;
  final BorderSide? borderSide;
  final double? blurSigma;
  final bool liquid;
  final BackdropKey? backdropKey;
  final bool keepInkLayer;

  const GlossyPill({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    BorderRadius? borderRadius,
    this.color,
    this.onTap,
    this.onLongPress,
    this.depth = 10,
    this.elevated = false,
    this.borderSide,
    this.blurSigma,
    this.liquid = false,
    this.backdropKey,
    this.keepInkLayer = false,
  }) : borderRadius =
           borderRadius ?? const BorderRadius.all(Radius.circular(100));

  @override
  State<GlossyPill> createState() => _GlossyPillState();
}

class _GlossyPillState extends State<GlossyPill> with TickerProviderStateMixin {
  // #***! нативные iOS 26-константы: раздувание длинной стороны при нажатии
  // и тремор с сопротивлением при протягивании пальца
  static final _pressSpring = GlassSpring.snappy(
    duration: const Duration(milliseconds: 350),
  );
  // #***! желейность: у следования перехлёст вокруг пальца, у возврата отскок
  static final _swayFollowSpring = GlassSpring.interactive(
    duration: const Duration(milliseconds: 150),
    extraBounce: 0.25,
  );
  static final _swayReturnSpring = GlassSpring.bouncy(
    duration: const Duration(milliseconds: 320),
    extraBounce: 0.12,
  );
  // #***! палец остановился – объект отскакивает назад без ожидания подъёма
  static const _fingerIdle = Duration(milliseconds: 120);

  static const _pressGrowth = 8.0;
  static const _swayMax = 8.0;
  static const _maxStretch = 0.05;

  late final _press = SingleSpringController(vsync: this, spring: _pressSpring);
  late final _swayX = SingleSpringController(
    vsync: this,
    spring: _swayFollowSpring,
  );
  late final _swayY = SingleSpringController(
    vsync: this,
    spring: _swayFollowSpring,
  );

  Offset? _pressOrigin;
  Timer? _returnTimer;
  bool _held = false;
  bool _idle = false;
  final ValueNotifier<Offset?> _pointer = ValueNotifier(null);

  bool get _inert =>
      !widget.keepInkLayer &&
      widget.onTap == null &&
      widget.onLongPress == null;

  double? _sigmaFor(Color base) =>
      widget.blurSigma != null && base.a < 1 ? widget.blurSigma : null;

  void _pointerDown(Offset position) {
    _pressOrigin = position;
    _pointer.value = position;
    _held = true;
    _idle = false;
    _swayX.spring = _swayFollowSpring;
    _swayY.spring = _swayFollowSpring;
    _press.animateTo(1.0);
    _armFingerIdle();
  }

  void _pointerMoved(Offset position, Offset current) {
    final delta = current - position;
    _swayX.animateTo(_saturate(delta.dx));
    _swayY.animateTo(_saturate(delta.dy));
    _pointer.value = current;
    if (_idle && _held) {
      // #***! взаимодействие возобновилось: нажатие и блеск возвращаются
      _idle = false;
      _press.animateTo(1.0);
    }
    _armFingerIdle();
  }

  void _armFingerIdle() {
    _returnTimer?.cancel();
    _returnTimer = Timer(_fingerIdle, () {
      _idle = true;
      _swayToRest();
      // #***! палец замер: гаснет и свечение, не только смещение
      _press.animateTo(0.0);
    });
  }

  void _swayToRest() {
    _swayX.spring = _swayReturnSpring;
    _swayY.spring = _swayReturnSpring;
    _swayX.animateTo(0);
    _swayY.animateTo(0);
  }

  void _release() {
    _returnTimer?.cancel();
    _held = false;
    _idle = true;
    _swayToRest();
    _press.animateTo(0.0);
    _pressOrigin = null;
  }

  static double _saturate(double value) =>
      _swayMax * (2 / (1 + math.exp(-value.abs() / 60)) - 1) * value.sign;

  @override
  void dispose() {
    _returnTimer?.cancel();
    _press.dispose();
    _swayX.dispose();
    _swayY.dispose();
    _pointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VisualStyle>(
      valueListenable: AppVisualStyle.current,
      builder: (context, style, _) {
        if (style == VisualStyle.materialYou) return _flat(context);
        if (widget.liquid && LiquidGlass.isSupported) return _liquid(context);
        return ValueListenableBuilder<bool>(
          valueListenable: AppPillGradient.current,
          builder: (context, gradient, _) => _glossy(context, gradient),
        );
      },
    );
  }

  Widget _liquid(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.color ?? cs.surfaceContainerHigh;
    final content = Padding(padding: widget.padding, child: widget.child);
    // #***! жизненный цикл нажатия живёт на сырых событиях указателя:
    // жесты арены отбирают тап при первом смещении и возврат не срабатывал
    final gesture = InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: content,
    );
    final inner = _inert
        ? content
        : Material(type: MaterialType.transparency, child: gesture);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final longest = constraints.biggest.longestSide;
        final growth = longest.isFinite && longest > 0
            ? math.min(_pressGrowth, longest * 0.4) / longest
            : 0.0;
        return ListenableBuilder(
          listenable: Listenable.merge([_press, _swayX, _swayY, _pointer]),
          builder: (context, _) {
            final press = _press.value.clamp(0.0, 1.0);
            final dx = _swayX.value;
            final dy = _swayY.value;
            final alongX = dx.abs() >= dy.abs();
            final k = press > 0 && longest.isFinite
                ? ((math.sqrt(dx * dx + dy * dy) / math.max(longest, 1)) * 0.5)
                      .clamp(0.0, _maxStretch)
                : 0.0;
            final sx = alongX ? 1 + k : 1 - k * 0.4;
            final sy = alongX ? 1 - k * 0.4 : 1 + k;
            final scale = 1 + growth * press;
            // #***! размер стекла = размер контента (Positioned.fill как в доке),
            // физика только Transform'ом поверх — layout не масштабируем
            return Transform(
              transform: Matrix4.identity()
                ..translateByDouble(dx, dy, 0, 1)
                ..scaleByDouble(sx * scale, sy * scale, 1, 1),
              alignment: Alignment.center,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  GlassSurface(
                    liquid: true,
                    borderRadius: widget.borderRadius,
                    // #***! полупрозрачный базовый цвет не тонирует:
                    // системный материал ios27 сам даёт читаемую заливку
                    frostTint: base.a < 1 ? Colors.transparent : base,
                    border: widget.borderSide != null
                        ? Border.fromBorderSide(widget.borderSide!)
                        : null,
                    backdropKey: widget.backdropKey,
                    child: Listener(
                      onPointerDown: _inert
                          ? null
                          : (event) => _pointerDown(event.localPosition),
                      onPointerMove: _inert
                          ? null
                          : (event) {
                              final origin = _pressOrigin;
                              if (origin == null) return;
                              _pointerMoved(origin, event.localPosition);
                            },
                      onPointerUp: _inert ? null : (_) => _release(),
                      onPointerCancel: _inert ? null : (_) => _release(),
                      child: inner,
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: widget.borderRadius,
                        child: CustomPaint(
                          painter: _PressGlowPainter(
                            press: press,
                            dark: dark,
                            point: _pointer.value,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _flat(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.color ?? cs.surfaceContainerHigh;
    final content = Padding(padding: widget.padding, child: widget.child);
    final material = Material(
      color: base,
      elevation: widget.elevated ? 3 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: widget.borderRadius,
        side: widget.borderSide ?? BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: _inert
          ? content
          : InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: content,
            ),
    );
    final sigma = _sigmaFor(base);
    if (sigma == null) return material;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        backdropGroupKey: widget.backdropKey,
        child: material,
      ),
    );
  }

  Widget _glossy(BuildContext context, bool gradient) {
    final cs = Theme.of(context).colorScheme;
    final base = widget.color ?? cs.surfaceContainerHigh;
    final content = Padding(padding: widget.padding, child: widget.child);
    final sigma = _sigmaFor(base);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          color: gradient ? null : base,
          gradient: gradient ? GlossyDecor.fillGradient(base) : null,
          border: widget.borderSide != null
              ? Border.fromBorderSide(widget.borderSide!)
              : GlossyDecor.rimBorder(base),
          boxShadow: [GlossyDecor.dropShadow(base, widget.depth)],
        ),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              if (sigma != null)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    backdropGroupKey: widget.backdropKey,
                    child: const SizedBox.expand(),
                  ),
                ),
              if (gradient) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: GlossyDecor.topSheen(base),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: GlossyDecor.bottomShade(base),
                      ),
                    ),
                  ),
                ),
              ],
              if (_inert)
                content
              else
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onTap,
                    onLongPress: widget.onLongPress,
                    child: content,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PressGlowPainter extends CustomPainter {
  final double press;
  final bool dark;
  final Offset? point;

  const _PressGlowPainter({
    required this.press,
    required this.dark,
    required this.point,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (press <= 0.01) return;
    final rect = Offset.zero & size;
    // #***! натуральный блеск: аддитивный поверх стекла и контента
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = ui.BlendMode.plus
        ..color = Colors.white.withValues(alpha: (dark ? 0.05 : 0.09) * press),
    );
    final clampRect = rect.deflate(6);
    final raw = point;
    final center = raw == null
        ? null
        : Offset(
            raw.dx.clamp(clampRect.left, clampRect.right),
            raw.dy.clamp(clampRect.top, clampRect.bottom),
          );
    if (center != null) {
      final radius = size.shortestSide * 0.9;
      final shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: (dark ? 0.12 : 0.16) * press),
          Colors.white.withValues(alpha: 0.04 * press),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = ui.BlendMode.plus
          ..shader = shader
          ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 12 * press),
      );
    }
  }

  @override
  bool shouldRepaint(_PressGlowPainter oldDelegate) =>
      oldDelegate.press != press ||
      oldDelegate.dark != dark ||
      oldDelegate.point != point;
}
