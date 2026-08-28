import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../backend/modules/messages.dart';
import '../../core/media/audio_file_track.dart';
import '../../core/media/audio_playback_controller.dart';
import '../../core/media/media_playback.dart';
import '../../core/utils/format.dart';
import '../../core/utils/haptics.dart';
import '../../l10n/app_localizations.dart';
import 'max_link_nav.dart';

class MediaPlaybackPill extends StatelessWidget {
  const MediaPlaybackPill({
    super.key,
    this.borderRadius,
    this.margin = EdgeInsets.zero,
  });

  final BorderRadius? borderRadius;
  final EdgeInsets margin;

  static const double height = 30;

  @override
  Widget build(BuildContext context) {
    final playback = MediaPlayback.instance;
    return ValueListenableBuilder<PlaybackKind?>(
      valueListenable: playback.primary,
      builder: (context, kind, _) {
        switch (kind) {
          case null:
            return const SizedBox.shrink();
          case PlaybackKind.voice:
            return ValueListenableBuilder<VoiceTrack?>(
              valueListenable: playback.voice,
              builder: (context, track, _) => track == null
                  ? const SizedBox.shrink()
                  : _VoicePill(
                      track: track,
                      borderRadius: borderRadius,
                      margin: margin,
                    ),
            );
          case PlaybackKind.videoNote:
            return ValueListenableBuilder<VideoNoteTrack?>(
              valueListenable: playback.videoNote,
              builder: (context, track, _) => track == null
                  ? const SizedBox.shrink()
                  : _VideoNotePill(
                      track: track,
                      borderRadius: borderRadius,
                      margin: margin,
                    ),
            );
          case PlaybackKind.audioFile:
            return ValueListenableBuilder<AudioFileTrack?>(
              valueListenable: playback.audioFile,
              builder: (context, track, _) => track == null
                  ? const SizedBox.shrink()
                  : _AudioFilePill(
                      track: track,
                      borderRadius: borderRadius,
                      margin: margin,
                    ),
            );
        }
      },
    );
  }
}

class _AudioFilePill extends StatelessWidget {
  const _AudioFilePill({
    required this.track,
    required this.borderRadius,
    required this.margin,
  });

  final AudioFileTrack track;
  final BorderRadius? borderRadius;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final audio = AudioPlaybackController.instance;
    final source = track.sourceName.trim();
    return _PillSurface(
      borderRadius: borderRadius,
      margin: margin,
      tick: Listenable.merge([
        audio.playing,
        audio.position,
        audio.duration,
        audio.processingState,
      ]),
      isPlaying: () => audio.playing.value,
      progress: () {
        final total = audio.duration.value.inMilliseconds;
        return total > 0
            ? (audio.position.value.inMilliseconds / total).clamp(0.0, 1.0)
            : 0.0;
      },
      label: source.isEmpty ? track.name : '${track.name} · $source',
      onToggle: audio.toggle,
      onClose: MediaPlayback.instance.closeAudioFile,
      onOpen: () {
        final chatId = track.chatId;
        final messageId = track.messageId;
        final messageTime = track.messageTime;
        if (chatId == null || messageId == null || messageTime == null) return;
        openChatAtMessage(
          context,
          chatId,
          messageId: messageId,
          messageTime: messageTime,
        );
      },
    );
  }
}

class _VoicePill extends StatelessWidget {
  const _VoicePill({
    required this.track,
    required this.borderRadius,
    required this.margin,
  });

  final VoiceTrack track;
  final BorderRadius? borderRadius;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final playback = MediaPlayback.instance;
    return ValueListenableBuilder<double>(
      valueListenable: playback.voiceSpeed,
      builder: (context, speed, _) {
        return _PillSurface(
          borderRadius: borderRadius,
          margin: margin,
          tick: Listenable.merge([
            track.audio.playing,
            track.audio.position,
            track.audio.duration,
          ]),
          isPlaying: () => track.audio.playing.value,
          progress: () {
            final total = track.audio.duration.value;
            return total > 0
                ? (track.audio.position.value / total).clamp(0.0, 1.0)
                : 0.0;
          },
          speed: speed,
          senderId: track.senderId,
          isMe: track.isMe,
          time: track.time,
          label: null,
          onToggle: track.audio.toggle,
          onSpeed: playback.cycleVoiceSpeed,
          onClose: playback.closeVoice,
          onOpen: () => openChatAtMessage(
            context,
            track.chatId,
            messageId: track.messageId,
            messageTime: track.time,
          ),
        );
      },
    );
  }
}

class _VideoNotePill extends StatelessWidget {
  const _VideoNotePill({
    required this.track,
    required this.borderRadius,
    required this.margin,
  });

  final VideoNoteTrack track;
  final BorderRadius? borderRadius;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final playback = MediaPlayback.instance;
    return ValueListenableBuilder<double>(
      valueListenable: playback.videoNoteSpeed,
      builder: (context, speed, _) {
        return _PillSurface(
          borderRadius: borderRadius,
          margin: margin,
          tick: track.controller,
          isPlaying: () => track.controller.value.isPlaying,
          progress: () {
            final value = track.controller.value;
            final total = value.duration.inMilliseconds;
            return total > 0
                ? (value.position.inMilliseconds / total).clamp(0.0, 1.0)
                : 0.0;
          },
          speed: speed,
          senderId: track.senderId,
          isMe: track.isMe,
          time: track.time,
          label: null,
          onToggle: () => track.controller.value.isPlaying
              ? track.controller.pause()
              : track.controller.play(),
          onSpeed: playback.cycleVideoNoteSpeed,
          onClose: playback.closeVideoNote,
          onOpen: () => openChatAtMessage(
            context,
            track.chatId,
            messageId: track.messageId,
            messageTime: track.time,
          ),
        );
      },
    );
  }
}

class _PillSurface extends StatelessWidget {
  const _PillSurface({
    required this.borderRadius,
    required this.margin,
    required this.tick,
    required this.isPlaying,
    required this.progress,
    this.speed,
    this.senderId,
    this.isMe,
    this.time,
    required this.label,
    required this.onToggle,
    this.onSpeed,
    required this.onClose,
    required this.onOpen,
  });

  final BorderRadius? borderRadius;
  final EdgeInsets margin;
  final Listenable tick;
  final bool Function() isPlaying;
  final double Function() progress;
  final double? speed;
  final int? senderId;
  final bool? isMe;
  final int? time;
  final String? label;
  final VoidCallback onToggle;
  final VoidCallback? onSpeed;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  String _speedLabel() {
    final value = speed ?? 1;
    final rounded = value.round();
    final text = value == rounded ? '$rounded' : '$value';
    return '${text}X';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final radius =
        borderRadius ?? BorderRadius.circular(MediaPlaybackPill.height / 2);
    final author = isMe == true
        ? l10n.playbackPillYou
        : (ContactCache.get(senderId ?? 0) ?? '${senderId ?? ''}');
    final clock = time == null
        ? ''
        : formatClock(DateTime.fromMillisecondsSinceEpoch(time!));

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: cs.surfaceContainerHigh,
          child: InkWell(
            onTap: onOpen,
            child: SizedBox(
              height: MediaPlaybackPill.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        AnimatedBuilder(
                          animation: tick,
                          builder: (context, _) => _IconTap(
                            icon: isPlaying()
                                ? Symbols.pause
                                : Symbols.play_arrow,
                            color: cs.primary,
                            size: 19,
                            onTap: onToggle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            label ?? '$author ${l10n.playbackPillAt} $clock',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (onSpeed != null)
                          _SpeedChip(label: _speedLabel(), onTap: onSpeed!),
                        _IconTap(
                          icon: Symbols.close,
                          color: cs.onSurfaceVariant,
                          size: 17,
                          onTap: onClose,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: tick,
                      builder: (context, child) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress(),
                        child: child,
                      ),
                      child: Container(height: 2, color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        child: Icon(icon, color: color, size: size, fill: 1),
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: () {
        Haptics.selection();
        onTap();
      },
      radius: 22,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
