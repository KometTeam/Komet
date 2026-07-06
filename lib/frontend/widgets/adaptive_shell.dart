import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/debug_test.dart';
import '../../core/utils/update_checker.dart';
import '../screens/chats/chat_list_screen.dart';
import '../screens/chats/chat_screen.dart';
import 'update_dialog.dart';

class AdaptiveShell extends StatefulWidget {
  const AdaptiveShell({super.key});

  @override
  State<AdaptiveShell> createState() => _AdaptiveShellState();
}

class DesktopChatSelection {
  final int chatId;
  final String name;
  final String imageUrl;
  final String chatType;

  const DesktopChatSelection({
    required this.chatId,
    required this.name,
    required this.imageUrl,
    required this.chatType,
  });
}

class _AdaptiveShellState extends State<AdaptiveShell> {
  static const double _breakpoint = 900;
  static const double _defaultListWidth = 380;
  static const double _minListWidth = 280;
  static const double _maxListWidth = 560;
  static const double _minChatPaneWidth = 360;
  static const double _dividerHitWidth = 10;
  static const double _dividerLineWidth = 1;
  static const String _prefsKey = 'desktop_list_width';

  double _listWidth = _defaultListWidth;
  DesktopChatSelection? _selected;

  @override
  void initState() {
    super.initState();
    _loadListWidth();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCheckUpdate());
  }

  Future<void> _maybeCheckUpdate() async {
    if (DebugTest.enabled) return;
    final update = await UpdateChecker.check();
    if (update == null || !mounted) return;
    await showUpdateDialog(context, update);
  }

  Future<void> _loadListWidth() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_prefsKey);
    if (saved == null || !mounted) return;
    setState(() {
      _listWidth = saved.clamp(_minListWidth, _maxListWidth);
    });
  }

  Future<void> _persistListWidth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefsKey, _listWidth);
  }

  void _onChatSelected(DesktopChatSelection chat) {
    if (chat.imageUrl.isNotEmpty) {
      unawaited(
        precacheImage(
          CachedNetworkImageProvider(
            chat.imageUrl,
            maxWidth: 144,
            maxHeight: 144,
          ),
          context,
        ),
      );
    }
    setState(() => _selected = chat);
  }

  void _closeChat() {
    setState(() => _selected = null);
  }

  void _onDrag(double dx, double totalWidth) {
    final maxAllowedByPane = totalWidth - _minChatPaneWidth - _dividerHitWidth;
    final upperBound = maxAllowedByPane < _maxListWidth
        ? maxAllowedByPane
        : _maxListWidth;
    final lower = _minListWidth;
    final next = (_listWidth + dx).clamp(lower, upperBound);
    if (next == _listWidth) return;
    setState(() => _listWidth = next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _breakpoint) {
          return const ChatListScreen();
        }
        final totalWidth = constraints.maxWidth;
        final effectiveListWidth = _listWidth.clamp(
          _minListWidth,
          (totalWidth - _minChatPaneWidth - _dividerHitWidth).clamp(
            _minListWidth,
            _maxListWidth,
          ),
        );
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: cs.surface,
          body: Row(
            children: [
              SizedBox(
                width: effectiveListWidth,
                child: ChatListScreen(onChatSelected: _onChatSelected),
              ),
              _ResizeDivider(
                hitWidth: _dividerHitWidth,
                lineWidth: _dividerLineWidth,
                color: cs.outlineVariant.withValues(alpha: 0.35),
                onDrag: (dx) => _onDrag(dx, totalWidth),
                onDragEnd: _persistListWidth,
              ),
              Expanded(
                child: _selected == null
                    ? _EmptyChatPane(colorScheme: cs)
                    : ChatScreen(
                        key: ValueKey(_selected!.chatId),
                        chatId: _selected!.chatId,
                        name: _selected!.name,
                        imageUrl: _selected!.imageUrl,
                        chatType: _selected!.chatType,
                        embedded: true,
                        onClose: _closeChat,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResizeDivider extends StatefulWidget {
  final double hitWidth;
  final double lineWidth;
  final Color color;
  final ValueChanged<double> onDrag;
  final Future<void> Function() onDragEnd;

  const _ResizeDivider({
    required this.hitWidth,
    required this.lineWidth,
    required this.color,
    required this.onDrag,
    required this.onDragEnd,
  });

  @override
  State<_ResizeDivider> createState() => _ResizeDividerState();
}

class _ResizeDividerState extends State<_ResizeDivider> {
  bool _hovering = false;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final highlight = _dragging || _hovering;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _dragging = true),
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        onHorizontalDragEnd: (_) async {
          setState(() => _dragging = false);
          await widget.onDragEnd();
        },
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        child: SizedBox(
          width: widget.hitWidth,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: widget.lineWidth,
              color: highlight
                  ? cs.primary.withValues(alpha: 0.6)
                  : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChatPane extends StatelessWidget {
  final ColorScheme colorScheme;

  const _EmptyChatPane({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.surfaceContainerLow,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.chat_bubble,
              size: 56,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              weight: 300,
            ),
            const SizedBox(height: 14),
            Text(
              'Выберите чат',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
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
