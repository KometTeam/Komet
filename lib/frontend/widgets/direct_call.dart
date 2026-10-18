import 'package:flutter/material.dart';

import '../../backend/modules/calls.dart';
import '../../core/calls/call_controller.dart';
import '../../l10n/app_localizations.dart';
import '../screens/calls/call_screen.dart';
import 'custom_notification.dart';

Future<bool> startDirectCall(
  BuildContext context, {
  required int peerId,
  required String name,
  String? avatarUrl,
  bool video = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final navigator = Navigator.of(context);
  final controller = CallController.instance;

  final active = controller.activeSession;
  if (active != null) {
    await navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            CallScreen(name: name, avatarUrl: avatarUrl, session: active),
      ),
    );
    return true;
  }

  if (peerId <= 0) {
    showCustomNotification(context, l10n.callsTabPeerUnknown);
    return false;
  }

  try {
    final session = await controller.startOutgoing(peerId, isVideo: video);
    if (!context.mounted) return false;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) =>
            CallScreen(name: name, avatarUrl: avatarUrl, session: session),
      ),
    );
    return true;
  } on CallPeerIsBotException {
    if (context.mounted) showCustomNotification(context, l10n.callPeerIsBot);
    return false;
  } catch (_) {
    if (context.mounted) {
      showCustomNotification(context, l10n.chatInfoCallFailed);
    }
    return false;
  }
}
