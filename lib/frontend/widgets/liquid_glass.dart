import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/config/app_frost.dart';

class LiquidGlass {
  @visibleForTesting
  static bool? supportedOverride;

  static bool get isSupported =>
      supportedOverride ?? (!kIsWeb && ui.ImageFilter.isShaderFilterSupported);

  // #***! полупрозрачные тинты не должны затирать системный материал ios27:
  // тёмный 28% тинт на тёмном фоне превращает стекло в чёрное пятно
  static LiquidGlassSettings surfaceSettings(BuildContext context, Color tint) {
    final preset = Theme.of(context).brightness == Brightness.dark
        ? LiquidGlassSettings.ios27Dark
        : LiquidGlassSettings.ios27Light;
    return tint.a >= 0.6 ? preset.copyWith(glassColor: tint) : preset;
  }

  static LiquidShape surfaceShape(BorderRadius borderRadius) {
    final radius = borderRadius.topLeft.x;
    return radius <= 0
        ? const LiquidRoundedRectangle(borderRadius: 0)
        : LiquidRoundedSuperellipse(borderRadius: radius);
  }
}

class GlassSurface extends StatelessWidget {
  final bool liquid;
  final BorderRadius borderRadius;
  final Color frostTint;
  final double frostSigma;
  final BoxBorder? border;
  final BackdropKey? backdropKey;
  final Widget child;

  const GlassSurface({
    super.key,
    this.liquid = false,
    this.borderRadius = BorderRadius.zero,
    required this.frostTint,
    this.frostSigma = AppFrost.sigma,
    this.border,
    this.backdropKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (liquid && LiquidGlass.isSupported) {
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: GlassContainer(
                useOwnLayer: true,
                quality: GlassQuality.premium,
                shape: LiquidGlass.surfaceShape(borderRadius),
                settings: LiquidGlass.surfaceSettings(context, frostTint),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          if (border != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    border: border,
                  ),
                ),
              ),
            ),
          child,
        ],
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: frostSigma, sigmaY: frostSigma),
        backdropGroupKey: backdropKey,
        child: DecoratedBox(
          decoration: BoxDecoration(color: frostTint, border: border),
          child: child,
        ),
      ),
    );
  }
}
