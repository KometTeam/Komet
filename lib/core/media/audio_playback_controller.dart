import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

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

  static AudioPlaybackController get instance {
    final value = _instance;
    if (value == null) throw StateError('Audio playback is not initialized');
    return value;
  }

  static bool get isInitialized => _instance != null;

  static Future<void> initialize() async {
    if (_instance != null) return;
    final handler = switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux => BackgroundAudioHandler(),
      _ => await AudioService.init(
        builder: BackgroundAudioHandler.new,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'ru.komet.app.audio',
          androidNotificationChannelName: 'Воспроизведение аудио',
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
        ),
      ),
    };
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _instance = AudioPlaybackController._(handler);
  }

  final BackgroundAudioHandler _handler;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  final ValueNotifier<bool> playing = ValueNotifier(false);
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> bufferedPosition = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<AudioProcessingState> processingState = ValueNotifier(
    AudioProcessingState.idle,
  );
  final ValueNotifier<String?> error = ValueNotifier(null);

  Future<void> playTrack(AudioFileTrack track) async {
    error.value = null;
    position.value = Duration.zero;
    bufferedPosition.value = Duration.zero;
    duration.value = Duration.zero;
    await _handler.load(track);
    await _handler.play();
  }

  Future<void> toggle() => playing.value ? _handler.pause() : _handler.play();

  Future<void> seek(Duration value) => _handler.seek(value);

  Future<void> stop() => _handler.stop();

  void _onActiveCallChanged() {
    if (ActiveCall.instance.current.value != null && playing.value) {
      unawaited(_handler.pause());
    }
  }
}
