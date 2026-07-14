import 'package:flutter/material.dart';

class SegmentedPillToggle extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final double segmentWidth;
  final double height;

  const SegmentedPillToggle({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    this.segmentWidth = 88,
    this.height = 34,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const pad = 3.0;
    final sel = selected.clamp(0, labels.length - 1);

    return Container(
      height: height,
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: sel * segmentWidth,
            top: 0,
            bottom: 0,
            width: segmentWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular((height - 2 * pad) / 2),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(labels.length, (i) {
              final active = i == sel;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: SizedBox(
                  width: segmentWidth,
                  child: Center(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      style: TextStyle(
                        color: active ? cs.onPrimary : cs.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      child: Text(labels[i]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
