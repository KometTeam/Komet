import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../utils/logger.dart';

class MediaKitVideoPlatform extends VideoPlayerPlatform {
  static void registerOnDesktop() {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows ||
          TargetPlatform.linux ||
          TargetPlatform.macOS:
        MediaKit.ensureInitialized();
        VideoPlayerPlatform.instance = MediaKitVideoPlatform();
      case TargetPlatform.android ||
          TargetPlatform.iOS ||
          TargetPlatform.fuchsia:
        return;
    }
  }

  final Map<int, _VideoSession> _sessions = {};
  int _nextPlayerId = 1;

  _VideoSession _session(int playerId) {
    final session = _sessions[playerId];
    if (session == null) {
      throw StateError('Video player $playerId is disposed');
    }
    return session;
  }

  @override
  Future<void> init() async {
    for (final playerId in _sessions.keys.toList()) {
      await dispose(playerId);
    }
  }

  @override
  Future<void> dispose(int playerId) async {
    await _sessions.remove(playerId)?.dispose();
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    final playerId = _nextPlayerId++;
    final session = _VideoSession(_resourceOf(dataSource));
    _sessions[playerId] = session;
    await session.open(dataSource.httpHeaders);
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _session(playerId).events;

  @override
  Future<void> setLooping(int playerId, bool looping) => _session(
    playerId,
  ).player.setPlaylistMode(looping ? PlaylistMode.single : PlaylistMode.none);

  @override
  Future<void> play(int playerId) => _session(playerId).player.play();

  @override
  Future<void> pause(int playerId) => _session(playerId).player.pause();

  @override
  Future<void> setVolume(int playerId, double volume) =>
      _session(playerId).player.setVolume(volume * 100);

  @override
  Future<void> seekTo(int playerId, Duration position) =>
      _session(playerId).player.seek(position);

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) =>
      _session(playerId).player.setRate(speed);

  @override
  Future<Duration> getPosition(int playerId) async =>
      _session(playerId).player.state.position;

  @override
  Widget buildView(int playerId) {
    final video = _session(playerId).video;
    return Video(
      key: ValueKey(video),
      controller: video,
      controls: NoVideoControls,
      fill: const Color(0x00000000),
      wakelock: false,
      pauseUponEnteringBackgroundMode: false,
      resumeUponEnteringForegroundMode: false,
    );
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  static String _resourceOf(DataSource dataSource) {
    switch (dataSource.sourceType) {
      case DataSourceType.asset:
        final package = dataSource.package;
        final asset = package == null
            ? dataSource.asset
            : 'packages/$package/${dataSource.asset}';
        return 'asset:///$asset';
      case DataSourceType.network ||
          DataSourceType.file ||
          DataSourceType.contentUri:
        final uri = dataSource.uri;
        if (uri == null) throw ArgumentError('uri must not be null');
        return uri;
    }
  }
}

class _VideoSession {
  _VideoSession(this._resource) {
    video = VideoController(player);
    _subscriptions.addAll([
      player.stream.duration.listen(_onDuration),
      player.stream.videoParams.listen(_onVideoParams),
      player.stream.tracks.listen(_onTracks),
      player.stream.playing.listen(
        (playing) => _emitWhenInitialized(
          VideoEvent(
            eventType: VideoEventType.isPlayingStateUpdate,
            isPlaying: playing,
          ),
        ),
      ),
      player.stream.completed.listen((completed) {
        if (!completed) return;
        _emitWhenInitialized(VideoEvent(eventType: VideoEventType.completed));
      }),
      player.stream.buffering.listen(
        (buffering) => _emitWhenInitialized(
          VideoEvent(
            eventType: buffering
                ? VideoEventType.bufferingStart
                : VideoEventType.bufferingEnd,
          ),
        ),
      ),
      player.stream.buffer.listen(
        (buffered) => _emitWhenInitialized(
          VideoEvent(
            eventType: VideoEventType.bufferingUpdate,
            buffered: [DurationRange(Duration.zero, buffered)],
          ),
        ),
      ),
      player.stream.error.listen(_onError),
      player.stream.log.listen(_onLog),
    ]);
  }

  static const Duration _startTimeout = Duration(seconds: 20);
  static const int _maxLoggedLines = 40;
  static const List<String> _loadFailures = [
    'Failed to open',
    'Failed to recognize file format',
  ];
  static final RegExp _url = RegExp(r'(https?)://([^/\s?#]+)\S*');

  final String _resource;
  final Player player = Player(
    configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
  );
  late final VideoController video;
  final StreamController<VideoEvent> _events = StreamController();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _startWatchdog;
  Duration? _duration;
  Size? _size;
  bool _initialized = false;
  bool _failed = false;
  String? _lastError;
  int _loggedLines = 0;

  Stream<VideoEvent> get events => _events.stream;

  Future<void> open(Map<String, String> httpHeaders) async {
    _startWatchdog = Timer(
      _startTimeout,
      () => _fail(
        _lastError ?? 'playback did not start in ${_startTimeout.inSeconds}s',
      ),
    );
    try {
      await player.open(
        Media(_resource, httpHeaders: httpHeaders),
        play: false,
      );
    } catch (error) {
      _fail(_redact('$error'));
    }
  }

  void _onDuration(Duration duration) {
    if (duration <= Duration.zero) return;
    _duration = duration;
    _maybeInitialize();
  }

  void _onVideoParams(VideoParams params) {
    final width = params.dw ?? 0;
    final height = params.dh ?? 0;
    if (width <= 0 || height <= 0) return;
    _size = Size(width.toDouble(), height.toDouble());
    _maybeInitialize();
  }

  void _onTracks(Tracks tracks) {
    final audioOnly = tracks.video.length == 2 && tracks.audio.length > 2;
    if (!audioOnly) return;
    _size = Size.zero;
    _maybeInitialize();
  }

  void _maybeInitialize() {
    final duration = _duration;
    final size = _size;
    if (_initialized || _failed || _events.isClosed) return;
    if (duration == null || size == null) return;
    _initialized = true;
    _startWatchdog?.cancel();
    _events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: duration,
        size: size,
      ),
    );
  }

  void _emitWhenInitialized(VideoEvent event) {
    if (_initialized && !_events.isClosed) _events.add(event);
  }

  void _onError(String message) {
    _lastError = _redact(message);
    if (_loadFailures.any(message.startsWith)) _fail(_lastError!);
  }

  void _fail(String message) {
    if (_failed || _events.isClosed) return;
    _failed = true;
    _startWatchdog?.cancel();
    logger.w('Video playback failed (${_describeSource()}): $message');
    _events.addError(PlatformException(code: 'media_kit', message: message));
  }

  void _onLog(PlayerLog log) {
    if (log.level != 'error' && log.level != 'warn') return;
    if (_loggedLines >= _maxLoggedLines) return;
    _loggedLines++;
    logger.w('mpv ${log.prefix}/${log.level}: ${_redact(log.text)}');
  }

  String _describeSource() {
    final uri = Uri.tryParse(_resource);
    if (uri == null || !uri.hasScheme) return 'file';
    return uri.host.isEmpty ? uri.scheme : uri.host;
  }

  static String _redact(String text) => text.trim().replaceAllMapped(
    _url,
    (match) => '${match[1]}://${match[2]}',
  );

  Future<void> dispose() async {
    _startWatchdog?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _events.close();
    await player.dispose();
  }
}
