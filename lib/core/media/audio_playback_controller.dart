import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import '../calls/active_call.dart';
import 'audio_file_track.dart';
import 'background_audio_handler.dart';

class AudioPlaybackController {
  AudioPlaybackController._(this._handler) {
    _subscriptions.add(
      _handler.playbackState.listen((state) {
        playing.value = state.playing;
        processingState.value = state.processingState;
        bufferedPosition.value = state.bufferedPosition;
      }),
    );
    _subscriptions.add(
      _handler.mediaItem.listen((item) {
        duration.value = item?.duration ?? Duration.zero;
      }),
    );
    _subscriptions.add(
      _handler.positionStream.listen((value) => position.value = value),
    );
    _subscriptions.add(
      _handler.bufferedPositionStream.listen(
        (value) => bufferedPosition.value = value,
      ),
    );
    _subscriptions.add(
      _handler.errors.stream.listen((value) => error.value = value),
    );
    ActiveCall.instance.current.addListener(_onActiveCallChanged);
  }

  static AudioPlaybackController? _instance;
  static Future<AudioPlaybackController>? _pending;

  static AudioPlaybackController get instance {
    final value = _instance;
    if (value == null) throw StateError('Audio playback is not initialized');
    return value;
  }

  static bool get isInitialized => _instance != null;

  static final ValueNotifier<String?> error = ValueNotifier(null);

  static Future<AudioPlaybackController> ensureInitialized(
    String notificationChannelName,
  ) async {
    final ready = _instance;
    if (ready != null) return ready;
    final pending = _pending ??= _create(notificationChannelName);
    try {
      return await pending;
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }

  static Future<AudioPlaybackController> _create(String channelName) async {
    JustAudioMediaKit.ensureInitialized(linux: true, windows: true);
    final handler = switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux => BackgroundAudioHandler(),
      _ => await AudioService.init(
        builder: BackgroundAudioHandler.new,
        config: AudioServiceConfig(
          androidNotificationChannelId: 'komet.audio.playback',
          androidNotificationChannelName: channelName,
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
        ),
      ),
    };
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    return _instance = AudioPlaybackController._(handler);
  }

  final BackgroundAudioHandler _handler;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _pausedByCall = false;

  final ValueNotifier<bool> playing = ValueNotifier(false);
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> bufferedPosition = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<AudioProcessingState> processingState = ValueNotifier(
    AudioProcessingState.idle,
  );

  Future<void> playTrack(AudioFileTrack track) async {
    error.value = null;
    _pausedByCall = false;
    position.value = Duration.zero;
    bufferedPosition.value = Duration.zero;
    duration.value = Duration.zero;
    await _handler.load(track);
    await _handler.play();
  }

  Future<void> toggle() {
    _pausedByCall = false;
    return playing.value ? _handler.pause() : _handler.play();
  }

  Future<void> seek(Duration value) => _handler.seek(value);

  Future<void> stop() {
    _pausedByCall = false;
    return _handler.stop();
  }

  Future<void> dispose() async {
    ActiveCall.instance.current.removeListener(_onActiveCallChanged);
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _handler.dispose();
    playing.dispose();
    position.dispose();
    bufferedPosition.dispose();
    duration.dispose();
    processingState.dispose();
    if (identical(_instance, this)) {
      _instance = null;
      _pending = null;
    }
  }

  void _onActiveCallChanged() {
    if (ActiveCall.instance.current.value != null) {
      if (!playing.value) return;
      _pausedByCall = true;
      unawaited(_handler.pause());
      return;
    }
    if (!_pausedByCall) return;
    _pausedByCall = false;
    if (processingState.value == AudioProcessingState.idle) return;
    unawaited(_handler.play());
  }
}
