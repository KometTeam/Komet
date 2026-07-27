import 'dart:math' as math;

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
  Widget? header,
  Widget? footer,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ChatMenuLayer(
      anchorRect: anchorRect,
      items: items,
      header: header,
      footer: footer,
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
  final Widget? header;
  final Widget? footer;
  final VoidCallback onDismiss;

  const _ChatMenuLayer({
    required this.anchorRect,
    required this.items,
    required this.onDismiss,
    this.header,
    this.footer,
  });

  @override
  State<_ChatMenuLayer> createState() => _ChatMenuLayerState();
}

class _MenuLayout extends SingleChildLayoutDelegate {
  static const double menuWidth = 290.0;
  static const double margin = 8.0;
  static const double gap = 6.0;

  final Rect anchor;
  final EdgeInsets safeArea;

  const _MenuLayout({required this.anchor, required this.safeArea});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(menuWidth, constraints.maxWidth - margin * 2);
    final available =
        constraints.maxHeight - safeArea.top - safeArea.bottom - margin * 2;
    return BoxConstraints(
      minWidth: math.max(0, width),
      maxWidth: math.max(0, width),
      maxHeight: math.max(120.0, available),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = math.max(margin, size.width - childSize.width - margin);
    final left = (anchor.right - childSize.width).clamp(margin, maxLeft);

    final topLimit = safeArea.top + margin;
    final bottomLimit = size.height - safeArea.bottom - margin;
    final below = anchor.bottom + gap;
    final above = anchor.top - gap - childSize.height;

    double top;
    if (below + childSize.height <= bottomLimit) {
      top = below;
    } else if (above >= topLimit) {
      top = above;
    } else {
      top = bottomLimit - childSize.height;
    }
    return Offset(left, math.max(topLimit, top));
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.safeArea != safeArea;
}

class _ChatMenuLayerState extends State<_ChatMenuLayer>
    with SingleTickerProviderStateMixin, AnimatedOverlayPopup<_ChatMenuLayer> {
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeArea = MediaQuery.paddingOf(context);
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
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _MenuLayout(
                  anchor: widget.anchorRect,
                  safeArea: safeArea,
                ),
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: child,
                  ),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.header != null) ...[
                widget.header!,
                Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.onSurface.withValues(alpha: 0.07),
                ),
              ],
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
              if (widget.footer != null) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.onSurface.withValues(alpha: 0.07),
                ),
                widget.footer!,
              ],
            ],
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
