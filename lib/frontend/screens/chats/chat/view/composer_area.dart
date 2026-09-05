import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:komet/backend/modules/messages.dart'
    show CachedMessage, FileHistoryEntry;
import 'package:komet/frontend/commands/commands.dart' show SlashCommand;
import 'package:komet/core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_composer_background.dart';
import 'package:komet/core/config/app_composer_style.dart';
import 'package:komet/core/config/app_frost.dart';
import 'package:komet/core/media/clipboard/clipboard_media.dart';
import 'package:komet/models/animoji.dart' show Animoji;
import 'package:komet/models/sticker.dart' show StickerItem;
import 'package:komet/frontend/screens/chats/chat/sticker_panel_controller.dart';
import 'package:komet/frontend/screens/chats/chat/upload_status.dart'
    show UploadStatus;
import 'package:komet/frontend/screens/chats/chat/video_note_controller.dart';
import 'package:komet/frontend/screens/chats/chat/voice_record_controller.dart';
import 'package:komet/frontend/widgets/attachment_panel.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';

import 'command_arguments_form.dart';
import 'composer_input.dart';
import 'frosted_panel.dart';
import 'selection_bar.dart';
import 'sticker_panel_view.dart';

class ComposerArea extends StatelessWidget {
  final Animation<double> selectionAnim;
  final Animation<double> searchAnim;
  final Animation<double> attachAnim;
  final StickerPanelController stickers;

  final SlashCommand? selectedCommand;
  final Map<String, TextEditingController> commandArgumentControllers;
  final Map<String, FocusNode> commandArgumentFocusNodes;
  final VoidCallback onCancelSelectedCommand;
  final VoidCallback onSendMessage;

  final ValueNotifier<bool> showAttachmentPanel;
  final VoidCallback onPickFile;
  final Future<bool> Function(int fileId) onSendFileById;

  final bool commentsMode;
  final String chatType;
  final ChatChromeStyle chrome;
  final bool chromeVignette;
  final BackdropKey? pillBackdrop;
  final BackdropKey? barBackdrop;
  final ValueListenable<CachedMessage?> replyTo;
  final ValueListenable<List<CachedMessage>> forwardMessages;
  final int myId;
  final ValueListenable<bool> hasText;
  final ValueListenable<UploadStatus> uploadStatus;
  final RichMessageController messageController;
  final FocusNode messageFocusNode;
  final VoiceRecordController voiceRec;
  final VideoNoteController note;
  final VoidCallback onToggleStickerPanel;
  final VoidCallback onScheduleMessage;
  final VoidCallback onOpenAttach;
  final VoidCallback onOpenAttachScheduled;
  final Future<void> Function(FileHistoryEntry entry) onSendHistory;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelForward;
  final bool crossChatReplySupported;
  final Future<void> Function() onPickReplyChat;
  final String Function(int ms) formatElapsed;
  final Widget Function(
    RichMessageController controller,
    BuildContext context,
    EditableTextState editableState, {
    List<ContextMenuButtonItem> extraItems,
  })
  formatContextMenu;
  final List<ContextMenuButtonItem> Function(
    BuildContext context,
    EditableTextState editableState,
  )
  pasteMenuItems;
  final Future<bool> Function()? onPasteMedia;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final bool channelSubscribed;
  final bool channelSubscribing;
  final VoidCallback onSubscribe;

  final void Function(StickerItem sticker) onStickerTap;
  final void Function(Animoji animoji) onEmojiTap;

  final ValueListenable<Set<String>> selectedIds;
  final VoidCallback onReplySelected;
  final VoidCallback onForwardSelected;
  final bool forwardDisabled;

  final bool composerFrosted;

  const ComposerArea({
    super.key,
    required this.selectionAnim,
    required this.searchAnim,
    required this.attachAnim,
    required this.stickers,
    required this.selectedCommand,
    required this.commandArgumentControllers,
    required this.commandArgumentFocusNodes,
    required this.onCancelSelectedCommand,
    required this.onSendMessage,
    required this.showAttachmentPanel,
    required this.onPickFile,
    required this.onSendFileById,
    required this.commentsMode,
    required this.chatType,
    required this.chrome,
    required this.chromeVignette,
    required this.pillBackdrop,
    required this.barBackdrop,
    required this.replyTo,
    required this.forwardMessages,
    required this.myId,
    required this.hasText,
    required this.uploadStatus,
    required this.messageController,
    required this.messageFocusNode,
    required this.voiceRec,
    required this.note,
    required this.onToggleStickerPanel,
    required this.onScheduleMessage,
    required this.onOpenAttach,
    required this.onOpenAttachScheduled,
    required this.onSendHistory,
    required this.onCancelReply,
    required this.onCancelForward,
    required this.crossChatReplySupported,
    required this.onPickReplyChat,
    required this.formatElapsed,
    required this.formatContextMenu,
    required this.pasteMenuItems,
    required this.onPasteMedia,
    required this.isMuted,
    required this.onToggleMute,
    required this.channelSubscribed,
    required this.channelSubscribing,
    required this.onSubscribe,
    required this.onStickerTap,
    required this.onEmojiTap,
    required this.selectedIds,
    required this.onReplySelected,
    required this.onForwardSelected,
    required this.forwardDisabled,
    required this.composerFrosted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: selectionAnim,
          builder: (context, child) {
            final t = Curves.easeOut.transform(
              selectionAnim.value.clamp(0.0, 1.0),
            );
            if (t == 0) return child!;
            if (t == 1) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1 - t,
                child: Transform.translate(
                  offset: Offset(0, 48 * t),
                  child: Opacity(opacity: 1 - t, child: child),
                ),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedCommand != null)
                CommandArgumentsForm(
                  key: ValueKey(selectedCommand!.name),
                  command: selectedCommand!,
                  controllers: commandArgumentControllers,
                  focusNodes: commandArgumentFocusNodes,
                  onCancel: onCancelSelectedCommand,
                  onSubmit: onSendMessage,
                ),
              AnimatedBuilder(
                animation: attachAnim,
                builder: (context, _) {
                  if (attachAnim.value == 0) {
                    return const SizedBox.shrink();
                  }
                  final curve = attachAnim.status == AnimationStatus.reverse
                      ? Curves.easeIn
                      : Curves.easeOut;
                  final t = curve.transform(attachAnim.value);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        heightFactor: t,
                        child: Opacity(
                          opacity: t,
                          child: AttachmentPanel(
                            onClose: () => showAttachmentPanel.value = false,
                            onPickFile: onPickFile,
                            onSendById: onSendFileById,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: stickers.anim,
                builder: (context, _) => ComposerInputBar(
                  bottomSafe: stickers.anim.value == 0,
                  chatType: commentsMode ? 'CHAT' : chatType,
                  chrome: chrome,
                  vignette: chromeVignette,
                  style: AppComposerStyle.current.value,
                  background: AppComposerBackground.current.value,
                  backdropKey: pillBackdrop,
                  attachAnim: attachAnim,
                  replyTo: replyTo,
                  forwardMessages: forwardMessages,
                  myId: myId,
                  hasText: hasText,
                  uploadStatus: uploadStatus,
                  messageController: messageController,
                  messageFocusNode: messageFocusNode,
                  voiceRec: voiceRec,
                  note: note,
                  onToggleStickerPanel: onToggleStickerPanel,
                  onSendText: onSendMessage,
                  onScheduleMessage: onScheduleMessage,
                  onOpenAttach: onOpenAttach,
                  onOpenAttachScheduled: onOpenAttachScheduled,
                  onSendHistory: onSendHistory,
                  onCancelReply: onCancelReply,
                  onCancelForward: onCancelForward,
                  onPickReplyChat: commentsMode || !crossChatReplySupported
                      ? null
                      : () => unawaited(onPickReplyChat()),
                  formatElapsed: formatElapsed,
                  contextMenuBuilder: (ctx, state) => formatContextMenu(
                    messageController,
                    ctx,
                    state,
                    extraItems: pasteMenuItems(ctx, state),
                  ),
                  onPasteMedia: ClipboardMedia.supported
                      ? onPasteMedia
                      : null,
                  isMuted: isMuted,
                  onToggleMute: onToggleMute,
                  channelSubscribed: channelSubscribed,
                  channelSubscribing: channelSubscribing,
                  onSubscribe: onSubscribe,
                  showStickerButton: !commentsMode && selectedCommand == null,
                  showAttachButton: !commentsMode && selectedCommand == null,
                  forceSend: commentsMode || selectedCommand != null,
                  readOnly: selectedCommand != null,
                  hintText: selectedCommand != null
                      ? 'Заполните аргументы команды'
                      : commentsMode
                      ? 'Комментарий'
                      : 'Message',
                ),
              ),
              StickerPanelView(
                stickers: stickers,
                onStickerTap: onStickerTap,
                onEmojiTap: onEmojiTap,
              ),
            ],
          ),
        ),
        AnimatedBuilder(
          animation: selectionAnim,
          builder: (context, child) {
            final t = Curves.easeOut.transform(
              selectionAnim.value.clamp(0.0, 1.0),
            );
            if (t == 0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: t,
                child: Opacity(opacity: t, child: child),
              ),
            );
          },
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: selectedIds,
            builder: (context, selected, _) => SelectionBottomBar(
              cs: cs,
              selected: selected,
              onReply: onReplySelected,
              onForward: onForwardSelected,
              allowForward: !forwardDisabled,
            ),
          ),
        ),
      ],
    );
    Widget wrapChrome(Widget child) {
      if (composerFrosted) {
        if (ComposerChrome.isGlossy(AppComposerStyle.current.value)) {
          return child;
        }
        return FrostedPanel(
          sigma: AppFrost.sigma,
          tint: AppFrost.glassTint(cs),
          border: Border(top: AppFrost.hairline(cs)),
          backdropKey: barBackdrop,
          child: child,
        );
      }
      if (chrome != ChatChromeStyle.blur) return child;
      return FrostedPanel(
        tint: AppFrost.blurPanelTint(cs),
        border: Border(top: AppFrost.hairline(cs)),
        backdropKey: barBackdrop,
        child: child,
      );
    }

    final base = wrapChrome(content);
    return AnimatedBuilder(
      animation: searchAnim,
      builder: (context, _) {
        final s = Curves.easeOut.transform(searchAnim.value.clamp(0.0, 1.0));
        if (s == 0) return base;
        if (s >= 1) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 1 - s,
            child: Opacity(
              opacity: 1 - s,
              child: IgnorePointer(child: base),
            ),
          ),
        );
      },
    );
  }
}
