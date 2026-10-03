import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_shape.dart';
import '../../core/utils/media_cache.dart';
import '../../core/utils/media_saver.dart';
import '../../core/utils/save_file_as.dart';
import '../../l10n/app_localizations.dart';
import 'chat_menu_overlay.dart';
import 'custom_notification.dart';
import 'sheet_helpers.dart';

// #***! на телефоне аватарка едет в галерею, на десктопе в выбранную папку
String avatarSaveLabel(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return savesToGallery
      ? l10n.photoViewerSaveToGallery
      : l10n.photoViewerSaveAs;
}

Future<void> saveAvatarPhoto(BuildContext context, String url) async {
  if (url.isEmpty) return;
  if (savesToGallery) {
    final result = await saveImageFromUrl(url);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showCustomNotification(
      context,
      result.ok
          ? (result.toGallery
                ? l10n.photoViewerSavedToGallery
                : l10n.photoViewerSavedTo('${result.location}'))
          : l10n.notificationsSaveFailed(result.errorText(l10n)),
    );
    return;
  }

  final dialogTitle = avatarSaveLabel(context);
  final cacheName = 'avatar_${url.hashCode & 0x7fffffff}.jpg';
  final file = await MediaCache.getOrDownload(cacheName, url);
  if (!context.mounted) return;
  if (file == null) {
    showCustomNotification(
      context,
      AppLocalizations.of(context)!.avatarPhotoLoadFailed,
    );
    return;
  }
  final result = await saveFileAs(
    source: file,
    fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    dialogTitle: dialogTitle,
  );
  if (!context.mounted || result.cancelled) return;
  final l10n = AppLocalizations.of(context)!;
  showCustomNotification(
    context,
    result.saved
        ? l10n.photoViewerSavedTo('${result.path}')
        : l10n.photoViewerSaveFileFailed,
  );
}

Future<bool> confirmAvatarDeletion(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.avatarPhotoDeleteTitle,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.avatarPhotoDeleteBody,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: AppShape.buttonBorder,
              ),
              child: Text(l10n.msgActionsDelete),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.chatInfoActionCancel),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed == true;
}

// #***! одно меню на шапку настроек и на полноэкранный просмотр
void showAvatarMenu({
  required BuildContext context,
  required Rect anchorRect,
  required VoidCallback onSave,
  VoidCallback? onDelete,
}) {
  showChatMenu(
    context: context,
    anchorRect: anchorRect,
    items: [
      ChatMenuItem(
        icon: Symbols.download,
        label: avatarSaveLabel(context),
        onTap: onSave,
      ),
      if (onDelete != null)
        ChatMenuItem(
          icon: Symbols.delete,
          label: AppLocalizations.of(context)!.msgActionsDelete,
          destructive: true,
          onTap: onDelete,
        ),
    ],
  );
}

Rect? anchorRectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
