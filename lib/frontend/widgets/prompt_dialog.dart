import 'package:flutter/material.dart';

Future<String?> showTextInputDialog(
  BuildContext context, {
  String? title,
  String? description,
  String? hint,
  String? initialValue,
  String confirmLabel = 'Подтвердить',
  String cancelLabel = 'Отмена',
  bool obscureText = false,
  int maxLines = 1,
  TextInputType? keyboardType,
}) async {
  final tec = TextEditingController(text: initialValue);
  try {
    return await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surfaceContainerHigh,
          title: title == null
              ? null
              : Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: cs.onSurface,
                  ),
                ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description != null) ...[
                Text(
                  description,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
              ],
              TextField(
                controller: tec,
                autofocus: true,
                obscureText: obscureText,
                maxLines: obscureText ? 1 : maxLines,
                keyboardType: keyboardType,
                decoration: InputDecoration(hintText: hint),
                onSubmitted: (v) {
                  final t = v.trim();
                  Navigator.pop(dialogContext, t.isEmpty ? null : t);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                cancelLabel,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
            FilledButton(
              onPressed: () {
                final t = tec.text.trim();
                Navigator.pop(dialogContext, t.isEmpty ? null : t);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  } finally {
    tec.dispose();
  }
}
