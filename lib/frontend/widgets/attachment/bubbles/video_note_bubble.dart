import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';
import 'package:komet/main.dart';

import '../../../../core/media/video_note_preloader.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/logger.dart';
import '../../../../models/attachment.dart';
import '../../small_spinner.dart';

class VideoNoteBubble extends StatefulWidget {
  final VideoAttachment attachment;
  final String messageId;
  final int chatId;
  final ColorScheme cs;
  final Color textColor;
  final Widget meta;

  const VideoNoteBubble({
    super.key,
    required this.attachment,
    required this.messageId,
    required this.chatId,
    required this.cs,
    required this.textColor,
    required this.meta,
  });

  @override
  State<VideoNoteBubble> createState() => _VideoNoteBubbleState();
}

class _VideoNoteBubbleState extends State<VideoNoteBubble>
    with SingleTickerProviderStateMixin {
  static const double _baseSize = 210;
  static const double _expandedScale = 1.7;
  static const Duration _expandDuration = Duration(milliseconds: 280);
  static const Duration _swapDuration = Duration(milliseconds: 220);

  static _VideoNoteBubbleState? _playingNote;

  late final AnimationController _expand;
  final ValueNotifier<double> _ringProgress = ValueNotifier(0);
  Uint8List? _preview;
  VideoPlayerController? _controller;
  Future<void>? _initializing;
  Duration? _pendingSeek;
  double? _lastAngle;
  bool _playing = false;
  bool _loading = false;
  bool _error = false;
  bool _scrubbing = false;
  bool _seekInFlight = false;
  bool _resumeAfterScrub = false;

  int? get _videoId => widget.attachment.videoId;
  String get _cacheName => 'videonote_$_videoId.mp4';
  int get _attachmentDurationMs => widget.attachment.duration ?? 0;

  bool get _ready {
    final controller = _controller;
    return controller != null && controller.value.isInitialized;
  }

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(vsync: this, duration: _expandDuration);
    _preview = _previewBytes(widget.attachment.previewData);
    if (VideoNotePreloader.autoLoads(widget.attachment.duration)) _preload();
  }

  @override
  void didUpdateWidget(VideoNoteBubble old) {
    super.didUpdateWidget(old);
    if (old.attachment.previewData != widget.attachment.previewData) {
      _preview = _previewBytes(widget.attachment.previewData);
    }
  }

  @override
  void dispose() {
    if (_playingNote == this) _playingNote = null;
    _PreviewPool.unregister(this);
    _expand.dispose();
    _ringProgress.dispose();
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final value = controller.value;

    if (!_scrubbing) {
      final total = value.duration.inMilliseconds;
      _ringProgress.value = total > 0
          ? (value.position.inMilliseconds / total).clamp(0.0, 1.0)
          : 0.0;
    }
    if (value.isPlaying != _playing) {
      setState(() => _playing = value.isPlaying);
    }
  }

  static Uint8List? _previewBytes(String? data) {
    if (data == null) return null;
    const marker = 'base64,';
    final idx = data.indexOf(marker);
    if (idx < 0) return null;
    try {
      return base64Decode(data.substring(idx + marker.length));
    } catch (_) {
      return null;
    }
  }

  Future<void> _preload() async {
    final file = await _fetch(priority: false);
    if (file == null || !mounted) return;
    await _ensureController(file);
  }

  Future<File?> _fetch({required bool priority}) {
    final videoId = _videoId;
    final token = widget.attachment.videoToken;
    if (videoId == null || token == null) return Future.value(null);
    return VideoNotePreloader.load(
      _cacheName,
      () => messagesModule.getVideoUrl(
        messageId: widget.messageId,
        chatId: widget.chatId,
        token: token,
        videoId: videoId,
      ),
      priority: priority,
      cancelled: priority ? null : () => !mounted,
    );
  }

  Future<VideoPlayerController?> _ensureController(File file) async {
    if (_controller != null) return _controller;
    final running = _initializing;
    if (running != null) {
      await running;
      return _controller;
    }

    final controller = VideoPlayerController.file(file);
    final future = controller.initialize();
    _initializing = future;
    try {
      await future;
    } catch (e) {
      logger.w('VideoNoteBubble: инициализация не удалась: $e');
      await controller.dispose();
      _initializing = null;
      return null;
    }
    _initializing = null;

    if (!mounted) {
      await controller.dispose();
      return null;
    }

    _controller = controller;
    await controller.setLooping(true);
    await controller.seekTo(Duration.zero);
    controller.addListener(_onTick);
    _PreviewPool.register(this);
    if (mounted) setState(() {});
    return controller;
  }

  void _releasePreview() {
    final controller = _controller;
    if (controller == null) return;
    _controller = null;
    controller.removeListener(_onTick);
    controller.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (_ready) {
      if (_controller!.value.isPlaying) {
        await _pause();
      } else {
        await _play();
      }
      return;
    }
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = false;
    });
    Haptics.tap();

    final file = await _fetch(priority: true);
    if (!mounted) return;
    final controller = file == null ? null : await _ensureController(file);
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = controller == null;
    });
    if (controller != null) await _play();
  }

  Future<void> _play() async {
    final controller = _controller;
    if (controller == null) return;
    final other = _playingNote;
    if (other != null && other != this) await other._pause();
    _playingNote = this;
    _PreviewPool.pin(this);
    await controller.play();
    _expand.forward();
    if (mounted) setState(() {});
  }

  Future<void> _pause() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.pause();
    if (_playingNote == this) _playingNote = null;
    _PreviewPool.register(this);
    _expand.reverse();
    if (mounted) setState(() {});
  }

  void _seekToProgress(double progress) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final total = controller.value.duration;
    if (total.inMilliseconds <= 0) return;
    _pendingSeek = total * progress.clamp(0.0, 1.0);
    if (!_seekInFlight) _drainSeeks();
  }

  NoteRingGeometry _geometry(double extent) =>
      NoteRingGeometry(extent: extent, knobRadius: _scrubbing ? 9 : 7);

  void _ringTap(Offset local, double extent) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    Haptics.tap();
    _seekToProgress(_geometry(extent).progressAt(local));
  }

  Future<void> _ringDragStart(Offset local, double extent) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    _resumeAfterScrub = controller.value.isPlaying;
    if (_resumeAfterScrub) await controller.pause();
    if (!mounted) return;

    final geometry = _geometry(extent);
    final target = geometry.progressAt(local);
    Haptics.tap();
    _lastAngle = geometry.angleAt(local);
    _ringProgress.value = target;
    setState(() => _scrubbing = true);
    _seekToProgress(target);
  }

  void _ringDragUpdate(Offset local, double extent) {
    final previous = _lastAngle;
    if (!_scrubbing || previous == null) return;
    final geometry = _geometry(extent);
    final angle = geometry.angleAt(local);
    _lastAngle = angle;
    _ringProgress.value = geometry.advance(
      _ringProgress.value,
      NoteRingGeometry.angleDelta(previous, angle),
    );
    _seekToProgress(_ringProgress.value);
  }

  Future<void> _ringDragEnd() async {
    if (!_scrubbing) return;
    setState(() {
      _scrubbing = false;
      _lastAngle = null;
    });
    if (!_resumeAfterScrub) return;
    _resumeAfterScrub = false;
    await _controller?.play();
    if (mounted) setState(() {});
  }

  Future<void> _drainSeeks() async {
    _seekInFlight = true;
    try {
      var target = _pendingSeek;
      while (target != null) {
        _pendingSeek = null;
        await _controller?.seekTo(target);
        target = _pendingSeek;
      }
    } catch (e) {
      logger.w('VideoNoteBubble._drainSeeks: $e');
    } finally {
      _seekInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _baseSize * _expandedScale;
        return AnimatedBuilder(
          animation: _expand,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_expand.value);
            final size = math.min(
              _baseSize * (1 + (_expandedScale - 1) * t),
              maxWidth,
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildCircle(size),
                const SizedBox(height: 6),
                SizedBox(width: size, child: _buildMetaRow()),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCircle(double size) {
    final controller = _controller;
    final ready = _ready;
    final playing = ready && _playing && !_scrubbing;
    final preview = _preview;

    return GestureDetector(
      onTap: _toggle,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: AnimatedSwitcher(
                  duration: _swapDuration,
                  child: ready
                      ? SizedBox.expand(
                          key: const ValueKey('note-video'),
                          child: FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width: controller!.value.size.width,
                              height: controller.value.size.height,
                              child: VideoPlayer(controller),
                            ),
                          ),
                        )
                      : preview != null
                      ? Image.memory(
                          preview,
                          key: const ValueKey('note-preview'),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : Container(
                          key: const ValueKey('note-empty'),
                          color: widget.cs.surfaceContainerHighest,
                        ),
                ),
              ),
            ),
            if (ready) _buildRing(size),
            if (!playing)
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SmallSpinner(size: 36, color: Colors.white),
                      )
                    : Icon(
                        _error ? Symbols.error : Symbols.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRing(double size) {
    return GestureDetector(
      onTapUp: (details) => _ringTap(details.localPosition, size),
      onPanStart: (details) => _ringDragStart(details.localPosition, size),
      onPanUpdate: (details) => _ringDragUpdate(details.localPosition, size),
      onPanEnd: (_) => _ringDragEnd(),
      onPanCancel: _ringDragEnd,
      child: CustomPaint(
        size: Size(size, size),
        painter: _NoteRingPainter(
          geometry: _geometry(size),
          progress: _ringProgress,
          color: widget.cs.primary,
          trackColor: Colors.white30,
        ),
      ),
    );
  }

  Widget _buildMetaRow() {
    final controller = _controller;
    final ready = _ready;
    final totalMs = ready
        ? controller!.value.duration.inMilliseconds
        : _attachmentDurationMs;
    final showPosition = ready && (_playing || _scrubbing);
    final style = TextStyle(
      color: widget.textColor.withValues(alpha: 0.7),
      fontSize: 11,
    );

    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: showPosition
              ? ValueListenableBuilder<double>(
                  valueListenable: _ringProgress,
                  builder: (context, progress, _) => Text(
                    formatSecondsMmSs((progress * totalMs) ~/ 1000),
                    style: style,
                  ),
                )
              : Text(formatSecondsMmSs((totalMs / 1000).round()), style: style),
        ),
        const Spacer(),
        widget.meta,
      ],
    );
  }
}

class NoteRingGeometry {
  const NoteRingGeometry({required this.extent, required this.knobRadius});

  static const double startAngle = -math.pi / 2;
  static const double bandTolerance = 12;
  static const double knobTolerance = 26;
  static const double stroke = 3;

  final double extent;
  final double knobRadius;

  double get radius => extent / 2 - knobRadius - 1;

  Offset get center => Offset(extent / 2, extent / 2);

  Offset knobCenter(double progress) {
    final angle = startAngle + 2 * math.pi * progress.clamp(0.0, 1.0);
    return center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }

  double angleAt(Offset local) {
    final vector = local - center;
    return math.atan2(vector.dy, vector.dx);
  }

  double progressAt(Offset local) {
    var turns = (angleAt(local) - startAngle) / (2 * math.pi) % 1.0;
    if (turns < 0) turns += 1.0;
    return turns;
  }

  static double angleDelta(double from, double to) {
    var delta = to - from;
    while (delta > math.pi) {
      delta -= 2 * math.pi;
    }
    while (delta < -math.pi) {
      delta += 2 * math.pi;
    }
    return delta;
  }

  double advance(double progress, double delta) =>
      (progress + delta / (2 * math.pi)).clamp(0.0, 1.0);

  bool grabs(Offset position, double progress) {
    if ((position - knobCenter(progress)).distance <= knobTolerance) {
      return true;
    }
    return ((position - center).distance - radius).abs() <= bandTolerance;
  }
}

class _NoteRingPainter extends CustomPainter {
  _NoteRingPainter({
    required this.geometry,
    required this.progress,
    required this.color,
    required this.trackColor,
  }) : super(repaint: progress);

  final NoteRingGeometry geometry;
  final ValueListenable<double> progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final value = progress.value;
    final center = geometry.center;
    final radius = geometry.radius;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = NoteRingGeometry.stroke
        ..color = trackColor,
    );

    final sweep = 2 * math.pi * value.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        NoteRingGeometry.startAngle,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = NoteRingGeometry.stroke
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    final knob = geometry.knobCenter(value);
    final knobRadius = geometry.knobRadius;
    canvas.drawCircle(
      knob,
      knobRadius,
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(knob, knobRadius, Paint()..color = Colors.white);
    canvas.drawCircle(knob, knobRadius - 2.5, Paint()..color = color);
  }

  @override
  bool hitTest(Offset position) => geometry.grabs(position, progress.value);

  @override
  bool shouldRepaint(_NoteRingPainter old) =>
      old.geometry.extent != geometry.extent ||
      old.geometry.knobRadius != geometry.knobRadius ||
      old.color != color ||
      old.trackColor != trackColor;
}

class _PreviewPool {
  static const int _maxIdle = 4;
  static final List<_VideoNoteBubbleState> _idle = [];

  static void register(_VideoNoteBubbleState state) {
    _idle
      ..remove(state)
      ..add(state);
    while (_idle.length > _maxIdle) {
      _idle.removeAt(0)._releasePreview();
    }
  }

  static void pin(_VideoNoteBubbleState state) => _idle.remove(state);

  static void unregister(_VideoNoteBubbleState state) => _idle.remove(state);
}
