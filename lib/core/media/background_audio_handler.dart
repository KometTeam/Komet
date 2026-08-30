import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_file_track.dart';

// #***! обвязка audio_service, рисует уведомление и ловит кнопки наушников
class BackgroundAudioHandler extends BaseAudioHandler with SeekHandler {
  BackgroundAudioHandler() {
    _subscriptions.add(
      _player.playbackEventStream.listen((_) => _broadcastState()),
    );
    _subscriptions.add(
      _player.errorStream.listen((error) => errors.add(error.message ?? '')),
    );
    _subscriptions.add(_player.durationStream.listen(_updateDuration));
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<String> errors = StreamController.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;

  // #***! загрузка трека с метаданными для шторки
  Future<void> load(AudioFileTrack track) async {
    final item = MediaItem(
      id: track.cacheName,
      title: track.name,
      album: track.sourceName.isEmpty ? null : track.sourceName,
      artUri: _artUri(track.thumbnailUrl),
      extras: {
        'path': track.path,
        'chatId': track.chatId,
        'messageId': track.messageId,
        'messageTime': track.messageTime,
      },
    );
    mediaItem.add(item);
    final duration = await _player.setFilePath(track.path);
    if (duration != null) mediaItem.add(item.copyWith(duration: duration));
    _broadcastState();
  }

  Uri? _artUri(String? value) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !const {'http', 'https', 'file'}.contains(uri.scheme)) {
      return null;
    }
    return uri;
  }

  void _updateDuration(Duration? duration) {
    final item = mediaItem.value;
    if (item == null || duration == null || item.duration == duration) return;
    mediaItem.add(item.copyWith(duration: duration));
  }

  @override
  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    await errors.close();
  }

  // #***! состояние транслируем системе чтоб уведомление совпадало с плеером
  void _broadcastState() {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0],
        processingState: _processingState(_player.processingState),
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  AudioProcessingState _processingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }
}
