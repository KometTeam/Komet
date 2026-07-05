import 'package:flutter/material.dart';

import '../../core/calls/call_controller.dart';
import '../../core/calls/call_link.dart';
import '../screens/calls/call_screen.dart';
import 'confirm_dialog.dart';
import 'custom_notification.dart';

Future<bool> tryHandleCallLink(BuildContext context, String url) async {
  final token = CallLink.token(url);
  if (token == null) return false;

  final controller = CallController.instance;
  if (controller.isBusy) {
    showCustomNotification(context, 'Звонок уже идёт');
    return true;
  }

  final navigator = Navigator.of(context);
  final preview = await controller.previewCallLink(url);
  if (!context.mounted) return true;

  final name = (preview?.callName?.isNotEmpty ?? false)
      ? preview!.callName!
      : 'Звонок';
  final count = preview?.participantsCount ?? 0;
  final message = count > 0
      ? 'Присоединиться к звонку «$name»? Сейчас в звонке: $count.'
      : 'Присоединиться к звонку «$name»?';

  final confirmed = await showConfirmDialog(
    context,
    title: 'Звонок',
    message: message,
    confirmLabel: 'Присоединиться',
  );
  if (!confirmed || !context.mounted) return true;

  try {
    final session = await controller.joinByLink(
      token,
      isVideo: preview?.isVideo ?? false,
    );
    navigator.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(name: name, session: session, isGroup: true),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      showCustomNotification(context, 'Не удалось присоединиться к звонку');
    }
  }
  return true;
}
