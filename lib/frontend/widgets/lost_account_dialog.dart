import 'package:flutter/material.dart';

import '../../core/config/app_shape.dart';
import '../../l10n/app_localizations.dart';

enum LostAccountChoice { signIn, remove }

Future<LostAccountChoice?> showLostAccountDialog(
  BuildContext context, {
  required String name,
}) {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  return showDialog<LostAccountChoice>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: cs.surfaceContainerHigh,
      shape: AppShape.dialogBorder,
      title: Text(
        l10n.accountSessionLostTitle,
        style: TextStyle(color: cs.onSurface),
      ),
      content: Text(
        l10n.accountSessionLostBody(name),
        style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(LostAccountChoice.remove),
          child: Text(
            l10n.accountSessionLostRemove,
            style: TextStyle(color: cs.error),
          ),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(LostAccountChoice.signIn),
          child: Text(l10n.accountSessionLostSignIn),
        ),
      ],
    ),
  );
}
