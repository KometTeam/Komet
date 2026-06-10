import 'package:flutter/material.dart';

class PillNavItem {
  final IconData icon;
  final String label;
  final bool longPressable;

  const PillNavItem({
    required this.icon,
    required this.label,
    this.longPressable = false,
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
  });

  static const double height = 68;

  double _interpWidth(int tab) {
    final maxIndex = items.length - 1;
    final rt = position.clamp(0.0, maxIndex.toDouble());
    final i0 = rt.floor();
    final i1 = rt.ceil();
    final frac = i0 == i1 ? 0.0 : rt - i0;
    double at(int sel) =>
        (tab == sel ? geometry.activeWidth : geometry.inactiveWidth) - 0.5;
    return at(i0) + (at(i1) - at(i0)) * frac;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visualSel = position.round().clamp(0, items.length - 1);
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(34),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 0.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          AnimatedPositioned(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            left: position * geometry.inactiveWidth + 4,
            top: 8,
            bottom: 8,
            width: geometry.activeWidth - 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(26),
              ),
            ),
          ),
          SizedBox(
            width: geometry.navInnerW,
            child: Row(
              children: List.generate(items.length, (i) {
                return AnimatedContainer(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  width: _interpWidth(i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: _PillNavCell(
                      item: items[i],
                      selected: i == visualSel,
                      cs: cs,
                      animationDuration: animationDuration,
                      iconSize: iconSize,
                      labelGap: labelGap,
                      iconsOnly: iconsOnly,
                      onTap: () => onTap(i),
                      onLongPress:
                          (onItemLongPress == null || !items[i].longPressable)
                          ? null
                          : (pos) => onItemLongPress!(i, pos),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillNavCell extends StatelessWidget {
  final PillNavItem item;
  final bool selected;
  final ColorScheme cs;
  final Duration animationDuration;
  final double iconSize;
  final double labelGap;
  final bool iconsOnly;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onLongPress;

  const _PillNavCell({
    required this.item,
    required this.selected,
    required this.cs,
    required this.animationDuration,
    required this.iconSize,
    required this.labelGap,
    required this.iconsOnly,
    required this.onTap,
    required this.onLongPress,
  });

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
            ? Icon(
                item.icon,
                color: selected ? cs.onPrimary : cs.onSurface,
                size: iconSize,
                fill: 1,
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      color: selected ? cs.onPrimary : cs.onSurface,
                      size: iconSize,
                      fill: 1,
                    ),
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
                                color: cs.onPrimary,
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
