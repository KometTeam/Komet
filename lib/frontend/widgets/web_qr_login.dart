import 'package:flutter/material.dart';

import '../../main.dart' show accountModule;
import 'custom_notification.dart';
import 'sheet_helpers.dart';
import 'small_spinner.dart';

Future<bool> showWebQrLoginConfirmSheet(BuildContext context) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
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
                'Вход по QR',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Вы точно хотите войти в аккаунт через веб или приложение MAX '
                'на компьютере?',
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
                        'Отмена',
                        style: TextStyle(color: cs.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('Войти'),
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
      showCustomNotification(context, 'Вход подтверждён');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showCustomNotification(context, 'Не удалось подтвердить вход: $e');
    }
    return false;
  }
}
