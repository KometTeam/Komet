import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/media/opus_ogg_encoder.dart';
import '../../../../core/utils/haptics.dart';
import '../../../widgets/custom_notification.dart';

class VoiceRecordController {
  VoiceRecordController({
    required this.contextOf,
    required this.isMounted,
    required this.myId,
    required this.onRecorded,
  });

  final BuildContext Function() contextOf;
  final bool Function() isMounted;
  final int Function() myId;
  final Future<void> Function(File file, int durationMs, List<double> amps)
  onRecorded;

  static const int minMs = 800;
  static const double cancelThreshold = 110;
  static const double _lockThreshold = 90;

  AudioRecorder? _recorder;
  final ValueNotifier<bool> _isRecording = ValueNotifier(false);
  final ValueNotifier<int> _elapsedMs = ValueNotifier(0);
  final ValueNotifier<double> _cancelDrag = ValueNotifier(0);
  final ValueNotifier<double> _amplitude = ValueNotifier(0);
  final ValueNotifier<int> _waveRev = ValueNotifier(0);
  final ValueNotifier<bool> _locked = ValueNotifier(false);
  final ValueNotifier<double> _lockDrag = ValueNotifier(0);
  final Stopwatch _stopwatch = Stopwatch();
  final List<double> _amps = [];
  Timer? _timer;
  StreamSubscription<Amplitude>? _ampSub;
  String? _path;
  bool _cancelled = false;
  bool _stopRequested = false;
  bool _transcode = false;

  ValueListenable<bool> get isRecording => _isRecording;
  ValueListenable<int> get elapsedMs => _elapsedMs;
  ValueListenable<double> get cancelDrag => _cancelDrag;
  ValueListenable<double> get amplitude => _amplitude;
  ValueListenable<int> get waveRev => _waveRev;
  ValueListenable<bool> get locked => _locked;
  ValueListenable<double> get lockDrag => _lockDrag;
  List<double> get amps => _amps;

  Future<void> start() async {
    if (_isRecording.value || myId() == 0) return;
    _stopRequested = false;
    final rec = _recorder ??= AudioRecorder();
    try {
      final AudioEncoder encoder;
      final String ext;
      // Предпочитаем собственный кодер (libopus → Ogg/Opus): его формат сервер
      // гарантированно принимает. Нативный Opus от record (напр. на Android)
      // CDN не дообрабатывает — остаётся attachment.not.ready.
      if (await OpusOggEncoder.ensureAvailable() &&
          await rec.isEncoderSupported(AudioEncoder.wav)) {
        encoder = AudioEncoder.wav;
        ext = 'wav';
        _transcode = true;
      } else if (await rec.isEncoderSupported(AudioEncoder.opus)) {
        encoder = AudioEncoder.opus;
        ext = 'ogg';
        _transcode = false;
      } else {
        if (isMounted()) {
          showCustomNotification(
            contextOf(),
            'Голосовые сообщения недоступны на этой платформе',
          );
        }
        return;
      }
      if (!await rec.hasPermission()) {
        if (isMounted()) {
          showCustomNotification(contextOf(), 'Нет доступа к микрофону');
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
      _amps.clear();
      _cancelled = false;
      _path = path;
      await rec.start(
        RecordConfig(encoder: encoder, numChannels: 1, sampleRate: 48000),
        path: path,
      );
      if (!isMounted()) {
        try {
          await rec.stop();
        } catch (_) {}
        return;
      }
      _stopwatch
        ..reset()
        ..start();
      _elapsedMs.value = 0;
      _cancelDrag.value = 0;
      _locked.value = false;
      _lockDrag.value = 0;
      _isRecording.value = true;
      FocusManager.instance.primaryFocus?.unfocus();
      Haptics.send();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _elapsedMs.value = _stopwatch.elapsedMilliseconds;
      });
      _ampSub = rec.onAmplitudeChanged(const Duration(milliseconds: 70)).listen(
        (amp) {
          final norm = ((amp.current + 45) / 45).clamp(0.0, 1.0);
          _amps.add(norm);
          _amplitude.value = norm;
          _waveRev.value++;
        },
      );
      if (_stopRequested) {
        _stopRequested = false;
        await stop(cancel: false);
      }
    } catch (_) {
      _isRecording.value = false;
      if (isMounted()) {
        showCustomNotification(contextOf(), 'Не удалось начать запись');
      }
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

    final drag = (-offsetFromOrigin.dx / cancelThreshold).clamp(0.0, 1.0);
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
    final rec = _recorder;
    if (rec == null) {
      _isRecording.value = false;
      return;
    }

    _timer?.cancel();
    _timer = null;
    await _ampSub?.cancel();
    _ampSub = null;
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds;
    _isRecording.value = false;
    _cancelDrag.value = 0;
    _amplitude.value = 0;
    _locked.value = false;
    _lockDrag.value = 0;

    String? path;
    try {
      path = await rec.stop();
    } catch (_) {}
    path ??= _path;
    final amps = List<double>.from(_amps);
    _amps.clear();

    final shouldCancel = cancel || _cancelled || elapsed < minMs;
    if (shouldCancel || path == null) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }

    var file = File(path);
    if (_transcode) {
      final ogg = await _transcodeWavToOgg(file);
      if (ogg == null) {
        if (isMounted()) {
          showCustomNotification(contextOf(), 'Не удалось закодировать запись');
        }
        return;
      }
      file = ogg;
    }
    await onRecorded(file, elapsed, amps);
  }

  Future<File?> _transcodeWavToOgg(File wav) async {
    try {
      final bytes = await wav.readAsBytes();
      final ogg = await OpusOggEncoder.wavToOggOpus(bytes);
      try {
        await wav.delete();
      } catch (_) {}
      if (ogg == null) return null;
      final oggPath = '${wav.path.substring(0, wav.path.length - 3)}ogg';
      final out = File(oggPath);
      await out.writeAsBytes(ogg, flush: true);
      return out;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _timer?.cancel();
    _ampSub?.cancel();
    _recorder?.dispose();
    _isRecording.dispose();
    _elapsedMs.dispose();
    _cancelDrag.dispose();
    _amplitude.dispose();
    _waveRev.dispose();
    _locked.dispose();
    _lockDrag.dispose();
  }
}
