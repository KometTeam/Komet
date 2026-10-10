import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/share_sender.dart';
import '../../../core/media/share_thumbnail.dart';
import '../../../core/share/share_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../models/animoji.dart';
import '../../../models/shared_payload.dart';
import '../../widgets/emoji_panel.dart';
import '../../widgets/rich_message_controller.dart';
import '../../widgets/small_spinner.dart';
import '../../widgets/springy_tap.dart';

class ShareComposerBar extends StatefulWidget {
  const ShareComposerBar({
    super.key,
    required this.title,
    this.hintText,
    required this.controller,
    required this.recipientNames,
    required this.onSend,
    this.thumbnail,
    this.headerAction,
    this.showHeader = true,
    this.textOnly = false,
    this.sending = false,
  });

  factory ShareComposerBar.forShare({
    Key? key,
    required AppLocalizations l10n,
    required PreparedShare share,
    required RichMessageController controller,
    required List<String> recipientNames,
    required Future<void> Function(RichMessageContent content) onSend,
    bool sending = false,
  }) => ShareComposerBar(
    key: key,
    title: shareTitleFor(
      l10n,
      photos: share.photos.length,
      videos: share.videos.length,
      documents: share.documents.length,
      textOnly: share.isTextOnly,
    ),
    showHeader: !share.isTextOnly,
    textOnly: share.isTextOnly,
    thumbnail: ShareThumbStack(files: share.files),
    controller: controller,
    recipientNames: recipientNames,
    onSend: onSend,
    sending: sending,
  );

  final String title;
  final String? hintText;
  final Widget? thumbnail;
  final Widget? headerAction;
  final bool showHeader;
  final bool textOnly;
  final RichMessageController controller;
  final List<String> recipientNames;
  final Future<void> Function(RichMessageContent content) onSend;
  final bool sending;

  @override
  State<ShareComposerBar> createState() => _ShareComposerBarState();
}

class _ShareComposerBarState extends State<ShareComposerBar> {
  static const double _emojiPanelHeight = 280;
  static const double _controlHeight = _SendButton.size;
  static const Duration _panelDuration = Duration(milliseconds: 220);

  final FocusNode _focus = FocusNode();
  bool _emojiOpen = false;

  RichMessageController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus && _emojiOpen) setState(() => _emojiOpen = false);
  }

  void _toggleEmoji() {
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
      return;
    }
    _focus.unfocus();
    setState(() => _emojiOpen = true);
  }

  void _insertAnimoji(Animoji animoji) {
    _controller.insertAnimoji(animoji);
    unawaited(animojiModule.noteUsed(animoji));
  }

  Future<void> _send() async {
    if (widget.sending) return;
    await widget.onSend(_controller.buildTrimmedContent());
  }

  String _subtitle(AppLocalizations l10n) =>
      shareSubtitleFor(l10n, widget.recipientNames);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: _emojiOpen ? 0 : bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showHeader) _buildPreviewRow(cs),
          _buildInputRow(cs),
          AnimatedSize(
            duration: _panelDuration,
            curve: Curves.easeOutCubic,
            child: _emojiOpen
                ? SizedBox(
                    height: _emojiPanelHeight + safeBottom,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: safeBottom),
                      child: EmojiPanel(onEmojiTap: _insertAnimoji),
                    ),
                  )
                : SizedBox(height: bottomInset > 0 ? 0 : safeBottom),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Icon(Symbols.forward, color: cs.primary, size: 22, weight: 500),
          const SizedBox(width: 12),
          if (widget.thumbnail case final thumbnail?) ...[
            thumbnail,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(AppLocalizations.of(context)!),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ?widget.headerAction,
        ],
      ),
    );
  }

  Widget _buildInputRow(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final hintText =
        widget.hintText ??
        (widget.textOnly
            ? l10n.composerHintMessage
            : l10n.attachSheetAddCaptionHint);
    final count = widget.recipientNames.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            height: _controlHeight,
            child: Center(
              child: IconButton(
                onPressed: _toggleEmoji,
                icon: Icon(
                  Symbols.mood,
                  color: _emojiOpen ? cs.primary : cs.onSurfaceVariant,
                  size: 26,
                  fill: _emojiOpen ? 1 : 0,
                ),
              ),
            ),
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: _controlHeight,
                maxHeight: 120,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                heightFactor: 1,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(color: cs.onSurface, fontSize: 16),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            count: count,
            sending: widget.sending,
            onTap: count == 0 ? null : _send,
          ),
        ],
      ),
    );
  }
}

class ShareThumbStack extends StatelessWidget {
  const ShareThumbStack({super.key, required this.files});

  final List<PreparedShareFile> files;

  static const double _size = 40;
  static const double _step = 9;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = files.take(3).toList();
    final width = _size + _step * (visible.length - 1).clamp(0, 2);

    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        children: [
          for (var i = visible.length - 1; i >= 0; i--)
            Positioned(
              left: i * _step,
              child: _ShareThumb(file: visible[i], size: _size, cs: cs),
            ),
        ],
      ),
    );
  }
}

class _ShareThumb extends StatelessWidget {
  const _ShareThumb({required this.file, required this.size, required this.cs});

  final PreparedShareFile file;
  final double size;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final provider = decodeSharedThumb(file.thumbDataUri);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.surfaceContainerHigh, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: provider != null
          ? Image(
              image: provider,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _localPhotoOrIcon(),
            )
          : _localPhotoOrIcon(),
    );
  }

  Widget _localPhotoOrIcon() {
    if (file.kind != SharedFileKind.photo) return _icon();
    return Image.file(
      file.file,
      fit: BoxFit.cover,
      cacheWidth: 128,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _icon(),
    );
  }

  Widget _icon() => Icon(
    switch (file.kind) {
      SharedFileKind.photo => Symbols.image,
      SharedFileKind.video => Symbols.movie,
      SharedFileKind.file => Symbols.description,
    },
    size: 20,
    color: cs.onSurfaceVariant,
  );
}

class _SendButton extends StatelessWidget {
  static const double size = 52;

  const _SendButton({
    required this.count,
    required this.sending,
    required this.onTap,
  });

  final int count;
  final bool sending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final enabled = onTap != null && !sending;

    return SpringyTap(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: enabled ? cs.primary : cs.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: sending
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SmallSpinner(size: 24, color: cs.onPrimary),
                    )
                  : Icon(
                      Symbols.send,
                      color: enabled ? cs.onPrimary : cs.onSurfaceVariant,
                      size: 24,
                      fill: 1,
                    ),
            ),
            if (count > 0 && !sending)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(minWidth: 20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.primary, width: 1.5),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
