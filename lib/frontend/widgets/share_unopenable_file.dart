import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import 'custom_notification.dart';
import '../../core/security/app_lock.dart';

Future<void> shareUnopenableFile(BuildContext context, String path) async {
  showCustomNotification(
    context,
    AppLocalizations.of(context)!.fileNoAppToOpen,
  );
  await AppLock.instance.external(() => Share.shareXFiles([XFile(path)]));
}
