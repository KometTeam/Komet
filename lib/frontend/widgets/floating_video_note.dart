import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/media_playback.dart';
import '../../core/utils/haptics.dart';
import 'draggable_floating_layer.dart';

class FloatingVideoNoteLayer extends StatelessWidget {
  const FloatingVideoNoteLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = MediaPlayback.instance;
    return ValueListenableBuilder<VideoNoteTrack?>(
      valueListenable: playback.videoNote,
      builder: (context, track, _) {
        if (track == null) return const SizedBox.shrink();
        return ValueListenableBuilder<int?>(
          valueListenable: playback.visibleChatId,
          builder: (context, chatId, _) => chatId == track.chatId
              ? const SizedBox.shrink()
              : _DraggableNote(track: track),
        );
      },
    );
  }
}

class _DraggableNote extends StatelessWidget {
  const _DraggableNote({required this.track});

  final VideoNoteTrack track;

  static const double _size = 96;

  void _toggle() {
    Haptics.tap();
    final controller = track.controller;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableFloatingLayer(
      storageKey: 'video_note',
      size: const Size(_size, _size),
      onTap: _toggle,
      child: _NoteCircle(track: track, size: _size),
    );
  }
}

class _NoteCircle extends StatelessWidget {
  const _NoteCircle({required this.track, required this.size});

  final VideoNoteTrack track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final frame = track.controller.value.size;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: ColoredBox(
                  color: cs.surfaceContainerHighest,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: frame.width <= 0 ? size : frame.width,
                      height: frame.height <= 0 ? size : frame.height,
                      child: VideoPlayer(track.controller),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: track.controller,
                builder: (context, value, _) {
                  final total = value.duration.inMilliseconds;
                  return CustomPaint(
                    painter: _RingPainter(
                      progress: total > 0
                          ? (value.position.inMilliseconds / total).clamp(
                              0.0,
                              1.0,
                            )
                          : 0.0,
                      color: cs.onSurface,
                      track: cs.onSurface.withValues(alpha: 0.25),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  static const double _stroke = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = rect.deflate(_stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = track;
    canvas.drawArc(circle, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(circle, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
