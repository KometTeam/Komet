import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/config/app_unchecked_links.dart';
import '../../core/media/clipboard/clipboard_media.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/text_format.dart';
import '../../l10n/app_localizations.dart';
import 'custom_notification.dart';
import 'link_text.dart';
import 'prompt_dialog.dart';
import 'rich_message_controller.dart';
import 'selection_toolbar.dart';

class FormatSelectionToolbar extends StatefulWidget {
  const FormatSelectionToolbar({
    super.key,
    required this.controller,
    required this.editableState,
    this.onPasteMedia,
  });

  final RichMessageController controller;
  final EditableTextState editableState;
  final VoidCallback? onPasteMedia;

  @override
  State<FormatSelectionToolbar> createState() => _FormatSelectionToolbarState();
}

class _FormatSelectionToolbarState extends State<FormatSelectionToolbar> {
  static final Expando<TextRange> _formattedRange = Expando<TextRange>();

  static const Set<ContextMenuButtonType> _clipboardActions = {
    ContextMenuButtonType.cut,
    ContextMenuButtonType.copy,
    ContextMenuButtonType.paste,
  };

  bool _formatting = false;
  bool _clipboardHasMedia = false;

  bool get _canFormat {
    final selection = widget.controller.selection;
    return selection.isValid && !selection.isCollapsed;
  }

  bool get _resumesFormatting {
    final kept = _formattedRange[widget.controller];
    if (kept == null || !_canFormat) return false;
    final selection = widget.controller.selection;
    return selection.start < kept.end && selection.end > kept.start;
  }

  @override
  void initState() {
    super.initState();
    _formatting = _resumesFormatting;
    widget.controller.addListener(_onControllerChanged);
    if (widget.onPasteMedia != null) unawaited(_probeClipboard());
  }

  @override
  void didUpdateWidget(FormatSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _formattedRange[widget.controller] = _formatting && _canFormat
        ? widget.controller.selection
        : null;
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {
      if (!_canFormat) _formatting = false;
    });
  }

  Future<void> _probeClipboard() async {
    final hasMedia = await ClipboardMedia.hasMedia();
    if (!mounted || !hasMedia) return;
    setState(() => _clipboardHasMedia = true);
  }

  void _setFormatting(bool value) {
    if (_formatting == value) return;
    setState(() => _formatting = value);
  }

  void _pasteMedia() {
    widget.editableState.hideToolbar();
    widget.onPasteMedia?.call();
  }

  void _applyFormat(TextFormat format) {
    final controller = widget.controller;
    final selection = controller.selection;
    if (format != TextFormat.link) {
      Haptics.selection();
      controller.toggleFormat(format);
    } else if (controller.isFormatActive(format)) {
      Haptics.selection();
      controller.setLink(selection, null);
    } else {
      final editable = widget.editableState;
      editable.hideToolbar();
      unawaited(_promptLink(editable.context, controller, selection));
    }
  }

  List<ContextMenuButtonItem> _textActions(AppLocalizations l10n) {
    final actions = [...widget.editableState.contextMenuButtonItems];
    if (widget.onPasteMedia != null && _clipboardHasMedia) {
      final index = actions.indexWhere(
        (action) => !_clipboardActions.contains(action.type),
      );
      actions.insert(
        index == -1 ? actions.length : index,
        ContextMenuButtonItem(
          label: l10n.composerPasteAttachment,
          onPressed: _pasteMedia,
        ),
      );
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final formatting = _formatting && _canFormat;
    return SelectionToolbar(
      anchors: widget.editableState.contextMenuAnchors,
      floor: SelectionToolbarFloor.topOf(widget.editableState.context),
      depth: formatting ? 1 : 0,
      onBack: formatting ? () => _setFormatting(false) : null,
      items: formatting ? _formatItems(l10n) : _actionItems(context, l10n),
    );
  }

  List<SelectionToolbarItem> _actionItems(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return [
      if (_canFormat)
        SelectionToolbarItem(
          icon: Symbols.text_format,
          tint: Theme.of(context).colorScheme.primary,
          label: l10n.chatScreenFormatMenu,
          onPressed: () => _setFormatting(true),
        ),
      for (final action in _textActions(l10n))
        if (action.onPressed case final onPressed?)
          if (AdaptiveTextSelectionToolbar.getButtonLabel(context, action)
              case final label when label.isNotEmpty)
            SelectionToolbarItem(label: label, onPressed: onPressed),
    ];
  }

  List<SelectionToolbarItem> _formatItems(AppLocalizations l10n) {
    final controller = widget.controller;
    return [
      for (final format in composerFormats)
        SelectionToolbarItem(
          icon: _formatIcon(format),
          tint: format == TextFormat.code ? codeTextColor : null,
          label: _formatLabel(l10n, format),
          selected: controller.isFormatActive(format),
          onPressed: () => _applyFormat(format),
        ),
    ];
  }
}

Future<void> _promptLink(
  BuildContext context,
  RichMessageController controller,
  TextRange range,
) async {
  final l10n = AppLocalizations.of(context)!;
  final raw = await showTextInputDialog(
    context,
    title: l10n.chatScreenFormatLinkTitle,
    hint: l10n.chatScreenFormatLinkHint,
    keyboardType: TextInputType.url,
  );
  if (raw == null || !context.mounted) return;
  final url = AppUncheckedLinks.current.value ? raw : linkFromInput(raw);
  if (url == null) {
    showCustomNotification(context, l10n.chatScreenFormatLinkInvalid);
    return;
  }
  controller.setLink(range, url);
}

IconData _formatIcon(TextFormat format) => switch (format) {
  TextFormat.strong => Symbols.format_bold,
  TextFormat.emphasized => Symbols.format_italic,
  TextFormat.underline => Symbols.format_underlined,
  TextFormat.strikethrough => Symbols.format_strikethrough,
  TextFormat.monospaced => Symbols.code,
  TextFormat.code => Symbols.format_color_text,
  TextFormat.heading => Symbols.format_h1,
  TextFormat.quote => Symbols.format_quote,
  TextFormat.link => Symbols.link,
  TextFormat.animoji => Symbols.mood,
  TextFormat.userMention => Symbols.alternate_email,
};

String _formatLabel(AppLocalizations l10n, TextFormat format) =>
    switch (format) {
      TextFormat.heading => l10n.chatScreenFormatHeading,
      TextFormat.strong => l10n.chatScreenFormatBold,
      TextFormat.emphasized => l10n.chatScreenFormatItalic,
      TextFormat.underline => l10n.chatScreenFormatUnderline,
      TextFormat.strikethrough => l10n.chatScreenFormatStrikethrough,
      TextFormat.monospaced => l10n.chatScreenFormatMonospace,
      TextFormat.code => l10n.chatScreenFormatRed,
      TextFormat.quote => l10n.chatScreenFormatQuote,
      TextFormat.link => l10n.chatScreenFormatLink,
      TextFormat.animoji => 'Animoji',
      TextFormat.userMention => l10n.chatScreenFormatMention,
    };
