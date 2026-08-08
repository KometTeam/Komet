import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/media_playback.dart';
import '../../core/utils/haptics.dart';

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

class _DraggableNote extends StatefulWidget {
  const _DraggableNote({required this.track});

  final VideoNoteTrack track;

  @override
  State<_DraggableNote> createState() => _DraggableNoteState();
}

class _DraggableNoteState extends State<_DraggableNote> {
  static const double _size = 96;
  static const double _edge = 12;

  static Offset? _saved;

  final ValueNotifier<Offset?> _offset = ValueNotifier(null);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Offset _clamp(Offset value, Size bounds, EdgeInsets safe) {
    final minX = _edge;
    final maxX = math.max(minX, bounds.width - _size - _edge);
    final minY = safe.top + _edge;
    final maxY = math.max(minY, bounds.height - _size - safe.bottom - _edge);
    return Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));
  }

  Offset _initial(Size bounds, EdgeInsets safe) => Offset(
    bounds.width - _size - _edge,
    bounds.height - _size - safe.bottom - 96,
  );

  void _toggle() {
    Haptics.tap();
    final controller = widget.track.controller;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _drag(Offset delta, Size bounds, EdgeInsets safe) {
    final current = _clamp(
      _offset.value ?? _saved ?? _initial(bounds, safe),
      bounds,
      safe,
    );
    final next = _clamp(current + delta, bounds, safe);
    _offset.value = next;
    _saved = next;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = constraints.biggest;
        final safe = MediaQuery.paddingOf(context);
        return ValueListenableBuilder<Offset?>(
          valueListenable: _offset,
          child: RepaintBoundary(
            child: GestureDetector(
              onTap: _toggle,
              onPanUpdate: (details) => _drag(details.delta, bounds, safe),
              child: _NoteCircle(track: widget.track, size: _size),
            ),
          ),
          builder: (context, offset, child) {
            final position = _clamp(
              offset ?? _saved ?? _initial(bounds, safe),
              bounds,
              safe,
            );
            return Stack(
              children: [
                Positioned(left: position.dx, top: position.dy, child: child!),
              ],
            );
          },
        );
      },
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
