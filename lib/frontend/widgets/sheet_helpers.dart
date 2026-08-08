import 'package:flutter/material.dart';

import '../../core/config/app_shape.dart';

/// Standard rounded top shape for modal bottom sheets.
const RoundedRectangleBorder kSheetShape = AppShape.sheetBorder;

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
