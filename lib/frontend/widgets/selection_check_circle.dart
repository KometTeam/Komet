import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_colors.dart';

/// Кружок выбора сообщения. Диаметр и отступ снизу подстраиваются под высоту
/// строки: на мелком кегле строка ниже кружка, и без подгонки кружки соседних
/// сообщений налезают друг на друга.
class SelectionCheckCircle extends StatelessWidget {
  const SelectionCheckCircle({
    super.key,
    required this.selected,
    this.diameter = maxDiameter,
  });

  static const double maxDiameter = 24;
  static const double minDiameter = 14;
  static const double preferredBottomInset = 10;
  static const double _verticalGap = 4;

  final bool selected;
  final double diameter;

  static double diameterFor(double rowHeight) {
    if (!rowHeight.isFinite) return maxDiameter;
    final fitted = (rowHeight - _verticalGap)
        .clamp(minDiameter, maxDiameter)
        .toDouble();
    return fitted < rowHeight ? fitted : rowHeight;
  }

  static double bottomInsetFor(double rowHeight, double diameter) =>
      rowHeight.isFinite
      ? ((rowHeight - diameter) / 2).clamp(0.0, preferredBottomInset).toDouble()
      : preferredBottomInset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(
          color: selected ? cs.primary : cs.mutedText,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(
              Symbols.check,
              size: diameter * 0.66,
              weight: 700,
              color: cs.onPrimary,
            )
          : null,
    );
  }
}
