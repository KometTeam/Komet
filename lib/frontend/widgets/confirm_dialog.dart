import 'package:flutter/material.dart';
import '../../core/config/app_shape.dart';

/// Shared confirmation dialog. Returns true if confirmed, false otherwise.
Future<bool> showConfirmDialog(
  BuildContext context, {
  String? title,
  required String message,
  String confirmLabel = 'OK',
  String cancelLabel = 'Отмена',
  bool destructive = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      shape: AppShape.dialogBorder,
      title: title == null
          ? null
          : Text(title, style: TextStyle(color: cs.onSurface)),
      content: Text(
        message,
        style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: cs.errorContainer,
                  foregroundColor: cs.onErrorContainer,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
