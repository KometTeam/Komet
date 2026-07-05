import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
  });

  final BuildContext Function() contextOf;
  final bool Function() isMounted;
  final Future<void> Function(File file, int durationMs) onRecorded;
  final String Function(int ms) formatElapsed;

  final NativeVideoNoteRecorder _rec = NativeVideoNoteRecorder();
  final ValueNotifier<bool> _videoNoteMode = ValueNotifier(false);
  final ValueNotifier<int?> _textureId = ValueNotifier(null);
  final ValueNotifier<bool> _camReady = ValueNotifier(false);
  final ValueNotifier<bool> _isRecording = ValueNotifier(false);
  final ValueNotifier<int> _elapsedMs = ValueNotifier(0);
  final ValueNotifier<double> _cancelDrag = ValueNotifier(0);
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _cancelled = false;
  bool _stopRequested = false;
  OverlayEntry? _overlay;

  ValueListenable<bool> get videoNoteMode => _videoNoteMode;
  ValueListenable<bool> get camReady => _camReady;
  ValueListenable<bool> get isRecording => _isRecording;

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

  Future<void> _initCamera() async {
    if (_rec.textureId != null) return;
    if (!_rec.isAvailable) {
      if (isMounted()) showCustomNotification(contextOf(), 'Камера недоступна');
      return;
    }
    try {
      final ok = await _rec.init();
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
    await _rec.dispose();
  }

  Future<void> start() async {
    if (_isRecording.value) return;
    _stopRequested = false;
    if (_rec.textureId == null) {
      await _initCamera();
      return;
    }
    try {
      final ok = await _rec.start();
      if (!ok) {
        _isRecording.value = false;
        return;
      }
      if (!isMounted()) {
        await _rec.stop();
        return;
      }
      _stopwatch
        ..reset()
        ..start();
      _elapsedMs.value = 0;
      _cancelDrag.value = 0;
      _cancelled = false;
      _isRecording.value = true;
      FocusManager.instance.primaryFocus?.unfocus();
      Haptics.send();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _elapsedMs.value = _stopwatch.elapsedMilliseconds;
      });
      _showOverlay();
      if (_stopRequested) {
        _stopRequested = false;
        await stop(cancel: false);
      }
    } catch (e) {
      logger.w('startNoteRecording: $e');
      _isRecording.value = false;
    }
  }

  void handleDrag(Offset offsetFromOrigin) {
    if (!_isRecording.value) return;
    final drag = (-offsetFromOrigin.dx / VoiceRecordController.cancelThreshold)
        .clamp(0.0, 1.0);
    _cancelDrag.value = drag;
    if (drag >= 1.0 && !_cancelled) {
      _cancelled = true;
      Haptics.error();
      stop(cancel: true);
    }
  }

  void handleEnd() => stop(cancel: false);

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
    _hideOverlay();

    final path = await _rec.stop();

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

    // Файл уже квадратный 480×480 (нативная запись) — шлём как есть.
    await onRecorded(File(path), elapsed);
  }

  void _showOverlay() {
    _overlay?.remove();
    _overlay = OverlayEntry(
      builder: (context) {
        final texId = _textureId.value;
        return Positioned.fill(
          child: IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 260,
                      height: 260,
                      child: texId != null
                          ? Texture(textureId: texId)
                          : Container(color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<int>(
                    valueListenable: _elapsedMs,
                    builder: (context, ms, _) => Text(
                      formatElapsed(ms),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFeatures: [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<double>(
                    valueListenable: _cancelDrag,
                    builder: (context, drag, _) => Opacity(
                      opacity: (0.5 + drag * 0.5).clamp(0.0, 1.0),
                      child: const Text(
                        '‹ влево — отмена',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    final overlay = Overlay.of(contextOf(), rootOverlay: true);
    overlay.insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void dispose() {
    _timer?.cancel();
    _overlay?.remove();
    _rec.dispose();
    _textureId.dispose();
    _videoNoteMode.dispose();
    _camReady.dispose();
    _isRecording.dispose();
    _elapsedMs.dispose();
    _cancelDrag.dispose();
  }
}
