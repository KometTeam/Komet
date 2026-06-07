import 'package:flutter/material.dart';

/// Standard rounded top shape for modal bottom sheets.
const RoundedRectangleBorder kSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
);

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
