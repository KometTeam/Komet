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
import 'package:komet/frontend/widgets/glossy_pill.dart';
import 'package:komet/frontend/widgets/liquid_glass.dart';
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
    required this.formatElapsed,
    required this.contextMenuBuilder,
    required this.isMuted,
    required this.onToggleMute,
  });

  final String chatType;
  final ChatChromeStyle chrome;
  final ComposerStyle style;
  final ComposerBackground background;
  final BackdropKey? backdropKey;
  final Animation<double> attachAnim;
  final ValueListenable<CachedMessage?> replyTo;
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
  final String Function(int ms) formatElapsed;
  final Widget Function(BuildContext, EditableTextState) contextMenuBuilder;
  final bool isMuted;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mutedIcon = cs.onSurfaceVariant.withValues(alpha: 0.85);

    if (chatType == "CHANNEL") {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _replyPreview(cs),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    constraints: const BoxConstraints(
                      minHeight: 54,
                      maxHeight: 180,
                    ),
                    child: _fieldSurface(
                      cs,
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
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
                                  Expanded(
                                    child: Focus(
                                      onKeyEvent: (node, event) {
                                        if (event is KeyDownEvent &&
                                            event.logicalKey ==
                                                LogicalKeyboardKey.enter &&
                                            !HardwareKeyboard
                                                .instance
                                                .isShiftPressed) {
                                          if (hasText.value) onSendText();
                                          return KeyEventResult.handled;
                                        }
                                        return KeyEventResult.ignored;
                                      },
                                      child: TextField(
                                        controller: messageController,
                                        focusNode: messageFocusNode,
                                        style: TextStyle(
                                          color: cs.onSurface,
                                          fontSize: 16,
                                        ),
                                        maxLines: null,
                                        keyboardType: TextInputType.multiline,
                                        textAlignVertical:
                                            TextAlignVertical.center,
                                        contextMenuBuilder: contextMenuBuilder,
                                        decoration: InputDecoration(
                                          hintText: 'Message',
                                          hintStyle: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 16,
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  _AttachButton(
                                    hasText: hasText,
                                    onOpen: onOpenAttach,
                                    onLongOpen: onOpenAttachScheduled,
                                    uploadStatus: uploadStatus,
                                    mutedIcon: mutedIcon,
                                    cs: cs,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SizedBox(
                              height: 54,
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
                            child: ValueListenableBuilder<bool>(
                              valueListenable: voiceRec.isRecording,
                              builder: (context, recording, _) => IgnorePointer(
                                ignoring: !recording,
                                child: AnimatedSlide(
                                  offset: recording
                                      ? Offset.zero
                                      : const Offset(0.06, 0),
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  child: AnimatedOpacity(
                                    opacity: recording ? 1 : 0,
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    child: _voiceRecordingIndicator(cs),
                                  ),
                                ),
                              ),
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
                      const SizedBox(width: 8),
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
                                builder: (context, locked, _) =>
                                    ValueListenableBuilder<bool>(
                                      valueListenable: voiceRec.isRecording,
                                      builder: (context, recording, _) =>
                                          ValueListenableBuilder<bool>(
                                            valueListenable: note.videoNoteMode,
                                            builder: (context, videoMode, _) {
                                              final sendMode =
                                                  hasText || locked;
                                              final pill = _actionSurface(
                                                color: _flat
                                                    ? Colors.transparent
                                                    : sendMode
                                                    ? cs.primary
                                                    : recording
                                                    ? cs.error
                                                    : _frost
                                                    ? AppFrost.inputTint(cs)
                                                    : cs.surfaceContainerHighest,
                                                onTap: hasText
                                                    ? onSendText
                                                    : locked
                                                    ? () => voiceRec.stop(
                                                        cancel: false,
                                                      )
                                                    : null,
                                                onLongPress: hasText
                                                    ? onScheduleMessage
                                                    : null,
                                                child: SizedBox(
                                                  width: 54,
                                                  height: 54,
                                                  child: Center(
                                                    child: Icon(
                                                      sendMode
                                                          ? Symbols.send
                                                          : videoMode
                                                          ? Symbols.videocam
                                                          : Symbols.mic,
                                                      color: _flat
                                                          ? (sendMode
                                                                ? cs.primary
                                                                : recording
                                                                ? cs.error
                                                                : cs.onSurfaceVariant)
                                                          : sendMode
                                                          ? cs.onPrimary
                                                          : recording
                                                          ? cs.onError
                                                          : cs.onSurface,
                                                      size: 24,
                                                      weight: 400,
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
                                              return GestureDetector(
                                                onTap: sendMode
                                                    ? null
                                                    : note.toggleMode,
                                                onLongPressStart: sendMode
                                                    ? null
                                                    : (_) => videoMode
                                                          ? note.start()
                                                          : voiceRec.start(),
                                                onLongPressMoveUpdate: sendMode
                                                    ? null
                                                    : (d) => videoMode
                                                          ? note.handleDrag(
                                                              d.offsetFromOrigin,
                                                            )
                                                          : voiceRec.handleDrag(
                                                              d.offsetFromOrigin,
                                                            ),
                                                onLongPressEnd: sendMode
                                                    ? null
                                                    : (_) => videoMode
                                                          ? note.handleEnd()
                                                          : voiceRec
                                                                .handleEnd(),
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

  bool get _flat => style == ComposerStyle.materialYou;

  bool get _frost => ComposerMaterial.isFrost(background);

  bool get _liquid => ComposerMaterial.isLiquid(background);

  bool get _translucent => _frost || _liquid;

  Widget _barSurface(ColorScheme cs, Widget child) {
    if (!_flat || _translucent) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: AppFrost.hairline(cs)),
      ),
      child: child,
    );
  }

  Widget _fieldSurface(ColorScheme cs, Widget child) {
    if (_flat) return child;
    return GlossyPill(
      color: _translucent
          ? AppFrost.inputTint(cs)
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
    if (_flat) {
      return Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: onTap == null && onLongPress == null
            ? child
            : InkWell(onTap: onTap, onLongPress: onLongPress, child: child),
      );
    }
    return GlossyPill(
      color: color,
      blurSigma: _frost ? AppFrost.sigma : null,
      liquid: _liquid,
      backdropKey: backdropKey,
      borderRadius: BorderRadius.circular(27),
      onTap: onTap,
      onLongPress: onLongPress,
      depth: 8,
      child: child,
    );
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
        final row = Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
          child: Row(
            children: [
              Icon(Symbols.reply, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Container(width: 2, height: 34, color: cs.primary),
              const SizedBox(width: 10),
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
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
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
        if (_flat && _translucent) return row;
        if (!_translucent && chrome != ChatChromeStyle.transparent) return row;
        return GlassSurface(
          liquid: _liquid,
          frostTint: AppFrost.panelTint(cs),
          border: Border(top: AppFrost.hairline(cs)),
          backdropKey: backdropKey,
          child: row,
        );
      },
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
        if (a <= 0.001) return pill;
        return ValueListenableBuilder<double>(
          valueListenable: voiceRec.amplitude,
          builder: (context, amp, _) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: amp),
            duration: const Duration(milliseconds: 110),
            builder: (context, v, _) {
              final glow = a * (88.0 + v * 76.0);
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 27 - glow / 2,
                    top: 27 - glow / 2,
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
                  _voiceLockChip(cs),
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

  Widget _voiceLockChip(ColorScheme cs) {
    return Positioned(
      bottom: 62,
      child: ValueListenableBuilder<double>(
        valueListenable: voiceRec.lockDrag,
        builder: (context, lock, _) => Opacity(
          opacity: (0.5 + lock * 0.5).clamp(0.0, 1.0),
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

  Widget _voiceRecordingIndicator(ColorScheme cs) {
    return Container(
      color: Color.alphaBlend(
        cs.surfaceContainerHighest.withValues(alpha: 0.92),
        cs.surface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
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
            valueListenable: voiceRec.elapsedMs,
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
              valueListenable: voiceRec.cancelDrag,
              builder: (context, drag, _) {
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
            valueListenable: voiceRec.locked,
            builder: (context, locked, _) => locked
                ? GestureDetector(
                    onTap: () => voiceRec.stop(cancel: true),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Symbols.delete, size: 22, color: cs.error),
                    ),
                  )
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

  const _AttachButton({
    required this.hasText,
    required this.onOpen,
    required this.onLongOpen,
    required this.uploadStatus,
    required this.mutedIcon,
    required this.cs,
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
          width: isText ? 0 : 36,
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
                      padding: const EdgeInsets.only(left: 12),
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
