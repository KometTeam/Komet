import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../../core/media/preview_image.dart';
import '../../../../../core/utils/media_cache.dart';
import '../../../../../core/utils/media_cache_names.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../widgets/attachment/avatar_editor.dart';
import '../../../../widgets/attachment/photo_pick.dart';
import '../../../../widgets/chat_menu_overlay.dart';
import '../../../../widgets/custom_notification.dart';
import '../../../../widgets/small_spinner.dart';
import '../../../../widgets/upload_bytes_label.dart';
import '../../../../widgets/upload_progress_ring.dart';
import '../message_media_draft.dart';

class EditMediaStrip extends StatefulWidget {
  final MessageMediaDraft draft;
  final bool enabled;

  const EditMediaStrip({super.key, required this.draft, this.enabled = true});

  static const double tileSize = 76;

  @override
  State<EditMediaStrip> createState() => _EditMediaStripState();
}

class _EditMediaStripState extends State<EditMediaStrip> {
  EditMediaItem? _opening;

  MessageMediaDraft get _draft => widget.draft;

  Future<void> _add() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await pickPhoto(context);
    if (picked == null || !mounted) return;
    _draft.add(picked.file, source: picked.item);
  }

  Future<void> _replace(EditMediaItem item) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await pickPhoto(context);
    if (picked == null || !mounted) return;
    _draft.replace(item, picked.file, source: picked.item);
  }

  Future<void> _edit(EditMediaItem item) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _opening = item);
    final source = await _sourceOf(item);
    if (!mounted) return;
    setState(() => _opening = null);
    if (source == null) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.mediaPreviewEditorOpenFailed,
      );
      return;
    }
    final edited = await openPhotoEditor(context, source);
    if (edited == null) return;
    if (!mounted) {
      edited.delete().then((_) {}, onError: (_) {});
      return;
    }
    _draft.replace(item, edited, temporary: true);
  }

  static Future<File?> _sourceOf(EditMediaItem item) async {
    final file = item.file;
    if (file != null) return file;
    final photo = item.kept;
    if (photo == null) return null;
    final localPath = photo.localPath;
    if (localPath != null && await File(localPath).exists()) {
      return File(localPath);
    }
    final url = photo.baseUrl ?? '';
    if (url.isEmpty || url.startsWith('data:')) return null;
    return MediaCache.getOrDownload(photoCacheName(photo, url), url);
  }

  void _openMenu(BuildContext anchor, EditMediaItem item) {
    final box = anchor.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final l10n = AppLocalizations.of(context)!;
    showChatMenu(
      context: anchor,
      anchorRect: box.localToGlobal(Offset.zero) & box.size,
      compact: true,
      items: [
        if (item.failed)
          ChatMenuItem(
            icon: Symbols.refresh,
            label: l10n.editMediaRetry,
            onTap: () => _draft.retry(item),
          ),
        ChatMenuItem(
          icon: Symbols.brush,
          label: l10n.editMediaEdit,
          onTap: () => _edit(item),
        ),
        ChatMenuItem(
          icon: Symbols.swap_horiz,
          label: l10n.editMediaReplace,
          onTap: () => _replace(item),
        ),
        ChatMenuItem(
          icon: Symbols.delete,
          label: l10n.editMediaRemove,
          destructive: true,
          onTap: () => _draft.remove(item),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && _opening == null;
    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        final items = _draft.items;
        return SizedBox(
          height: EditMediaStrip.tileSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == items.length) {
                return _AddTile(onTap: enabled ? _add : null);
              }
              final item = items[index];
              return _MediaTile(
                key: ObjectKey(item),
                item: item,
                busy: identical(_opening, item),
                onTap: enabled ? (anchor) => _openMenu(anchor, item) : null,
                onRemove: enabled ? () => _draft.remove(item) : null,
              );
            },
          ),
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  final EditMediaItem item;
  final bool busy;
  final void Function(BuildContext anchor)? onTap;
  final VoidCallback? onRemove;

  const _MediaTile({
    super.key,
    required this.item,
    required this.busy,
    required this.onTap,
    required this.onRemove,
  });

  static const Color _scrim = Color(0x66000000);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cacheWidth =
        (EditMediaStrip.tileSize * 2 * MediaQuery.devicePixelRatioOf(context))
            .round();
    final tap = onTap;
    return SizedBox.square(
      dimension: EditMediaStrip.tileSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _image(cs, cacheWidth),
            if (item.uploading) ...[
              const ColoredBox(color: _scrim),
              Center(
                child: UploadProgressRing(
                  progress: item.progress,
                  slot: 0,
                  color: Colors.white,
                  trackColor: Colors.white24,
                  size: 34,
                  strokeWidth: 2.4,
                  showCancelIcon: false,
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: UploadBytesLabel(progress: item.progress),
              ),
            ] else if (item.failed || busy) ...[
              const ColoredBox(color: _scrim),
              Center(
                child: busy
                    ? const SmallSpinner(size: 22, color: Colors.white)
                    : const Icon(Symbols.refresh, color: Colors.white),
              ),
            ],
            Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: tap == null ? null : () => tap(context)),
            ),
            if (onRemove != null)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Symbols.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _image(ColorScheme cs, int cacheWidth) {
    final file = item.file;
    final photo = item.kept;
    final preview = photo == null
        ? null
        : dataUriImage(photo, photo.previewData);
    final placeholder = preview == null
        ? ColoredBox(color: cs.surfaceContainerHighest)
        : Image(image: preview, fit: BoxFit.cover, gaplessPlayback: true);
    if (file != null) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    final url = photo?.baseUrl ?? '';
    if (url.isEmpty || url.startsWith('data:')) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      fadeInDuration: Duration.zero,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: AppLocalizations.of(context)!.editMediaAdd,
      child: Material(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: EditMediaStrip.tileSize,
            child: Icon(
              Symbols.add_photo_alternate,
              color: onTap == null
                  ? cs.onSurfaceVariant.withValues(alpha: 0.4)
                  : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
