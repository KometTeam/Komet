import 'package:flutter/material.dart';

import '../../core/config/app_shape.dart';

/// Standard rounded top shape for modal bottom sheets.
const RoundedRectangleBorder kSheetShape = AppShape.sheetBorder;

/// Pill-shaped action button for the bottom row of a modal sheet.
class SheetButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  final Color? color;

  const SheetButton({
    super.key,
    required this.label,
    required this.filled,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    final fill = color ?? cs.primary;
    final labelColor = filled ? cs.onPrimary : (color ?? cs.onSurface);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (disabled ? fill.withValues(alpha: 0.4) : fill)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: disabled
                ? labelColor.withValues(alpha: filled ? 0.85 : 0.4)
                : labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// The little drag "grabber" pill shown at the top of a bottom sheet.
class SheetGrabber extends StatelessWidget {
  final EdgeInsetsGeometry margin;

  const SheetGrabber({
    super.key,
    this.margin = const EdgeInsets.symmetric(vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 4,
      margin: margin,
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
