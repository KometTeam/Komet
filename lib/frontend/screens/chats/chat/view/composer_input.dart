import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/backend/modules/messages.dart';
import 'package:komet/core/config/app_chat_chrome.dart';
import 'package:komet/core/config/app_colors.dart';
import 'package:komet/core/config/app_composer_background.dart';
import 'package:komet/core/config/app_composer_style.dart';
import 'package:komet/core/config/app_frost.dart';
import 'package:komet/frontend/screens/chats/chat/upload_status.dart';
import 'package:komet/frontend/screens/chats/chat/video_note_controller.dart';
import 'package:komet/frontend/screens/chats/chat/voice_record_controller.dart';
import 'package:komet/frontend/widgets/composer_morph_icon.dart';
import 'package:komet/frontend/widgets/glossy_pill.dart';
import 'package:komet/frontend/widgets/liquid_glass.dart';
import 'package:komet/frontend/widgets/paste_media_scope.dart';
import 'package:komet/frontend/widgets/reply_preview.dart';
import 'package:komet/frontend/widgets/rich_message_controller.dart';

class ComposerInputBar extends StatelessWidget {
  const ComposerInputBar({
    super.key,
    required this.chatType,
    required this.chrome,
    required this.style,
    required this.background,
    this.backdropKey,
    required this.attachAnim,
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
    required this.onSendText,
    required this.onScheduleMessage,
    required this.onOpenAttach,
    required this.onOpenAttachScheduled,
    required this.onSendHistory,
    required this.onCancelReply,
    required this.onCancelForward,
    this.onPickReplyChat,
    required this.formatElapsed,
    required this.contextMenuBuilder,
    this.onPasteMedia,
    required this.isMuted,
    required this.onToggleMute,
    this.channelSubscribed = true,
    this.channelSubscribing = false,
    this.onSubscribe,
    this.showStickerButton = true,
    this.showAttachButton = true,
    this.forceSend = false,
    this.readOnly = false,
    this.hintText = 'Message',
    this.bottomSafe = true,
    this.vignette = false,
  });

  final String chatType;
  final ChatChromeStyle chrome;
  final ComposerStyle style;
  final ComposerBackground background;
  final BackdropKey? backdropKey;
  final Animation<double> attachAnim;
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
  final VoidCallback onSendText;
  final VoidCallback onScheduleMessage;
  final VoidCallback onOpenAttach;
  final VoidCallback onOpenAttachScheduled;
  final Future<void> Function(FileHistoryEntry entry) onSendHistory;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelForward;
  final VoidCallback? onPickReplyChat;
  final String Function(int ms) formatElapsed;
  final Widget Function(BuildContext, EditableTextState) contextMenuBuilder;
  final Future<bool> Function()? onPasteMedia;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final bool channelSubscribed;
  final bool channelSubscribing;
  final VoidCallback? onSubscribe;
  final bool showStickerButton;
  final bool showAttachButton;
  final bool forceSend;
  final bool readOnly;
  final String hintText;
  final bool bottomSafe;
  final bool vignette;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CachedMessage>>(
      valueListenable: forwardMessages,
      builder: (context, forwards, _) => _build(context, forwards),
    );
  }

  Widget _build(BuildContext context, List<CachedMessage> forwards) {
    final cs = Theme.of(context).colorScheme;
    final mutedIcon = cs.onSurfaceVariant.withValues(alpha: 0.85);
    final hasForward = forwards.isNotEmpty;

    if (chatType == "CHANNEL" && !hasForward) {
      if (!channelSubscribed) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: GlossyPill(
              onTap: channelSubscribing ? null : onSubscribe,
              color: cs.primary,
              borderRadius: BorderRadius.circular(28),
              padding: const EdgeInsets.symmetric(vertical: 16),
              depth: 8,
              borderSide: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 0.5,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: channelSubscribing
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : Text(
                          'Подписаться',
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      }
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: GlossyPill(
            onTap: onToggleMute,
            color: Color.alphaBlend(
              cs.surfaceContainerHighest.withValues(alpha: 0.92),
              cs.surface,
            ),
            borderRadius: BorderRadius.circular(28),
            padding: const EdgeInsets.symmetric(vertical: 16),
            depth: 8,
            borderSide: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.5),
              width: 0.5,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Center(
                child: Text(
                  isMuted ? 'Включить уведомления' : 'Отключить уведомления',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final bar = SafeArea(
      bottom: bottomSafe,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _messagePreview(cs, forwards),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _barSideInset,
              vertical: _barVerticalInset,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: BoxConstraints(
                      minHeight: _controlSize,
                      maxHeight: 180,
                    ),
                    child: _fieldSurface(
                      cs,
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              voiceRec.isRecording,
                              note.isRecording,
                            ]),
                            builder: (context, child) {
                              final recording =
                                  voiceRec.isRecording.value ||
                                  note.isRecording.value;
                              return IgnorePointer(
                                ignoring: recording,
                                child: AnimatedOpacity(
                                  opacity: recording ? 0 : 1,
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  child: child,
                                ),
                              );
                            },
                            child: AnimatedBuilder(
                              animation: attachAnim,
                              builder: (context, child) {
                                final t = attachAnim.value;
                                return IgnorePointer(
                                  ignoring: t > 0.5,
                                  child: Opacity(
                                    opacity: (1 - t).clamp(0.0, 1.0),
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: _fieldSideInset,
                                  right: _fieldTrailingInset,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (showStickerButton) ...[
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: onToggleStickerPanel,
                                        child: Icon(
                                          Symbols.face,
                                          color: mutedIcon,
                                          size: 24,
                                          weight: 400,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Focus(
                                        onKeyEvent: (node, event) {
                                          if (event is KeyDownEvent &&
                                              event.logicalKey ==
                                                  LogicalKeyboardKey.enter &&
                                              !HardwareKeyboard
                                                  .instance
                                                  .isShiftPressed) {
                                            if (hasText.value ||
                                                hasForward ||
                                                forceSend) {
                                              onSendText();
                                            }
                                            return KeyEventResult.handled;
                                          }
                                          return KeyEventResult.ignored;
                                        },
                                        child: PasteMediaScope(
                                          onPaste: onPasteMedia,
                                          child: TextField(
                                            controller: messageController,
                                            focusNode: messageFocusNode,
                                            readOnly: readOnly,
                                            style: TextStyle(
                                              color: cs.onSurface,
                                              fontSize: 16,
                                            ),
                                            maxLines: null,
                                            keyboardType:
                                                TextInputType.multiline,
                                            textCapitalization:
                                                TextCapitalization.sentences,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            contextMenuBuilder:
                                                contextMenuBuilder,
                                            decoration: InputDecoration(
                                              hintText: hintText,
                                              hintStyle: TextStyle(
                                                color: cs.onSurfaceVariant,
                                                fontSize: 16,
                                              ),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (showAttachButton)
                                      _AttachButton(
                                        hasText: hasText,
                                        onOpen: onOpenAttach,
                                        onLongOpen: onOpenAttachScheduled,
                                        uploadStatus: uploadStatus,
                                        mutedIcon: mutedIcon,
                                        cs: cs,
                                        slot: _attachSlot,
                                        leading: _attachLeading,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SizedBox(
                              height: _controlSize,
                              child: AnimatedBuilder(
                                animation: attachAnim,
                                builder: (context, child) {
                                  final t = attachAnim.value;
                                  return IgnorePointer(
                                    ignoring: t < 0.5,
                                    child: Opacity(
                                      opacity: t.clamp(0.0, 1.0),
                                      child: child,
                                    ),
                                  );
                                },
                                child: _HistoryStrip(
                                  anim: attachAnim,
                                  cs: cs,
                                  onTapEntry: onSendHistory,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: Listenable.merge([
                                voiceRec.isRecording,
                                note.isRecording,
                              ]),
                              builder: (context, _) {
                                final video = note.isRecording.value;
                                final recording =
                                    video || voiceRec.isRecording.value;
                                return IgnorePointer(
                                  ignoring: !recording,
                                  child: AnimatedSlide(
                                    offset: recording
                                        ? Offset.zero
                                        : const Offset(0.06, 0),
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutCubic,
                                    child: AnimatedOpacity(
                                      opacity: recording ? 1 : 0,
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                      child: _recordingIndicator(cs, video),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: attachAnim,
                  builder: (context, child) {
                    final t = attachAnim.value;
                    return ClipRect(
                      clipper: _ButtonClipper(t),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: (1 - t).clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: _actionGap),
                      AnimatedBuilder(
                        animation: attachAnim,
                        builder: (context, child) {
                          final t = attachAnim.value;
                          return Transform.translate(
                            offset: Offset(t * 80, 0),
                            child: Opacity(
                              opacity: (1 - t * 1.5).clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: ValueListenableBuilder<bool>(
                          valueListenable: hasText,
                          builder: (context, hasText, _) =>
                              ValueListenableBuilder<bool>(
                                valueListenable: voiceRec.locked,
                                builder: (context, voiceLocked, _) =>
                                    ValueListenableBuilder<bool>(
                                      valueListenable: voiceRec.isRecording,
                                      builder: (context, voiceRecording, _) =>
                                          AnimatedBuilder(
                                            animation: Listenable.merge([
                                              note.videoNoteMode,
                                              note.isRecording,
                                              note.locked,
                                            ]),
                                            builder: (context, _) {
                                              final videoMode =
                                                  note.videoNoteMode.value;
                                              final noteRecording =
                                                  note.isRecording.value;
                                              final recording =
                                                  voiceRecording ||
                                                  noteRecording;
                                              final locked = noteRecording
                                                  ? note.locked.value
                                                  : voiceLocked;
                                              final sendMode =
                                                  hasText ||
                                                  hasForward ||
                                                  locked ||
                                                  forceSend;
                                              final pill = _actionSurface(
                                                color: _flat
                                                    ? Colors.transparent
                                                    : recording
                                                    ? cs.error
                                                    : _frost
                                                    ? AppFrost.glassTint(cs)
                                                    : cs.surfaceContainerHighest,
                                                onTap:
                                                    (hasText ||
                                                        hasForward ||
                                                        forceSend)
                                                    ? onSendText
                                                    : locked
                                                    ? () => noteRecording
                                                          ? note.stop(
                                                              cancel: false,
                                                            )
                                                          : voiceRec.stop(
                                                              cancel: false,
                                                            )
                                                    : null,
                                                onLongPress:
                                                    (hasText &&
                                                        !forceSend &&
                                                        !hasForward)
                                                    ? onScheduleMessage
                                                    : null,
                                                child: SizedBox(
                                                  width: _controlSize,
                                                  height: _controlSize,
                                                  child: Center(
                                                    child: ComposerMorphIcon(
                                                      action: sendMode
                                                          ? ComposerAction.send
                                                          : videoMode
                                                          ? ComposerAction
                                                                .videocam
                                                          : ComposerAction.mic,
                                                      color: recording
                                                          ? (_flat
                                                                ? cs.error
                                                                : cs.onError)
                                                          : sendMode
                                                          ? cs.primary
                                                          : _flat
                                                          ? cs.onSurfaceVariant
                                                          : cs.onSurface,
                                                    ),
                                                  ),
                                                ),
                                              );
                                              final visual =
                                                  _recordingButtonVisual(
                                                    pill: pill,
                                                    cs: cs,
                                                    active:
                                                        recording && !locked,
                                                  );
                                              final voiceEnabled =
                                                  !sendMode && !forceSend;
                                              return GestureDetector(
                                                onTap: voiceEnabled
                                                    ? note.toggleMode
                                                    : null,
                                                onLongPressStart: voiceEnabled
                                                    ? (_) => videoMode
                                                          ? note.start()
                                                          : voiceRec.start()
                                                    : null,
                                                onLongPressMoveUpdate:
                                                    voiceEnabled
                                                    ? (d) => videoMode
                                                          ? note.handleDrag(
                                                              d.offsetFromOrigin,
                                                            )
                                                          : voiceRec.handleDrag(
                                                              d.offsetFromOrigin,
                                                            )
                                                    : null,
                                                onLongPressEnd: voiceEnabled
                                                    ? (_) => videoMode
                                                          ? note.handleEnd()
                                                          : voiceRec.handleEnd()
                                                    : null,
                                                child: visual,
                                              );
                                            },
                                          ),
                                    ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return _barSurface(cs, bar);
  }

  bool get _flat => !ComposerChrome.isGlossy(style);

  bool get _frost => ComposerMaterial.isFrost(background);

  bool get _liquid => ComposerMaterial.isLiquid(background);

  bool get _translucent => _frost || _liquid;

  double get _controlSize => _flat ? 48 : 54;

  double get _barSideInset => _flat ? 0 : 12;

  double get _barVerticalInset => _flat ? 4 : 8;

  double get _fieldSideInset => _flat ? 12 : 14;

  double get _fieldTrailingInset => _flat ? 0 : 14;

  double get _actionGap => _flat ? 0 : 8;

  double get _attachSlot => _flat ? 48 : 36;

  double get _attachLeading => _flat ? 0 : 12;

  Widget _barSurface(ColorScheme cs, Widget child) {
    if (!_flat || _translucent) return child;
    if (chrome == ChatChromeStyle.blur) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: vignette ? null : Border(top: AppFrost.hairline(cs)),
      ),
      child: child,
    );
  }

  Widget _fieldSurface(ColorScheme cs, Widget child) {
    if (_flat) return child;
    return GlossyPill(
      color: _translucent
          ? AppFrost.glassTint(cs)
          : Color.alphaBlend(
              cs.surfaceContainerHighest.withValues(alpha: 0.92),
              cs.surface,
            ),
      blurSigma: _frost ? AppFrost.sigma : null,
      liquid: _liquid,
      backdropKey: backdropKey,
      borderRadius: BorderRadius.circular(28),
      depth: 8,
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.5),
        width: 0.5,
      ),
      child: child,
    );
  }

  Widget _actionSurface({
    required Color color,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, tinted, _) => _actionSurfaceOf(
        color: tinted ?? color,
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }

  Widget _actionSurfaceOf({
    required Color color,
    required Widget child,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    if (_flat) {
      return Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, onLongPress: onLongPress, child: child),
      );
    }
    return GlossyPill(
      color: color,
      blurSigma: _frost ? AppFrost.sigma : null,
      liquid: _liquid,
      backdropKey: backdropKey,
      borderRadius: BorderRadius.circular(_controlSize / 2),
      onTap: onTap,
      onLongPress: onLongPress,
      keepInkLayer: true,
      depth: 8,
      child: child,
    );
  }

  Widget _replyIconButton(ColorScheme cs) {
    final icon = Icon(Symbols.reply, size: 20, color: cs.primary);
    if (onPickReplyChat == null) return icon;
    return InkWell(
      onTap: onPickReplyChat,
      customBorder: const CircleBorder(),
      child: Padding(padding: const EdgeInsets.all(4), child: icon),
    );
  }

  Widget _messagePreview(ColorScheme cs, List<CachedMessage> forwards) {
    if (forwards.isNotEmpty) return _forwardPreview(cs, forwards);
    return _replyPreview(cs);
  }

  Widget _forwardPreview(ColorScheme cs, List<CachedMessage> messages) {
    final first = messages.first;
    final senderName = ContactCache.get(first.senderId);
    final info = ReplyInfo(
      senderId: first.senderId,
      text: first.text,
      attachments: first.attachments,
    );
    final preview = info.previewText();
    final visual = ReplyPreview.of(
      text: first.text,
      attachments: first.attachments,
    );
    final title = messages.length == 1
        ? first.senderId == myId
              ? 'Пересылка от вас'
              : senderName == null
              ? 'Пересылка сообщения'
              : 'Пересылка от $senderName'
        : 'Пересылка: ${_forwardCount(messages.length)}';
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
      child: Row(
        children: [
          Icon(Symbols.forward, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Container(width: 2, height: 34, color: cs.primary),
          const SizedBox(width: 10),
          _previewThumb(cs, visual),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (preview.isNotEmpty) _previewLine(cs, visual, preview),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.close, size: 20),
            color: cs.onSurfaceVariant,
            onPressed: onCancelForward,
          ),
        ],
      ),
    );
    return _previewSurface(cs, row);
  }

  String _forwardCount(int count) {
    final last = count % 10;
    final lastTwo = count % 100;
    if (last == 1 && lastTwo != 11) return '$count сообщение';
    if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
      return '$count сообщения';
    }
    return '$count сообщений';
  }

  Widget _replyPreview(ColorScheme cs) {
    return ValueListenableBuilder<CachedMessage?>(
      valueListenable: replyTo,
      builder: (context, reply, _) {
        if (reply == null) return const SizedBox.shrink();
        final name = reply.senderId == myId
            ? 'Вы'
            : (ContactCache.get(reply.senderId) ?? 'Сообщение');
        final info = ReplyInfo(
          senderId: reply.senderId,
          text: reply.text,
          attachments: reply.attachments,
        );
        final preview = info.previewText();
        final visual = ReplyPreview.of(
          text: reply.text,
          attachments: reply.attachments,
        );
        final row = Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
          child: Row(
            children: [
              _replyIconButton(cs),
              const SizedBox(width: 10),
              Container(width: 2, height: 34, color: cs.primary),
              const SizedBox(width: 10),
              _previewThumb(cs, visual),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ответ $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (preview.isNotEmpty) _previewLine(cs, visual, preview),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Symbols.close, size: 20),
                color: cs.onSurfaceVariant,
                onPressed: onCancelReply,
              ),
            ],
          ),
        );
        return _previewSurface(cs, row);
      },
    );
  }

  static const double _previewThumbSide = 34;

  Widget _previewThumb(ColorScheme cs, ReplyPreview preview) {
    if (!preview.hasMedia) return const SizedBox.shrink();
    const size = Size(_previewThumbSide, _previewThumbSide);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: preview.thumbnail(size: size, cs: cs, radius: 6),
    );
  }

  Widget _previewLine(ColorScheme cs, ReplyPreview preview, String text) {
    final icon = preview.hasMedia ? null : preview.icon;
    final style = TextStyle(color: cs.onSurfaceVariant, fontSize: 13);
    if (icon == null) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _previewSurface(ColorScheme cs, Widget child) {
    if (_flat && _translucent) return child;
    if (!_translucent && chrome != ChatChromeStyle.transparent) return child;
    return GlassSurface(
      liquid: _liquid,
      frostTint: AppFrost.glassTint(cs),
      border: Border(top: AppFrost.hairline(cs)),
      backdropKey: backdropKey,
      child: child,
    );
  }

  Widget _recordingButtonVisual({
    required Widget pill,
    required ColorScheme cs,
    required bool active,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: active ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, a, _) {
        return ValueListenableBuilder<double>(
          valueListenable: voiceRec.amplitude,
          builder: (context, amp, _) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: a <= 0.001 ? 0.0 : amp),
            duration: const Duration(milliseconds: 110),
            builder: (context, v, _) {
              final glow = a * (88.0 + v * 76.0);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: _controlSize / 2 - glow / 2,
                    top: _controlSize / 2 - glow / 2,
                    child: Container(
                      width: glow,
                      height: glow,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.error.withValues(
                          alpha: a * (0.16 + v * 0.12),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: note.isRecording,
                    builder: (context, video, _) => _lockChip(
                      cs,
                      a,
                      video ? note.lockDrag : voiceRec.lockDrag,
                    ),
                  ),
                  Transform.scale(
                    scale: 1.0 + a * 0.14 + a * v * 0.24,
                    child: pill,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _lockChip(
    ColorScheme cs,
    double reveal,
    ValueListenable<double> lockDrag,
  ) {
    return Positioned(
      bottom: _controlSize + 8,
      child: ValueListenableBuilder<double>(
        valueListenable: lockDrag,
        builder: (context, lock, _) => Opacity(
          opacity: (reveal * (0.5 + lock * 0.5)).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, lock * 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  cs.surfaceContainerHighest.withValues(alpha: 0.96),
                  cs.surface,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.lock,
                    size: 16,
                    color: lock > 0.6 ? cs.primary : cs.onSurfaceVariant,
                  ),
                  Icon(
                    Symbols.keyboard_arrow_up,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recordingIndicator(ColorScheme cs, bool video) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _fieldSideInset),
      child: Row(
        children: [
          if (video)
            _RecordingDot(color: cs.error)
          else
            ValueListenableBuilder<double>(
              valueListenable: voiceRec.amplitude,
              builder: (context, amp, child) => TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: amp),
                duration: const Duration(milliseconds: 120),
                builder: (context, v, child) =>
                    Transform.scale(scale: 1.0 + v * 0.7, child: child),
                child: child,
              ),
              child: _RecordingDot(color: cs.error),
            ),
          const SizedBox(width: 12),
          ValueListenableBuilder<int>(
            valueListenable: video ? note.elapsedMs : voiceRec.elapsedMs,
            builder: (context, ms, _) => Text(
              formatElapsed(ms),
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: video ? note.cancelDrag : voiceRec.cancelDrag,
              builder: (context, drag, _) {
                if (video) {
                  return Opacity(
                    opacity: (0.55 + drag * 0.45).clamp(0.0, 1.0),
                    child: Center(
                      child: Text(
                        '‹ Влево — отмена',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }
                if (drag > 0.01) {
                  return Opacity(
                    opacity: (0.45 + drag * 0.55).clamp(0.0, 1.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Symbols.arrow_back,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Отмена',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox(
                  height: 26,
                  child: ValueListenableBuilder<int>(
                    valueListenable: voiceRec.waveRev,
                    builder: (context, _, _) => CustomPaint(
                      size: Size.infinite,
                      painter: _LiveWavePainter(
                        amps: voiceRec.amps,
                        color: cs.primary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<bool>(
            valueListenable: video ? note.locked : voiceRec.locked,
            builder: (context, locked, _) => locked
                ? GestureDetector(
                    onTap: () => video
                        ? note.stop(cancel: true)
                        : voiceRec.stop(cancel: true),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Symbols.delete, size: 22, color: cs.error),
                    ),
                  )
                : video
                ? const SizedBox.shrink()
                : Text(
                    '‹ влево — отмена',
                    style: TextStyle(color: cs.mutedText, fontSize: 11),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final ValueListenable<bool> hasText;
  final VoidCallback onOpen;
  final VoidCallback onLongOpen;
  final ValueListenable<UploadStatus> uploadStatus;
  final Color mutedIcon;
  final ColorScheme cs;
  final double slot;
  final double leading;

  const _AttachButton({
    required this.hasText,
    required this.onOpen,
    required this.onLongOpen,
    required this.uploadStatus,
    required this.mutedIcon,
    required this.cs,
    required this.slot,
    required this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([hasText, uploadStatus]),
      builder: (context, _) {
        final isText = hasText.value;
        final status = uploadStatus.value;
        final iconColor = status.awaitingResponse
            ? cs.primary
            : (status.active
                  ? cs.onSurfaceVariant.withValues(alpha: 0.5)
                  : mutedIcon);
        final disabled = isText || status.active;
        final onTap = disabled ? null : onOpen;
        final onLongPress = disabled ? null : onLongOpen;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isText ? 0 : slot,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isText ? 0 : 1,
            child: isText
                ? const SizedBox.shrink()
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
                    onLongPress: onLongPress,
                    child: Padding(
                      padding: EdgeInsets.only(left: leading),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (status.active)
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: status.progressValue,
                                color: cs.primary,
                              ),
                            ),
                          Icon(
                            Symbols.attachment,
                            color: iconColor,
                            size: 22,
                            weight: 400,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  final Animation<double> anim;
  final ColorScheme cs;
  final Future<void> Function(FileHistoryEntry entry) onTapEntry;

  const _HistoryStrip({
    required this.anim,
    required this.cs,
    required this.onTapEntry,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<FileHistoryEntry>>(
      valueListenable: FileHistoryCache.notifier,
      builder: (context, history, _) {
        if (history.isEmpty) {
          return Center(
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, _) {
                final v = anim.value.clamp(0.0, 1.0);
                return Opacity(
                  opacity: v,
                  child: Text(
                    'история пуста...',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                );
              },
            ),
          );
        }
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: history.length,
          itemBuilder: (ctx, idx) {
            final e = history[idx];
            final startInterval = (idx * 0.05).clamp(0.0, 0.45);
            return AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                final raw = ((anim.value - startInterval) / 0.45).clamp(
                  0.0,
                  1.0,
                );
                final v = Curves.easeOutCubic.transform(raw);
                return Opacity(
                  opacity: v,
                  child: Transform.translate(
                    offset: Offset(-14 * (1 - v), 0),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 54,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTapEntry(e),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _iconForFilename(e.filename),
                              color: cs.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Text(
                                _labelForEntry(e),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 9,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => FileHistoryCache.remove(e.fileId),
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.5),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            Symbols.close,
                            size: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ButtonClipper extends CustomClipper<Rect> {
  final double t;
  const _ButtonClipper(this.t);

  @override
  Rect getClip(Size size) {
    if (t <= 0.001) {
      return Rect.fromLTRB(-120, -260, size.width + 120, size.height + 40);
    }
    return Rect.fromLTRB(0, 0, size.width, size.height);
  }

  @override
  bool shouldReclip(_ButtonClipper old) => old.t != t;
}

class _RecordingDot extends StatefulWidget {
  final Color color;
  const _RecordingDot({required this.color});

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.25).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

class _LiveWavePainter extends CustomPainter {
  final List<double> amps;
  final Color color;

  const _LiveWavePainter({required this.amps, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const slot = 5.0;
    const barW = 3.0;
    final count = (size.width / slot).floor();
    if (count <= 0 || amps.isEmpty) return;

    final start = amps.length > count ? amps.length - count : 0;
    final visible = amps.sublist(start);
    final center = size.height / 2;
    final paint = Paint()..color = color;
    final offset = size.width - visible.length * slot;

    for (var i = 0; i < visible.length; i++) {
      final h = (visible[i] * size.height).clamp(2.0, size.height);
      final x = offset + i * slot + (slot - barW) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, center - h / 2, barW, h),
          const Radius.circular(barW / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveWavePainter old) => true;
}

String _labelForEntry(FileHistoryEntry e) {
  final n = e.filename;
  if (n == null || n.isEmpty) return e.fileId.toString();
  final lastDot = n.lastIndexOf('.');
  return lastDot > 0 ? n.substring(0, lastDot) : n;
}

IconData _iconForFilename(String? name) {
  if (name == null || !name.contains('.')) return Symbols.description;
  final ext = name.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'bmp':
    case 'heic':
    case 'heif':
      return Symbols.image;
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
    case 'webm':
    case '3gp':
      return Symbols.movie;
    case 'mp3':
    case 'wav':
    case 'ogg':
    case 'flac':
    case 'm4a':
    case 'aac':
      return Symbols.audio_file;
    case 'pdf':
      return Symbols.picture_as_pdf;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return Symbols.folder_zip;
    case 'doc':
    case 'docx':
    case 'txt':
    case 'rtf':
    case 'odt':
    case 'md':
      return Symbols.article;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Symbols.table_chart;
    case 'ppt':
    case 'pptx':
      return Symbols.slideshow;
    case 'dart':
    case 'js':
    case 'ts':
    case 'py':
    case 'java':
    case 'kt':
    case 'swift':
    case 'cpp':
    case 'c':
    case 'h':
    case 'rs':
    case 'go':
    case 'rb':
    case 'php':
    case 'html':
    case 'css':
    case 'json':
    case 'xml':
    case 'yaml':
    case 'yml':
      return Symbols.code;
    default:
      return Symbols.description;
  }
}
