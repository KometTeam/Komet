import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_shape.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../contacts/contact_sheet_common.dart';
import 'chat_screen.dart';

Future<void> showChatPreview(
  BuildContext context, {
  required int chatId,
  required String name,
  required String imageUrl,
  required String chatType,
  required bool hasUnread,
  required VoidCallback onOpen,
  required Future<void> Function() onMarkRead,
}) {
  Haptics.medium();
  return showBlurredCard<void>(
    context,
    (_) => _ChatPreviewCard(
      chatId: chatId,
      name: name,
      imageUrl: imageUrl,
      chatType: chatType,
      hasUnread: hasUnread,
      onOpen: onOpen,
      onMarkRead: onMarkRead,
    ),
  );
}

class _ChatPreviewCard extends StatefulWidget {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;
  final bool hasUnread;
  final VoidCallback onOpen;
  final Future<void> Function() onMarkRead;

  const _ChatPreviewCard({
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
    required this.hasUnread,
    required this.onOpen,
    required this.onMarkRead,
  });

  @override
  State<_ChatPreviewCard> createState() => _ChatPreviewCardState();
}

class _ChatPreviewCardState extends State<_ChatPreviewCard> {
  static const double _maxWidth = 520;
  static const double _maxHeight = 680;

  bool _marking = false;

  void _open() {
    Navigator.of(context).pop();
    widget.onOpen();
  }

  Future<void> _markRead() async {
    if (_marking) return;
    setState(() => _marking = true);
    await widget.onMarkRead();
    if (!mounted) return;
    Haptics.success();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, _maxWidth);
              final height = math.min(constraints.maxHeight - 72, _maxHeight);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _open,
                    child: Container(
                      width: width,
                      height: height,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(AppShape.card),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        removeBottom: true,
                        child: ChatScreen(
                          chatId: widget.chatId,
                          name: widget.name,
                          imageUrl: widget.imageUrl,
                          chatType: widget.chatType,
                          embedded: true,
                          preview: true,
                          onClose: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: width,
                    child: Row(
                      children: [
                        if (widget.hasUnread) ...[
                          Expanded(
                            child: _PreviewAction(
                              icon: Symbols.done_all,
                              label: l10n.chatPreviewMarkRead,
                              busy: _marking,
                              onTap: () => unawaited(_markRead()),
                              background: cs.surfaceContainerHigh,
                              foreground: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: _PreviewAction(
                            icon: Symbols.chat,
                            label: l10n.chatPreviewOpen,
                            onTap: _open,
                            background: cs.primary,
                            foreground: cs.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PreviewAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final bool busy;

  const _PreviewAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: busy ? null : onTap,
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
