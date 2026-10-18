import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/config/app_frost.dart';
import '../../core/config/app_nav_pill_style.dart';
import '../../core/config/app_pill_gradient.dart';
import '../../core/config/app_visual_style.dart';
import 'animated_lottie_icon.dart';
import 'glossy_pill.dart';
import 'liquid_glass.dart';

class PillNavItem {
  final IconData icon;
  final String label;
  final bool longPressable;
  final String? animationAsset;

  const PillNavItem({
    required this.icon,
    required this.label,
    this.longPressable = false,
    this.animationAsset,
  });
}

class PillNavGeometry {
  final double navInnerW;
  final double activeWidth;
  final double inactiveWidth;

  const PillNavGeometry(this.navInnerW, this.activeWidth, this.inactiveWidth);

  factory PillNavGeometry.fromInnerWidth(double navInnerW, int itemCount) {
    final totalWeight = (itemCount - 1) + _activeWeight;
    final unit = navInnerW / totalWeight;
    return PillNavGeometry(navInnerW, unit * _activeWeight, unit);
  }

  factory PillNavGeometry.equal(double itemWidth, int itemCount) =>
      PillNavGeometry(itemWidth * itemCount, itemWidth, itemWidth);

  static const double _activeWeight = 2.2;
}

class SlidingPillNav extends StatelessWidget {
  final List<PillNavItem> items;
  final double position;
  final Duration animationDuration;
  final PillNavGeometry geometry;
  final ValueChanged<int> onTap;
  final void Function(int index, Offset globalPosition)? onItemLongPress;
  final double iconSize;
  final double labelGap;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool iconsOnly;
  final bool pressed;
  final BackdropKey? backdropKey;

  const SlidingPillNav({
    super.key,
    required this.items,
    required this.position,
    required this.geometry,
    required this.onTap,
    this.animationDuration = Duration.zero,
    this.onItemLongPress,
    this.iconSize = 22,
    this.labelGap = 6,
    this.backgroundColor,
    this.borderColor,
    this.iconsOnly = false,
    this.pressed = false,
    this.backdropKey,
  });

  static const double height = 68;

  double _interpWidth(int tab, PillNavGeometry geometry) {
    final maxIndex = items.length - 1;
    final rt = position.clamp(0.0, maxIndex.toDouble());
    final i0 = rt.floor();
    final i1 = rt.ceil();
    final frac = i0 == i1 ? 0.0 : rt - i0;
    double at(int sel) =>
        tab == sel ? geometry.activeWidth : geometry.inactiveWidth;
    return at(i0) + (at(i1) - at(i0)) * frac;
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder<VisualStyle>(
      valueListenable: AppVisualStyle.current,
      builder: (context, style, _) {
        if (style == VisualStyle.materialYou) {
          return _buildNav(
            context,
            glossy: false,
            gradient: false,
            frost: false,
            liquid: false,
          );
        }
        return ValueListenableBuilder<bool>(
          valueListenable: AppPillGradient.current,
          builder: (context, gradient, _) =>
              ValueListenableBuilder<NavPillStyle>(
                valueListenable: AppNavPillStyle.current,
                builder: (context, navStyle, _) => _buildNav(
                  context,
                  glossy: true,
                  gradient: gradient,
                  frost: NavPillMaterial.isFrost(navStyle),
                  liquid: NavPillMaterial.isLiquid(navStyle),
                ),
              ),
        );
      },
    );
  }

  Widget _buildNav(
    BuildContext context, {
    required bool glossy,
    required bool gradient,
    required bool frost,
    required bool liquid,
  }) {
    final cs = Theme.of(context).colorScheme;
    final visualSel = position.round().clamp(0, items.length - 1);
    final translucent = backgroundColor != null && backgroundColor!.a < 1;
    final base = liquid
        ? (translucent ? backgroundColor! : Colors.transparent)
        : (backgroundColor ??
              (frost ? AppFrost.glassTint(cs) : cs.surfaceContainerHigh));
    final useGradient = glossy && gradient && !liquid;
    final frosted = frost && !liquid && base.a < 1;
    // #***! бар и линза — поверхности liquid_glass_widgets: у стека свой
    // изолированный бэкдроп-группой, чёрных дыр от платформ-вью нет;
    // ios27* — реплика системного glassEffect(.regular), clear-режим — Glass.clear

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: useGradient || liquid ? null : base,
        gradient: useGradient ? GlossyDecor.fillGradient(base) : null,
        borderRadius: BorderRadius.circular(34),
        border: glossy
            ? GlossyDecor.rimBorder(base)
            : (borderColor != null
                  ? Border.all(color: borderColor!, width: 0.5)
                  : null),
        boxShadow: frosted || liquid
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: liquid ? 0.28 : 0.5),
                  blurRadius: liquid ? 26 : 20,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : geometry.navInnerW;
          final scale = geometry.navInnerW > 0
              ? width / geometry.navInnerW
              : 0.0;
          final layout = PillNavGeometry(
            width,
            geometry.activeWidth * scale,
            geometry.inactiveWidth * scale,
          );
          return Stack(
            clipBehavior: liquid ? Clip.none : Clip.hardEdge,
            children: [
              if (liquid)
                Positioned.fill(
                  child: IgnorePointer(
                    child: GlassContainer(
                      useOwnLayer: true,
                      quality: GlassQuality.premium,
                      shape: const LiquidRoundedSuperellipse(borderRadius: 34),
                      settings: LiquidGlass.surfaceSettings(context, base),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              if (frosted)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: AppFrost.sigma,
                          sigmaY: AppFrost.sigma,
                        ),
                        backdropGroupKey: backdropKey,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              if (useGradient)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: GlossyDecor.topSheen(base),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!liquid)
                AnimatedPositioned(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  left: position * layout.inactiveWidth + 4,
                  top: 8,
                  bottom: 8,
                  width: (layout.activeWidth - 8).clamp(0.0, layout.navInnerW),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                width: layout.navInnerW,
                child: Row(
                  children: List.generate(items.length, (i) {
                    return AnimatedContainer(
                      duration: animationDuration,
                      curve: Curves.easeOutCubic,
                      width: _interpWidth(i, layout),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: _PillNavCell(
                          key: ValueKey('pill-nav-item-$i'),
                          item: items[i],
                          selected: i == visualSel,
                          cs: cs,
                          selectedColor: liquid ? cs.onSurface : cs.onPrimary,
                          animationDuration: animationDuration,
                          iconSize: iconSize,
                          labelGap: labelGap,
                          iconsOnly: iconsOnly,
                          onTap: () => onTap(i),
                          onLongPress:
                              (onItemLongPress == null ||
                                  !items[i].longPressable)
                              ? null
                              : (pos) => onItemLongPress!(i, pos),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (liquid)
                _LiquidLensPill(
                  position: position.clamp(0.0, (items.length - 1).toDouble()),
                  pressed: pressed,
                  layout: layout,
                  tint: cs.primary.withValues(alpha: 0.35),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LiquidLensPill extends StatefulWidget {
  const _LiquidLensPill({
    required this.position,
    required this.pressed,
    required this.layout,
    required this.tint,
  });

  final double position;
  final bool pressed;
  final PillNavGeometry layout;
  final Color tint;

  @override
  State<_LiquidLensPill> createState() => _LiquidLensPillState();
}

class _LiquidLensPillState extends State<_LiquidLensPill>
    with TickerProviderStateMixin {
  static final _settleSpring = GlassSpring.snappy(
    duration: const Duration(milliseconds: 400),
  );
  static final _pressSpring = GlassSpring.interactive(
    duration: const Duration(milliseconds: 250),
    extraBounce: 0.1,
  );
  static final _followSpring = GlassSpring.interactive(
    duration: const Duration(milliseconds: 140),
  );
  static const _maxDragVelocity = 25.0;

  late final _settle = SingleSpringController(
    vsync: this,
    spring: _settleSpring,
    initialValue: widget.position,
  );
  late final _press = SingleSpringController(
    vsync: this,
    spring: _pressSpring,
    initialValue: widget.pressed ? 1.0 : 0.0,
  );

  DateTime? _lastDragTick;
  double _lastDragPosition = 0;
  double _dragVelocity = 0;

  @override
  void initState() {
    super.initState();
    _lastDragPosition = widget.position;
  }

  @override
  void didUpdateWidget(covariant _LiquidLensPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != oldWidget.position) {
      final now = DateTime.now();
      if (_lastDragTick != null) {
        final dtMs = now.difference(_lastDragTick!).inMicroseconds / 1000;
        if (dtMs > 0) {
          _dragVelocity = (widget.position - _lastDragPosition) / (dtMs / 1000);
        }
      }
      _lastDragTick = now;
      _lastDragPosition = widget.position;
      if (widget.pressed) {
        // следуем за пальцем на быстрой пружине: лёгкое желейное запаздывание,
        // крупный прыжок (зажали вне селектора) превращается в перелёт
        _settle.spring = _followSpring;
        _settle.animateTo(widget.position);
      } else {
        _lastDragTick = null;
        _settle.spring = _settleSpring;
        _settle.animateTo(
          widget.position,
          fromVelocity: _dragVelocity.clamp(
            -_maxDragVelocity,
            _maxDragVelocity,
          ),
        );
        _dragVelocity = 0;
      }
    }
    if (widget.pressed != oldWidget.pressed) {
      if (widget.pressed) {
        _settle.spring = _followSpring;
        _settle.animateTo(widget.position);
      } else {
        _settle.spring = _settleSpring;
        _settle.animateTo(
          widget.position,
          fromVelocity: _dragVelocity.clamp(
            -_maxDragVelocity,
            _maxDragVelocity,
          ),
        );
        _dragVelocity = 0;
        _lastDragTick = null;
      }
      _press.animateTo(widget.pressed ? 1.0 : 0.0);
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_settle, _press]),
      builder: (context, _) {
        final press = _press.value.clamp(0.0, 1.0);
        final bulgeW = press * 18.0;
        final bulgeH = press * 24.0;
        // стретч по скорости: стекло тянется вдоль разгона и сжимается поперёк
        final speedPx = _settle.velocity.abs() * widget.layout.inactiveWidth;
        final stretch = (speedPx / 2800.0).clamp(0.0, 0.30);
        final width =
            (widget.layout.activeWidth - 8).clamp(
              0.0,
              widget.layout.navInnerW,
            ) +
            bulgeW;
        final height = 52.0 + bulgeH;
        final left =
            _settle.value * widget.layout.inactiveWidth +
            4 -
            bulgeW / 2 -
            width * stretch / 2;
        final inset = height * 0.18 * stretch;
        return Positioned(
          left: left,
          top: 8 - bulgeH / 2 + inset,
          bottom: 8 - bulgeH / 2 + inset,
          width: width * (1 + stretch),
          child: IgnorePointer(
            child: GlassContainer(
              useOwnLayer: true,
              quality: GlassQuality.premium,
              shape: LiquidRoundedSuperellipse(borderRadius: height / 2),
              // copyWithPinch — системный эффект из AnimatedGlassIndicator: бар за
              // кромками пилюли сжимается к её центру, при зажатии выглядит мельче
              settings: LiquidGlassSettings(
                bodyMode: GlassBodyMode.clear,
                blur: 0,
                glassColor: widget.tint.withValues(
                  alpha: widget.tint.a * (1.0 - 0.55 * press),
                ),
                thickness: 16.0,
                refractiveIndex: 1 + 0.3 * press,
                saturation: 1.5,
                lensModel: GlassLensModel.paraxial,
                specularSharpness: GlassSpecularSharpness.medium,
                shadowElevation: 0,
                chromaticAberration: 0.01 + 1 * press,
                edgeAbsorption: 0.3,
              ).copyWithPinch(0.5 * press),
              child: const SizedBox.expand(),
            ),
          ),
        );
      },
    );
  }
}

class _PillNavCell extends StatelessWidget {
  final PillNavItem item;
  final bool selected;
  final ColorScheme cs;
  final Color selectedColor;
  final Duration animationDuration;
  final double iconSize;
  final double labelGap;
  final bool iconsOnly;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onLongPress;

  const _PillNavCell({
    super.key,
    required this.item,
    required this.selected,
    required this.cs,
    required this.selectedColor,
    required this.animationDuration,
    required this.iconSize,
    required this.labelGap,
    required this.iconsOnly,
    required this.onTap,
    required this.onLongPress,
  });

  Widget _buildIcon() {
    final color = selected ? selectedColor : cs.onSurface;
    final asset = item.animationAsset;
    if (asset != null) {
      return AnimatedLottieIcon(
        asset: asset,
        color: color,
        size: iconSize,
        active: selected,
      );
    }
    return Icon(item.icon, color: color, size: iconSize, fill: 1);
  }

  @override
  Widget build(BuildContext context) {
    final opacityDuration = animationDuration == Duration.zero
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPress == null
          ? null
          : (d) => onLongPress!(d.globalPosition),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: iconsOnly
            ? _buildIcon()
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIcon(),
                    AnimatedContainer(
                      duration: animationDuration,
                      curve: Curves.easeOutCubic,
                      width: selected ? null : 0,
                      child: AnimatedOpacity(
                        duration: opacityDuration,
                        opacity: selected ? 1.0 : 0.0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: labelGap),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: selectedColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
