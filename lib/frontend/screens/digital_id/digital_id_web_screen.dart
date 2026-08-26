import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../backend/modules/webapp.dart' show WebAppLaunch;
import '../../../core/utils/logger.dart';
import '../../../main.dart' show digitalIdModule, webAppModule;
import '../webapp/web_app_screen.dart';

Future<void> resetDigitalIdWebData() async {
  await CookieManager.instance().deleteAllCookies();
  try {
    await WebStorageManager.instance().deleteAllData();
  } catch (_) {}
}

Future<void> resetDigitalIdSession() async {
  digitalIdModule.reset();
  try {
    await resetDigitalIdWebData();
  } catch (_) {}
}

class DigitalIdWebScreen extends StatelessWidget {
  final WebAppLaunch? initialLaunch;

  const DigitalIdWebScreen({super.key, this.initialLaunch});

  @override
  Widget build(BuildContext context) {
    return WebAppScreen(
      title: 'Цифровой ID',
      preferSystemUserAgent: true,
      privateChannel: true,
      mobileIdVerifier: digitalIdModule.fetchMobileIdVerification,
      loader: () async => initialLaunch ?? await webAppModule.fetchDigitalId(),
      onExternalCallback: webAppModule.handleExternalCallback,
      onConsoleMessage: (controller, consoleMessage) {
        final msg = '[DID] ${consoleMessage.message}';
        final lvl = consoleMessage.messageLevel.toString().toUpperCase();
        if (lvl.contains('ERROR')) {
          logger.e(msg);
        } else if (lvl.contains('WARNING')) {
          logger.w(msg);
        } else {
          logger.i(msg);
        }
      },
      onLoadStart: (controller, url) {
        if (url != null) {
          logger.i('[DID] loadStart: ${url.scheme}://${url.host}${url.path}');
        }
      },
      shouldOverrideUrlLoading: (_, action, _) async {
        final uri = action.request.url;
        final url = uri?.toString() ?? '';
        final scheme = uri?.scheme ?? '';
        if (kDebugMode) {
          debugPrint(
            '[KOMET-DID] nav: ${url.length > 140 ? url.substring(0, 140) : url}',
          );
        }
        if (scheme != 'http' && scheme != 'https') {
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
    );
  }
}
