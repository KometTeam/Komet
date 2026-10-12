import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../main.dart' show accountModule;
import 'custom_notification.dart';
import 'sheet_helpers.dart';
import 'small_spinner.dart';
import '../../core/config/app_fonts.dart';

Future<bool> showWebQrLoginConfirmSheet(BuildContext context) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      final l10n = AppLocalizations.of(sheetContext)!;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SheetGrabber(margin: EdgeInsets.zero)),
              const SizedBox(height: 20),
              Text(
                l10n.webQrLoginTitle,
                style: TextStyle(
                  fontFamily: displayFontOf(context),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.webQrLoginMessage,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: Text(
                        l10n.chatInfoActionCancel,
                        style: TextStyle(color: cs.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: Text(l10n.tokenLoginButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return agreed ?? false;
}

Future<bool> confirmAndAuthorizeWebQrLogin(
  BuildContext context,
  String qrLink,
) async {
  final confirmed = await showWebQrLoginConfirmSheet(context);
  if (!confirmed || !context.mounted) return false;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return PopScope(
        canPop: false,
        child: Center(
          child: Card(
            color: cs.surfaceContainerHigh,
            child: const Padding(
              padding: EdgeInsets.all(28),
              child: SmallSpinner(size: 36),
            ),
          ),
        ),
      );
    },
  );

  try {
    await accountModule.authorizeWebQrLogin(qrLink.trim());
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.webQrLoginConfirmed,
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.webQrLoginFailed('$e'),
      );
    }
    return false;
  }
}
