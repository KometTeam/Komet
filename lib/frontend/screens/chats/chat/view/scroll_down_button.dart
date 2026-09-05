import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/core/config/app_frost.dart';
import 'package:komet/frontend/widgets/animated_text_swap.dart';
import 'package:komet/frontend/widgets/glossy_pill.dart';

class ScrollDownButton extends StatelessWidget {
  final ValueListenable<double> composerHeight;
  final bool materialComposer;
  final bool composerUnderlap;
  final bool frosted;
  final bool liquidChrome;
  final BackdropKey? pillBackdrop;
  final Animation<double> scrollDownCurved;
  final ValueListenable<int> newMessageCount;
  final VoidCallback onTap;

  static const double _scrollDownSize = 46.0;
  static const double _materialIconSlot = 48.0;

  const ScrollDownButton({
    super.key,
    required this.composerHeight,
    required this.materialComposer,
    required this.composerUnderlap,
    required this.frosted,
    required this.liquidChrome,
    required this.pillBackdrop,
    required this.scrollDownCurved,
    required this.newMessageCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: composerHeight,
      builder: (context, height, child) => Positioned(
        right: materialComposer
            ? (_materialIconSlot - _scrollDownSize) / 2
            : 16,
        bottom: (composerUnderlap ? height : 0) + 12,
        child: child!,
      ),
      child: AnimatedBuilder(
        animation: scrollDownCurved,
        builder: (context, child) {
          final t = scrollDownCurved.value;
          if (t == 0) return const SizedBox.shrink();
          final backdropVisible = t >= 1;
          return Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.82 + 0.18 * t,
              child: SizedBox(
                width: _scrollDownSize,
                height: _scrollDownSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: GlossyPill(
                        color: frosted || liquidChrome
                            ? AppFrost.glassTint(cs)
                            : null,
                        blurSigma: frosted && !liquidChrome && backdropVisible
                            ? AppFrost.sigma
                            : null,
                        liquid: liquidChrome,
                        backdropKey: pillBackdrop,
                        elevated: true,
                        onTap: onTap,
                        child: child!,
                      ),
                    ),
                    Positioned(
                      top: -5,
                      right: -3,
                      child: ValueListenableBuilder<int>(
                        valueListenable: newMessageCount,
                        builder: (context, count, _) => count <= 0
                            ? const SizedBox.shrink()
                            : AnimatedValueSwap<int>(
                                value: count > 99 ? 100 : count,
                                alignment: Alignment.centerRight,
                                builder: (context, value) =>
                                    _UnreadBadge(cs: cs, count: value),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: Center(
          child: Icon(
            Symbols.keyboard_arrow_down,
            color: cs.onSurface,
            weight: 500,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final ColorScheme cs;
  final int count;

  const _UnreadBadge({required this.cs, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 21),
      height: 21,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: cs.onPrimary,
          fontSize: 12,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
