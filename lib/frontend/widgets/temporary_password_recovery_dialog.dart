import 'package:flutter/material.dart';

import '../../core/storage/temporary_password_recovery.dart';
import '../../core/storage/token_storage.dart';
import '../../l10n/app_localizations.dart';
import 'confirm_dialog.dart';

Future<void> showTemporaryPasswordRecovery(
  BuildContext context,
  int accountId, {
  int? verifiedAccountId,
}) async {
  Future<bool> authorized() async =>
      verifiedAccountId == accountId ||
      await TokenStorage.getActiveAccountId() == accountId;
  if (!await authorized()) return;
  final recovery = await TemporaryPasswordRecovery.read(accountId);
  if (recovery == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.temporaryPasswordRecoveryTitle,
    message: l10n.temporaryPasswordRecoveryMessage,
    confirmLabel: l10n.temporaryPasswordRecoveryShow,
  );
  if (!confirmed || !await authorized()) return;
  final current = await TemporaryPasswordRecovery.read(accountId);
  if (current?.operationId != recovery.operationId || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.temporaryPasswordRecoveryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectableText(recovery.password),
          const SizedBox(height: 16),
          Text(l10n.temporaryPasswordRecoveryInstructions),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
