import 'package:flutter/material.dart';

import '../../core/config/app_pill_gradient.dart';
import '../../core/config/app_visual_style.dart';

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

class GlossyPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double depth;
  final bool elevated;
  final BorderSide? borderSide;

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
  }) : borderRadius =
           borderRadius ?? const BorderRadius.all(Radius.circular(100));

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VisualStyle>(
      valueListenable: AppVisualStyle.current,
      builder: (context, style, _) {
        if (style == VisualStyle.materialYou) return _flat(context);
        return ValueListenableBuilder<bool>(
          valueListenable: AppPillGradient.current,
          builder: (context, gradient, _) => _glossy(context, gradient),
        );
      },
    );
  }

  Widget _flat(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = color ?? cs.surfaceContainerHigh;
    final content = Padding(padding: padding, child: child);
    return Material(
      color: base,
      elevation: elevated ? 3 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: borderSide ?? BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null && onLongPress == null
          ? content
          : InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
    );
  }

  Widget _glossy(BuildContext context, bool gradient) {
    final cs = Theme.of(context).colorScheme;
    final base = color ?? cs.surfaceContainerHigh;
    final content = Padding(padding: padding, child: child);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: gradient ? null : base,
          gradient: gradient ? GlossyDecor.fillGradient(base) : null,
          border: GlossyDecor.rimBorder(base),
          boxShadow: [GlossyDecor.dropShadow(base, depth)],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
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
              if (onTap == null && onLongPress == null)
                content
              else
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    onLongPress: onLongPress,
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
