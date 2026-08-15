import 'package:flutter/material.dart';

import '../../../backend/modules/webapp.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/link_opener.dart';
import '../../../core/utils/webview_support.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart' show webAppModule;
import '../../widgets/custom_notification.dart';
import 'web_app_bridge.dart';
import 'web_app_screen.dart';

Future<void> openMiniApp(
  BuildContext context, {
  required int botId,
  required String title,
  int? chatId,
  String entryPoint = WebAppEntryPoint.webApp,
}) async {
  if (botId <= 0) return;
  Haptics.tap();

  if (webViewSupported) {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebAppScreen(
          title: title,
          entryPoint: entryPoint,
          loader: () => webAppModule.fetchLaunch(botId, chatId: chatId),
        ),
      ),
    );
    return;
  }

  try {
    final launch = await webAppModule.fetchLaunch(botId, chatId: chatId);
    if (!context.mounted) return;
    await openExternalUrl(context, launch.url);
  } on WebAppUnavailable catch (e) {
    if (context.mounted) showCustomNotification(context, e.message);
  } catch (_) {
    if (context.mounted) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.miniAppFailed,
      );
    }
  }
}
