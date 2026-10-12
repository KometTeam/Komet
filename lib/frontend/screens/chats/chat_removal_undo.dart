import 'package:flutter/material.dart';

import '../../../backend/modules/chats.dart' show chats;
import '../../widgets/custom_notification.dart';
import '../../widgets/undo_notification.dart';

void removeChatsWithUndo(
  BuildContext context, {
  required String message,
  required List<int> chatIds,
  required Future<String?> Function(int chatId) remove,
}) {
  if (chatIds.isEmpty) return;
  final overlay = Overlay.of(context, rootOverlay: true);
  chats.holdForRemoval(chatIds);
  showUndoNotification(
    context,
    message,
    onUndo: () => chats.releaseRemoval(chatIds),
    onCommit: () async {
      final errors = <String>[];
      for (final chatId in chatIds) {
        final error = await remove(chatId);
        if (error != null) errors.add(error);
      }
      chats.releaseRemoval(chatIds);
      if (errors.isEmpty || !overlay.mounted) return;
      showCustomNotificationOnOverlay(overlay, errors.first);
    },
  );
}
