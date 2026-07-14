import 'package:flutter/material.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/storage/token_storage.dart';
import '../chats/chat_info_screen.dart';

Future<void> openContactDialogProfile(
  BuildContext context, {
  required int contactId,
  required String name,
  String? avatarUrl,
}) async {
  final accountId = await TokenStorage.getActiveAccountId();
  final existing = accountId == null
      ? null
      : await AppDatabase.findDialogChatByParticipant(accountId, contactId);
  final chatId = existing ?? ((accountId ?? 0) ^ contactId);
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatInfoScreen(
        chatId: chatId,
        name: name,
        imageUrl: avatarUrl ?? '',
        chatType: 'DIALOG',
        dialogPeerId: contactId,
      ),
    ),
  );
}
