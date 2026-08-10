import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/models/chat_folder.dart';
import '../../../backend/modules/folders.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/utils/haptics.dart';
import '../../../main.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/sheet_helpers.dart';
import 'folder_edit_sheet.dart';

enum _FolderAction { edit, create, delete }

Future<void> showFolderActionSheet(
  BuildContext context, {
  required ChatFolder folder,
}) async {
  final cs = Theme.of(context).colorScheme;
  final isAllChats = folder.id == FoldersModule.allChatsFolderId;
  final canEdit = !isAllChats && (folder.canEditTitle || folder.canEditFilters);
  final canDelete = !isAllChats && folder.canDelete;

  final action = await showModalBottomSheet<_FolderAction>(
    context: context,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetGrabber(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
            child: Text(
              folder.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (canEdit)
            _ActionRow(
              icon: Symbols.edit,
              label: 'Изменить',
              onTap: () => Navigator.pop(ctx, _FolderAction.edit),
            ),
          _ActionRow(
            icon: Symbols.create_new_folder,
            label: 'Новая папка',
            onTap: () => Navigator.pop(ctx, _FolderAction.create),
          ),
          if (canDelete)
            _ActionRow(
              icon: Symbols.delete,
              label: 'Удалить',
              color: cs.error,
              onTap: () => Navigator.pop(ctx, _FolderAction.delete),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  switch (action) {
    case _FolderAction.edit:
      await showFolderEditSheet(context, folder: folder);
    case _FolderAction.create:
      await showFolderEditSheet(context);
    case _FolderAction.delete:
      await _confirmDelete(context, folder);
  }
}

Future<void> _confirmDelete(BuildContext context, ChatFolder folder) async {
  final confirmed = await showConfirmDialog(
    context,
    message: 'Удалить папку «${folder.title}»? Чаты останутся на месте.',
    confirmLabel: 'Удалить',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  final accountId = await TokenStorage.getActiveAccountId();
  if (accountId == null || !context.mounted) return;

  try {
    await FoldersModule.deleteFolders(api, accountId, [folder.id]);
    Haptics.success();
  } catch (e) {
    Haptics.error();
    if (!context.mounted) return;
    showCustomNotification(
      context,
      e is PacketError ? e.message : 'Не удалось удалить папку',
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = color ?? cs.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: tint, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: tint,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
