import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../widgets/glossy_pill.dart';

import '../../../../core/config/app_video_note_quality.dart';
import '../../../../core/media/native_video_note_recorder.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/logger.dart';
import '../../../widgets/custom_notification.dart';
import 'voice_record_controller.dart';

class VideoNoteController {
  VideoNoteController({
    required this.contextOf,
    required this.isMounted,
    required this.onRecorded,
    required this.formatElapsed,
    required this.bottomInset,
  });

  final BuildContext Function() contextOf;
  final bool Function() isMounted;
  final Future<void> Function(File file, int durationMs) onRecorded;
  final String Function(int ms) formatElapsed;
  final double Function() bottomInset;

  final NativeVideoNoteRecorder _rec = NativeVideoNoteRecorder();
  final ValueNotifier<bool> _videoNoteMode = ValueNotifier(false);
  final ValueNotifier<int?> _textureId = ValueNotifier(null);
  final ValueNotifier<bool> _camReady = ValueNotifier(false);
  final ValueNotifier<bool> _isRecording = ValueNotifier(false);
  final ValueNotifier<int> _elapsedMs = ValueNotifier(0);
  final ValueNotifier<double> _cancelDrag = ValueNotifier(0);
  final ValueNotifier<bool> _locked = ValueNotifier(false);
  final ValueNotifier<double> _lockDrag = ValueNotifier(0);
  final ValueNotifier<bool> _flashOn = ValueNotifier(false);
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _cancelled = false;
  bool _stopRequested = false;
  bool? _frontOverride;
  bool _switchingCamera = false;

  bool get _front => _frontOverride ?? !AppVideoNoteRearCamera.current.value;

  static const int maxMs = 60000;
  static const double _lockThreshold = 90;

  ValueListenable<bool> get videoNoteMode => _videoNoteMode;
  ValueListenable<bool> get camReady => _camReady;
  ValueListenable<bool> get isRecording => _isRecording;
  ValueListenable<int> get elapsedMs => _elapsedMs;
  ValueListenable<double> get cancelDrag => _cancelDrag;
  ValueListenable<bool> get locked => _locked;
  ValueListenable<double> get lockDrag => _lockDrag;
  ValueListenable<bool> get flashOn => _flashOn;
  ValueListenable<int?> get textureId => _textureId;

  bool get flashAvailable => _rec.hasFlash || _stub;

  bool get cameraControlsAvailable => true;

  Future<void> toggleFlash() async {
    final next = !_flashOn.value;
    _flashOn.value = _stub ? next : await _rec.setTorch(next);
    Haptics.tap();
  }

  Future<void> toggleMode() async {
    final toVideo = !_videoNoteMode.value;
    _videoNoteMode.value = toVideo;
    Haptics.tap();
    if (toVideo) {
      await _initCamera();
    } else {
      await _disposeCamera();
    }
  }

  bool get _stub => !_rec.isAvailable;

  Future<void> _initCamera() async {
    if (_stub) {
      _camReady.value = true;
      _textureId.value = null;
      return;
    }
    if (_rec.textureId != null) return;
    if (!await _rec.requestPermission()) {
      _videoNoteMode.value = false;
      if (isMounted()) {
        showCustomNotification(contextOf(), 'Нет доступа к камере');
      }
      return;
    }
    try {
      final ok = await _rec.init(
        front: _front,
        size: AppVideoNoteResolution.current.value,
        fps: AppVideoNoteFps.current.value,
      );
      if (!ok) {
        if (isMounted()) {
          showCustomNotification(contextOf(), 'Камера недоступна');
        }
        return;
      }
      if (!isMounted() || !_videoNoteMode.value) {
        await _disposeCamera();
        return;
      }
      _textureId.value = _rec.textureId;
      _camReady.value = true;
    } catch (e) {
      logger.w('initNoteCamera: $e');
      if (isMounted()) showCustomNotification(contextOf(), 'Камера недоступна');
    }
  }

  Future<void> _disposeCamera() async {
    _camReady.value = false;
    _textureId.value = null;
    if (!_stub) await _rec.dispose();
  }

  Future<void> start() async {
    if (_isRecording.value) return;
    _stopRequested = false;
    if (!_stub && _rec.textureId == null) {
      await _initCamera();
      return;
    }
    try {
      final ok = _stub || await _rec.start();
      if (!ok) {
        _isRecording.value = false;
        return;
      }
      if (!isMounted()) {
        if (!_stub) await _rec.stop();
        return;
      }
      _stopwatch
        ..reset()
        ..start();
      _elapsedMs.value = 0;
      _cancelDrag.value = 0;
      _lockDrag.value = 0;
      _locked.value = false;
      _cancelled = false;
      _isRecording.value = true;
      FocusManager.instance.primaryFocus?.unfocus();
      Haptics.send();
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        final ms = _stopwatch.elapsedMilliseconds;
        _elapsedMs.value = ms >= maxMs ? maxMs : ms;
        if (ms >= maxMs) unawaited(stop(cancel: false));
      });
      if (_stopRequested) {
        _stopRequested = false;
        await stop(cancel: false);
      }
    } catch (e) {
      logger.w('startNoteRecording: $e');
      _isRecording.value = false;
    }
  }

  Future<String?> _stubClip() async {
    try {
      final data = await rootBundle.load('assets/debug/fake_video_note.mp4');
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/note_stub_${DateTime.now().millisecondsSinceEpoch}.mp4',
      );
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return file.path;
    } catch (e) {
      logger.w('VideoNoteController._stubClip: $e');
      return null;
    }
  }

  Future<void> flipCamera() async {
    if (_stub) {
      Haptics.tap();
      return;
    }
    if (!_camReady.value || _switchingCamera) return;
    _switchingCamera = true;
    try {
      final ok = await _rec.switchCamera();
      if (ok) {
        _frontOverride = !_front;
        Haptics.tap();
      }
    } finally {
      _switchingCamera = false;
    }
  }

  void handleDrag(Offset offsetFromOrigin) {
    if (!_isRecording.value || _locked.value) return;

    final lock = (-offsetFromOrigin.dy / _lockThreshold).clamp(0.0, 1.0);
    _lockDrag.value = lock;
    if (lock >= 1.0) {
      _locked.value = true;
      _lockDrag.value = 0;
      _cancelDrag.value = 0;
      Haptics.send();
      return;
    }

    final drag = (-offsetFromOrigin.dx / VoiceRecordController.cancelThreshold)
        .clamp(0.0, 1.0);
    _cancelDrag.value = drag;
    if (drag >= 1.0 && !_cancelled) {
      _cancelled = true;
      Haptics.error();
      stop(cancel: true);
    }
  }

  void handleEnd() {
    if (_locked.value) return;
    stop(cancel: false);
  }

  Future<void> stop({required bool cancel}) async {
    if (!_isRecording.value) {
      _stopRequested = true;
      return;
    }
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds;
    _isRecording.value = false;
    _cancelDrag.value = 0;
    _lockDrag.value = 0;
    _locked.value = false;
    if (_flashOn.value) {
      _flashOn.value = false;
      unawaited(_rec.setTorch(false));
    }

    final path = _stub ? await _stubClip() : await _rec.stop();

    final shouldCancel =
        cancel || _cancelled || elapsed < VoiceRecordController.minMs;
    if (shouldCancel || path == null) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }

    // Файл уже квадратный (нативная запись) — шлём как есть.
    await onRecorded(File(path), elapsed);
  }

  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    _textureId.dispose();
    _videoNoteMode.dispose();
    _camReady.dispose();
    _isRecording.dispose();
    _elapsedMs.dispose();
    _cancelDrag.dispose();
    _locked.dispose();
    _lockDrag.dispose();
    _flashOn.dispose();
  }
}

class VideoNoteRecordingLayer extends StatefulWidget {
  const VideoNoteRecordingLayer({super.key, required this.controller});

  final VideoNoteController controller;

  @override
  State<VideoNoteRecordingLayer> createState() =>
      _VideoNoteRecordingLayerState();
}

class _VideoNoteRecordingLayerState extends State<VideoNoteRecordingLayer>
    with SingleTickerProviderStateMixin {
  static const double _circle = 260;
  static const double _maxBlur = 18;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.isRecording.addListener(_onRecordingChanged);
  }

  void _onRecordingChanged() {
    if (widget.controller.isRecording.value) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  @override
  void dispose() {
    widget.controller.isRecording.removeListener(_onRecordingChanged);
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = widget.controller;
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_reveal.value);
          if (t <= 0.001) return const SizedBox.shrink();
          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(
                        sigmaX: _maxBlur * t,
                        sigmaY: _maxBlur * t,
                      ),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.35 * t),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: AbsorbPointer(child: SizedBox.expand()),
              ),
              Opacity(opacity: t, child: child),
            ],
          );
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: ValueListenableBuilder<int>(
                    valueListenable: controller.elapsedMs,
                    builder: (context, ms, child) => CustomPaint(
                      foregroundPainter: _NoteProgressPainter(
                        progress: (ms / VideoNoteController.maxMs).clamp(
                          0.0,
                          1.0,
                        ),
                        color: Colors.white,
                      ),
                      child: child,
                    ),
                    child: SizedBox(
                      width: _circle,
                      height: _circle,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: ClipOval(
                          child: ValueListenableBuilder<int?>(
                            valueListenable: controller.textureId,
                            builder: (context, texId, _) => texId == null
                                ? _StubPreview(controller: controller)
                                : Texture(textureId: texId),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom:
                  MediaQuery.paddingOf(context).bottom +
                  widget.controller.bottomInset() +
                  12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _CameraControls(controller: controller, cs: cs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StubPreview extends StatelessWidget {
  const _StubPreview({required this.controller});

  final VideoNoteController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.elapsedMs,
      builder: (context, ms, _) {
        final hue = (ms / 40) % 360;
        return ColoredBox(
          color: HSVColor.fromAHSV(1, hue, 0.45, 0.35).toColor(),
          child: const Center(
            child: Icon(Symbols.videocam, size: 64, color: Colors.white54),
          ),
        );
      },
    );
  }
}

class _CameraControls extends StatelessWidget {
  const _CameraControls({required this.controller, required this.cs});

  final VideoNoteController controller;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GlossyPill(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      depth: 10,
      elevated: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.cameraControlsAvailable)
            _ControlButton(
              icon: Symbols.flip_camera_ios,
              color: cs.onSurface,
              onTap: controller.flipCamera,
            ),
          if (controller.flashAvailable)
            ValueListenableBuilder<bool>(
              valueListenable: controller.flashOn,
              builder: (context, on, _) => _ControlButton(
                icon: on ? Symbols.flash_on : Symbols.flash_off,
                color: on ? cs.primary : cs.onSurface,
                onTap: controller.toggleFlash,
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 24, color: color, fill: 1),
      ),
    );
  }
}

class _NoteProgressPainter extends CustomPainter {
  const _NoteProgressPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const double _stroke = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final circle = (Offset.zero & size).deflate(_stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(circle, -math.pi / 2, math.pi * 2 * progress, false, paint);
  }

  @override
  bool shouldRepaint(_NoteProgressPainter old) => old.progress != progress;
}
