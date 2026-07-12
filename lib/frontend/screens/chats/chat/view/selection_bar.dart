import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/glossy_pill.dart';

class SelectionTopBar extends StatelessWidget {
  final ColorScheme cs;
  final Set<String> selected;
  final bool glossy;
  final CachedMessage? copyMsg;
  final CachedMessage? editMsg;
  final VoidCallback onClear;
  final void Function(CachedMessage) onCopy;
  final void Function(CachedMessage) onEdit;
  final VoidCallback onDelete;

  const SelectionTopBar({
    super.key,
    required this.cs,
    required this.selected,
    required this.glossy,
    required this.copyMsg,
    required this.editMsg,
    required this.onClear,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final count = selected.length;
    final label = 'Выбрано $count';

    if (!glossy) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Symbols.close, color: cs.onSurface),
              onPressed: onClear,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            if (copyMsg != null)
              IconButton(
                icon: Icon(Symbols.content_copy, color: cs.onSurface),
                onPressed: () => onCopy(copyMsg!),
              ),
            if (editMsg != null)
              IconButton(
                icon: Icon(Symbols.edit, color: cs.onSurface),
                onPressed: () => onEdit(editMsg!),
              ),
            IconButton(
              icon: Icon(Symbols.delete, color: cs.onSurface),
              onPressed: onDelete,
            ),
          ],
        ),
      );
    }

    Widget actionBtn(IconData icon, VoidCallback onTap) => IconButton(
      icon: Icon(icon, weight: 500, color: cs.onSurface),
      onPressed: onTap,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: GlossyPill(
              onTap: onClear,
              child: Center(
                child: Icon(
                  Symbols.close,
                  color: cs.onSurface,
                  weight: 500,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GlossyPill(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlossyPill(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (copyMsg != null)
                    actionBtn(Symbols.content_copy, () => onCopy(copyMsg!)),
                  if (editMsg != null)
                    actionBtn(Symbols.edit, () => onEdit(editMsg!)),
                  actionBtn(Symbols.delete, onDelete),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectionBottomBar extends StatelessWidget {
  final ColorScheme cs;
  final Set<String> selected;
  final VoidCallback onReply;
  final VoidCallback onForward;

  const SelectionBottomBar({
    super.key,
    required this.cs,
    required this.selected,
    required this.onReply,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final single = selected.length == 1;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            if (single) ...[
              Expanded(
                child: _pill(
                  cs,
                  icon: Symbols.reply,
                  label: 'Ответить',
                  iconLeading: false,
                  onTap: onReply,
                ),
              ),
              const SizedBox(width: 12),
            ] else
              const Spacer(),
            Expanded(
              child: _pill(
                cs,
                icon: Symbols.forward,
                label: 'Переслать',
                iconLeading: true,
                onTap: onForward,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required bool iconLeading,
    required VoidCallback onTap,
  }) {
    final textWidget = Text(
      label,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'Outfit',
      ),
    );
    final iconWidget = Icon(icon, color: cs.onSurface, size: 22, weight: 500);
    return GlossyPill(
      onTap: onTap,
      color: Color.alphaBlend(
        cs.surfaceContainerHighest.withValues(alpha: 0.92),
        cs.surface,
      ),
      borderRadius: BorderRadius.circular(28),
      depth: 8,
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        width: 0.5,
      ),
      child: SizedBox(
        height: 54,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: iconLeading
              ? [iconWidget, const SizedBox(width: 8), textWidget]
              : [textWidget, const SizedBox(width: 8), iconWidget],
        ),
      ),
    );
  }
}
