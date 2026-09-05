import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/config/app_fonts.dart';
import 'package:komet/core/config/app_shape.dart';
import 'package:komet/core/media/clipboard/pasted_attachment.dart';
import 'package:komet/core/utils/format.dart';
import 'package:komet/frontend/widgets/sheet_helpers.dart';
import 'package:komet/l10n/app_localizations.dart';

Future<String?> showPastePreviewSheet(
  BuildContext context, {
  required List<PastedAttachment> items,
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surfaceContainerHigh,
    shape: kSheetShape,
    builder: (_) => _PastePreviewSheet(items: items),
  );
}

class _PastePreviewSheet extends StatefulWidget {
  const _PastePreviewSheet({required this.items});

  final List<PastedAttachment> items;

  @override
  State<_PastePreviewSheet> createState() => _PastePreviewSheetState();
}

class _PastePreviewSheetState extends State<_PastePreviewSheet> {
  final TextEditingController _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  bool get _captionAllowed => widget.items.every((it) => it.isMedia);

  String _title(AppLocalizations l10n) {
    if (widget.items.length > 1) {
      return l10n.pasteAttachTitleMany(widget.items.length);
    }
    return switch (widget.items.first.kind) {
      PastedAttachmentKind.image => l10n.pasteAttachTitleImage,
      PastedAttachmentKind.video => l10n.pasteAttachTitleVideo,
      PastedAttachmentKind.file => l10n.pasteAttachTitleFile,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final single = widget.items.length == 1 ? widget.items.first : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.center, child: SheetGrabber()),
            const SizedBox(height: 6),
            Text(
              _title(l10n),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: displayFontOf(context),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child:
                    single != null && single.kind == PastedAttachmentKind.image
                    ? _SingleImagePreview(item: single)
                    : _AttachmentList(items: widget.items),
              ),
            ),
            if (_captionAllowed) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _caption,
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: cs.onSurface, fontSize: 15),
                decoration: InputDecoration(
                  hintText: l10n.pasteAttachCaptionHint,
                  hintStyle: TextStyle(color: cs.onSurfaceVariant),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: AppShape.buttonRadius,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SheetButton(
                    label: l10n.pasteAttachCancel,
                    filled: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SheetButton(
                    label: l10n.pasteAttachSend,
                    filled: true,
                    onTap: () =>
                        Navigator.of(context).pop(_caption.text.trim()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleImagePreview extends StatelessWidget {
  const _SingleImagePreview({required this.item});

  final PastedAttachment item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: AppShape.cardRadius,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280),
        color: cs.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Image.file(
          item.file,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _AttachmentTile(item: item),
        ),
      ),
    );
  }
}

class _AttachmentList extends StatelessWidget {
  const _AttachmentList({required this.items});

  final List<PastedAttachment> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _AttachmentTile(item: items[i]),
        ],
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.item});

  final PastedAttachment item;

  IconData get _icon => switch (item.kind) {
    PastedAttachmentKind.image => Symbols.image,
    PastedAttachmentKind.video => Symbols.movie,
    PastedAttachmentKind.file => Symbols.description,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: AppShape.buttonRadius,
          ),
          child: item.kind == PastedAttachmentKind.image
              ? ClipRRect(
                  borderRadius: AppShape.buttonRadius,
                  child: Image.file(
                    item.file,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(_icon, size: 22, color: cs.onSurfaceVariant),
                  ),
                )
              : Icon(_icon, size: 22, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatBytes(item.size),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
