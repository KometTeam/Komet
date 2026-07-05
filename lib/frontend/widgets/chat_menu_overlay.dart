import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/haptics.dart';
import 'animated_overlay_popup.dart';

class ChatMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool dividerAfter;
  final bool destructive;

  const ChatMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.showChevron = false,
    this.dividerAfter = false,
    this.destructive = false,
  });
}

void showChatMenu({
  required BuildContext context,
  required Rect anchorRect,
  required List<ChatMenuItem> items,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ChatMenuLayer(
      anchorRect: anchorRect,
      items: items,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
  Haptics.medium();
}

class _ChatMenuLayer extends StatefulWidget {
  final Rect anchorRect;
  final List<ChatMenuItem> items;
  final VoidCallback onDismiss;

  const _ChatMenuLayer({
    required this.anchorRect,
    required this.items,
    required this.onDismiss,
  });

  @override
  State<_ChatMenuLayer> createState() => _ChatMenuLayerState();
}

class _ChatMenuLayerState extends State<_ChatMenuLayer>
    with SingleTickerProviderStateMixin, AnimatedOverlayPopup<_ChatMenuLayer> {
  static const double _menuWidth = 290.0;
  static const double _hMargin = 8.0;
  static const double _vMargin = 8.0;
  static const double _gap = 6.0;

  @override
  Duration get overlayForwardDuration => const Duration(milliseconds: 220);

  @override
  Duration get overlayReverseDuration => const Duration(milliseconds: 160);

  @override
  VoidCallback get onOverlayDismiss => widget.onDismiss;

  void _onItemTap(ChatMenuItem item) {
    Haptics.tap();
    closeOverlay().then((_) => item.onTap?.call());
  }

  Rect _resolveRect(Size screen) {
    final maxWidth = screen.width - 2 * _hMargin;
    final width = maxWidth <= 0
        ? screen.width
        : (_menuWidth.clamp(0.0, maxWidth));
    final maxLeft = screen.width - width - _hMargin;
    double left = widget.anchorRect.right - width;
    if (left > maxLeft) left = maxLeft;
    if (left < _hMargin) left = _hMargin;
    final top = widget.anchorRect.bottom + _gap;
    return Rect.fromLTWH(left, top, width, 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final screen = MediaQuery.sizeOf(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final rect = _resolveRect(screen);
    final maxHeight = (screen.height - rect.top - bottomInset - _vMargin).clamp(
      120.0,
      double.infinity,
    );
    return AnimatedBuilder(
      animation: overlayAnimation,
      builder: (ctx, child) {
        final t = overlayAnimation.value.clamp(0.0, 1.0);
        final scale = 0.9 + 0.1 * t;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: closeOverlay,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: rect.left,
              top: rect.top,
              width: rect.width,
              child: Opacity(
                opacity: t,
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topRight,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 6),
                for (final item in widget.items) ...[
                  _ChatMenuRow(item: item, onTap: () => _onItemTap(item)),
                  if (item.dividerAfter)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.onSurface.withValues(alpha: 0.07),
                    ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMenuRow extends StatelessWidget {
  final ChatMenuItem item;
  final VoidCallback onTap;

  const _ChatMenuRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = item.destructive ? cs.error : cs.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Icon(item.icon, size: 24, weight: 350, color: fg),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (item.showChevron)
              Icon(
                Symbols.chevron_right,
                size: 22,
                weight: 400,
                color: cs.onSurface.withValues(alpha: 0.7),
              ),
          ],
        ),
      ),
    );
  }
}
