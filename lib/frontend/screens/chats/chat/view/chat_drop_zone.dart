import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/config/app_fonts.dart';
import 'package:komet/core/config/app_shape.dart';
import 'package:komet/core/utils/desktop_platform.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/l10n/app_localizations.dart';

class ChatDropZone extends StatefulWidget {
  final bool enabled;
  final ValueChanged<List<String>> onDrop;
  final Widget child;

  const ChatDropZone({
    super.key,
    required this.enabled,
    required this.onDrop,
    required this.child,
  });

  @override
  State<ChatDropZone> createState() => _ChatDropZoneState();
}

class _ChatDropZoneState extends State<ChatDropZone> {
  bool _hovering = false;

  bool get _active =>
      widget.enabled && ModalRoute.isCurrentOf(context) != false;

  void _setHovering(bool value) {
    if (_hovering == value) return;
    if (!_active) {
      _hovering = value;
      return;
    }
    setState(() => _hovering = value);
  }

  Future<void> _onDragDone(DropDoneDetails details) async {
    _setHovering(false);
    final paths = <String>[];
    var folders = 0;
    for (final item in details.files) {
      if (item.path.isEmpty) continue;
      if (item is DropItemDirectory ||
          await FileSystemEntity.isDirectory(item.path)) {
        folders++;
      } else {
        paths.add(item.path);
      }
    }
    if (!mounted) return;
    if (paths.isNotEmpty) widget.onDrop(paths);
    if (folders > 0) {
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.chatDropFoldersUnsupported,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktopPlatform) return widget.child;
    final active = _active;
    return DropTarget(
      enable: active,
      onDragEntered: (_) => _setHovering(true),
      onDragExited: (_) => _setHovering(false),
      onDragDone: (details) => unawaited(_onDragDone(details)),
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: active && _hovering ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: const _DropHint(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropHint extends StatelessWidget {
  const _DropHint();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: cs.surface.withValues(alpha: 0.82),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppShape.cardRadius,
            border: Border.all(color: cs.primary, width: 2),
            color: cs.primary.withValues(alpha: 0.06),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Symbols.upload_file,
                  size: 48,
                  weight: 300,
                  color: cs.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.chatDropHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    fontFamily: displayFontOf(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
