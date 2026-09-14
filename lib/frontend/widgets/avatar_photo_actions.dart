import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
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
bool get _savesToGallery =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

String avatarSaveLabel(BuildContext context) => _savesToGallery
    ? 'Сохранить в галерею'
    : (AppLocalizations.of(context)?.photoViewerSaveAs ?? 'Сохранить как…');

Future<void> saveAvatarPhoto(BuildContext context, String url) async {
  if (url.isEmpty) return;
  if (_savesToGallery) {
    final result = await saveImageFromUrl(url);
    if (!context.mounted) return;
    showCustomNotification(
      context,
      result.ok
          ? (result.toGallery
                ? 'Сохранено в галерею'
                : 'Сохранено: ${result.location}')
          : 'Не удалось сохранить: ${result.error}',
    );
    return;
  }

  final dialogTitle = avatarSaveLabel(context);
  final cacheName = 'avatar_${url.hashCode & 0x7fffffff}.jpg';
  final file = await MediaCache.getOrDownload(cacheName, url);
  if (!context.mounted) return;
  if (file == null) {
    showCustomNotification(context, 'Не удалось загрузить фото');
    return;
  }
  final result = await saveFileAs(
    source: file,
    fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    dialogTitle: dialogTitle,
  );
  if (!context.mounted || result.cancelled) return;
  showCustomNotification(
    context,
    result.saved ? 'Сохранено: ${result.path}' : 'Не удалось сохранить файл',
  );
}

Future<bool> confirmAvatarDeletion(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
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
              'Удалить фото?',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Фотография пропадёт из профиля и из истории аватарок.',
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
              child: const Text('Удалить'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
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
          label: 'Удалить',
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
