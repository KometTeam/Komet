import 'dart:async';

import 'package:flutter/material.dart';

import 'package:komet/core/media/clipboard/clipboard_media.dart';

class PasteMediaToolbar extends StatefulWidget {
  const PasteMediaToolbar({
    super.key,
    required this.anchors,
    required this.buttonItems,
    required this.pasteItem,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;
  final ContextMenuButtonItem pasteItem;

  @override
  State<PasteMediaToolbar> createState() => _PasteMediaToolbarState();
}

class _PasteMediaToolbarState extends State<PasteMediaToolbar> {
  bool _hasMedia = false;

  @override
  void initState() {
    super.initState();
    unawaited(_probeClipboard());
  }

  Future<void> _probeClipboard() async {
    final hasMedia = await ClipboardMedia.hasMedia();
    if (!mounted || !hasMedia) return;
    setState(() => _hasMedia = true);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: widget.anchors,
      buttonItems: _hasMedia
          ? widget.buttonItems
          : widget.buttonItems
                .where((item) => item != widget.pasteItem)
                .toList(growable: false),
    );
  }
}
