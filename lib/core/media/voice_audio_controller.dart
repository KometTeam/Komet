import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ogg_opus_player/ogg_opus_player.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/download_progress.dart';
import '../utils/logger.dart';
import '../utils/media_cache.dart';
import 'opus_ogg_index.dart';

enum VoiceAudioFailure { none, download, playback }

class VoiceAudioController {
  VoiceAudioController({
    required this.cacheName,
    required this.resolveUrl,
    required Duration fallbackDuration,
  }) : duration = ValueNotifier(
         fallbackDuration.inMicroseconds / Duration.microsecondsPerSecond,
       );

  final String cacheName;
  final Future<String?> Function() resolveUrl;

  static const double _endEpsilon = 0.05;

  static VoiceAudioController? _active;
  static int _sliceCounter = 0;
  static Directory? _sliceDir;

  final ValueNotifier<bool> playing = ValueNotifier(false);
  final ValueNotifier<double> position = ValueNotifier(0);
  final ValueNotifier<double> duration;
  final ValueNotifier<VoiceAudioFailure> failure = ValueNotifier(
    VoiceAudioFailure.none,
  );

  ValueListenable<double?> get downloadProgress =>
      MediaDownloadProgress.notifier(cacheName);

  ValueListenable<bool> get downloaded => MediaCache.presence(cacheName);

  bool get scrubbing => _scrubbing;

  File? _file;
  OpusOggIndex? _index;
  OggOpusPlayer? _player;
  File? _slice;
  Timer? _ticker;
  Future<void>? _loading;
  double _sliceOffset = 0;
  double _speed = 1;
  int _startGeneration = 0;
  bool _scrubbing = false;
  bool _resumeAfterScrub = false;
  bool _finished = false;
  bool _disposed = false;

  Future<void> toggle() async {
    if (playing.value) {
      pause();
      return;
    }
    await play();
  }

  Future<void> play() async {
    if (_disposed) return;
    if (!await _ensureLoaded()) return;
    if (_disposed) return;

    if (_active != this) {
      _active?.pause();
      _active = this;
    }

    if (_finished) {
      _finished = false;
      _disposePlayer();
      position.value = 0;
    }

    final player = _player;
    if (player != null) {
      player.play();
      _applySpeed();
      playing.value = true;
      _startTicker();
      return;
    }

    final total = duration.value;
    final from = total > 0 && position.value >= total - _endEpsilon
        ? 0.0
        : position.value;
    await _startAt(from);
  }

  void pause() {
    _startGeneration++;
    _player?.pause();
    playing.value = false;
    _stopTicker();
  }

  void setSpeed(double speed) {
    if (_disposed) return;
    _speed = speed;
    _applySpeed();
  }

  void stopAndReset() {
    if (_disposed) return;
    pause();
    _disposePlayer();
    _finished = false;
    _sliceOffset = 0;
    position.value = 0;
  }

  void _applySpeed() {
    final player = _player;
    if (player == null) return;
    try {
      player.setPlaybackRate(_speed);
    } catch (e) {
      logger.w('VoiceAudioController.setSpeed($cacheName): $e');
    }
  }

  Future<void> seekTo(double seconds) async {
    scrubStart();
    scrubTo(seconds);
    await scrubEnd();
  }

  void scrubStart() {
    if (_scrubbing) return;
    _scrubbing = true;
    _resumeAfterScrub = playing.value;
    _startGeneration++;
    if (playing.value) pause();
  }

  void scrubTo(double seconds) {
    final total = duration.value;
    position.value = total <= 0 ? 0 : seconds.clamp(0.0, total);
  }

  Future<void> scrubEnd() async {
    if (!_scrubbing) return;
    _scrubbing = false;
    final resume = _resumeAfterScrub;
    _resumeAfterScrub = false;
    _finished = false;

    if (_file == null) {
      if (resume) await play();
      return;
    }

    _disposePlayer();
    if (resume) await _startAt(position.value);
  }

  Future<bool> _ensureLoaded() async {
    if (_file != null) return true;
    final running = _loading;
    if (running != null) {
      await running;
      return _file != null;
    }
    final future = _load();
    _loading = future;
    try {
      await future;
    } finally {
      _loading = null;
    }
    return _file != null;
  }

  Future<void> _load() async {
    failure.value = VoiceAudioFailure.none;
    try {
      var file = await MediaCache.existing(cacheName);
      if (file == null) {
        MediaDownloadProgress.set(cacheName, 0);
        try {
          final url = await resolveUrl();
          if (url != null && url.isNotEmpty) {
            file = await MediaCache.getOrDownload(
              cacheName,
              url,
              onProgress: (value) =>
                  MediaDownloadProgress.set(cacheName, value),
            );
          }
        } finally {
          MediaDownloadProgress.set(cacheName, null);
        }
      }
      if (_disposed) return;
      if (file == null) {
        failure.value = VoiceAudioFailure.download;
        return;
      }
      _file = file;
      await _buildIndex(file);
    } catch (e) {
      logger.w('VoiceAudioController._load($cacheName): $e');
      if (!_disposed) failure.value = VoiceAudioFailure.download;
    }
  }

  Future<void> _buildIndex(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (_disposed) return;
      final index = OpusOggIndex.parse(bytes);
      if (index == null) return;
      _index = index;
      if (index.duration > 0) duration.value = index.duration;
    } catch (e) {
      logger.w('VoiceAudioController: индекс не построен ($cacheName): $e');
    }
  }

  Future<void> _startAt(double seconds) async {
    final file = _file;
    if (file == null) return;
    final generation = ++_startGeneration;
    _disposePlayer();

    final total = duration.value;
    if (total > 0 && seconds >= total - _endEpsilon) {
      _finished = true;
      playing.value = false;
      position.value = total;
      return;
    }

    var path = file.path;
    var offset = 0.0;
    final index = _index;
    if (seconds > 0 && index != null) {
      final bytes = index.sliceFrom(seconds);
      if (bytes != null) {
        final slice = await _writeSlice(bytes);
        if (_disposed || generation != _startGeneration) return;
        if (slice != null) {
          path = slice.path;
          offset = seconds;
        }
      }
    }

    _sliceOffset = offset;
    position.value = offset;

    try {
      final player = OggOpusPlayer(path);
      _player = player;
      player.state.addListener(_onPlayerState);
      player.play();
      _applySpeed();
      playing.value = true;
      _startTicker();
    } catch (e) {
      logger.w('VoiceAudioController._startAt($cacheName): $e');
      failure.value = VoiceAudioFailure.playback;
      playing.value = false;
    }
  }

  Future<File?> _writeSlice(Uint8List bytes) async {
    try {
      final dir = _sliceDir ??= await getTemporaryDirectory();
      final next = File(p.join(dir.path, 'voice_slice_${_sliceCounter++}.ogg'));
      await next.writeAsBytes(bytes);
      final previous = _slice;
      _slice = next;
      await _deleteQuietly(previous);
      return next;
    } catch (e) {
      logger.w('VoiceAudioController._writeSlice($cacheName): $e');
      return null;
    }
  }

  void _onPlayerState() {
    final state = _player?.state.value;
    if (state == null || _disposed) return;
    if (state == PlayerState.ended) {
      _finished = true;
      playing.value = false;
      position.value = duration.value;
      _stopTicker();
      return;
    }
    if (state == PlayerState.error) {
      failure.value = VoiceAudioFailure.playback;
      playing.value = false;
      _stopTicker();
    }
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _onTick(),
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTick() {
    final player = _player;
    if (player == null || _scrubbing || _finished) return;
    final total = duration.value;
    final value = _sliceOffset + player.currentPosition;
    position.value = total > 0 ? value.clamp(0.0, total) : value;
  }

  void _disposePlayer() {
    final player = _player;
    _player = null;
    _stopTicker();
    if (player == null) return;
    player.state.removeListener(_onPlayerState);
    player.dispose();
  }

  static Future<void> _deleteQuietly(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    _disposePlayer();
    if (_active == this) _active = null;
    final slice = _slice;
    _slice = null;
    _deleteQuietly(slice).ignore();
    playing.dispose();
    position.dispose();
    duration.dispose();
    failure.dispose();
  }
}
