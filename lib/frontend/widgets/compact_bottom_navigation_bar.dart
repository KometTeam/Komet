import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sliding_pill_nav.dart';

class CompactBottomNavigationBar extends StatelessWidget {
  const CompactBottomNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onItemLongPress,
  });

  final List<PillNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final void Function(int index, Offset position)? onItemLongPress;

  static double contentHeight(BuildContext context) =>
      math.max(50, 34 + MediaQuery.textScalerOf(context).scale(10) * 1.2);

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: contentHeight(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _CompactTab(
                    item: items[index],
                    selected: index == currentIndex,
                    onTap: () => onTap(index),
                    onLongPress:
                        items[index].longPressable && onItemLongPress != null
                        ? (position) => onItemLongPress!(index, position)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactTab extends StatefulWidget {
  const _CompactTab({
    required this.item,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final PillNavItem item;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onLongPress;

  @override
  State<_CompactTab> createState() => _CompactTabState();
}

class _CompactTabState extends State<_CompactTab> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.selected ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        onLongPressStart: widget.onLongPress == null
            ? null
            : (details) {
                _setPressed(false);
                widget.onLongPress!(details.globalPosition);
              },
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            opacity: _pressed ? 0.55 : 1,
            duration: const Duration(milliseconds: 100),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.item.icon,
                    color: color,
                    size: 24,
                    fill: widget.selected ? 1 : 0,
                    weight: widget.selected ? 500 : 400,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
