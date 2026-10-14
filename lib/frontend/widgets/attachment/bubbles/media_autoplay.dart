import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:komet/main.dart' show messagesModule;

import '../../../../core/config/komet_settings.dart';
import '../../../../core/media/auto_download_gate.dart';
import '../../../../core/media/video_preloader.dart';
import '../../../../core/utils/logger.dart';
import '../../../../models/attachment.dart';

typedef MediaAutoplayBuilder =
    Widget Function(BuildContext context, Widget surface, bool playing);

class AutoplayClip {
  static const int maxVideoDurationMs = 60000;
  static const int maxBytes = 20 * 1024 * 1024;

  final String cacheName;
  final String? localPath;
  final Future<String?> Function()? resolveUrl;
  final Size frameSize;
  final ValueListenable<bool> setting;
  final ValueListenable<bool> autoDownload;

  const AutoplayClip({
    required this.cacheName,
    required this.frameSize,
    required this.setting,
    required this.autoDownload,
    this.localPath,
    this.resolveUrl,
  });

  static AutoplayClip? video(
    VideoAttachment video, {
    required String messageId,
    required int chatId,
  }) {
    final duration = video.duration;
    if (duration == null || duration <= 0 || duration > maxVideoDurationMs) {
      return null;
    }
    final videoId = video.videoId;
    final token = video.videoToken;
    final localPath = video.localPath;
    if (localPath == null && (videoId == null || token == null)) return null;
    return AutoplayClip(
      cacheName: 'videopreview_$videoId.mp4',
      localPath: localPath,
      resolveUrl: videoId == null || token == null
          ? null
          : () => messagesModule.getVideoPreviewUrl(
              messageId: messageId,
              chatId: chatId,
              token: token,
              videoId: videoId,
            ),
      frameSize: _sizeOf(video.width, video.height),
      setting: KometSettings.autoplayVideo,
      autoDownload: KometSettings.autoDownloadVideo,
    );
  }

  static AutoplayClip? gif(PhotoAttachment photo) {
    final url = photo.mp4Url;
    final photoId = photo.photoId;
    if (!photo.isGif || url == null || url.isEmpty || photoId == null) {
      return null;
    }
    return AutoplayClip(
      cacheName: 'gif_$photoId.mp4',
      resolveUrl: () async => url,
      frameSize: _sizeOf(photo.width, photo.height),
      setting: KometSettings.autoplayGif,
      autoDownload: KometSettings.autoDownloadPhoto,
    );
  }

  static Size _sizeOf(int? width, int? height) =>
      Size((width ?? 1).toDouble(), (height ?? 1).toDouble());
}

class MediaAutoplay extends StatefulWidget {
  final AutoplayClip? clip;
  final String? manualLoadKey;
  final bool suspended;
  final MediaAutoplayBuilder builder;

  const MediaAutoplay({
    super.key,
    required this.clip,
    required this.manualLoadKey,
    required this.suspended,
    required this.builder,
  });

  @override
  State<MediaAutoplay> createState() => _MediaAutoplayState();
}

class _MediaAutoplayState extends State<MediaAutoplay>
    with WidgetsBindingObserver {
  static const double _visibleFraction = 0.6;
  static const Duration _fadeIn = Duration(milliseconds: 180);

  final Key _visibilityKey = UniqueKey();
  final List<Listenable> _watched = [];
  VideoPlayerController? _controller;
  Future<void>? _opening;
  bool _visible = false;
  bool _foreground = true;
  bool _playing = false;
  bool _hasFrame = false;
  bool _failed = false;

  bool get _allowed {
    final clip = widget.clip;
    if (clip == null || !clip.setting.value || widget.suspended || _failed) {
      return false;
    }
    if (clip.localPath != null) return true;
    final key = widget.manualLoadKey;
    final autoDownload = clip.autoDownload.value;
    return key == null
        ? autoDownload
        : AutoDownloadGate.allows(autoDownload, key);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watch();
  }

  @override
  void didUpdateWidget(MediaAutoplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final clip = widget.clip;
    final old = oldWidget.clip;
    if (!identical(old?.setting, clip?.setting) ||
        !identical(old?.autoDownload, clip?.autoDownload) ||
        oldWidget.manualLoadKey != widget.manualLoadKey) {
      _watch();
    }
    if (old?.cacheName != clip?.cacheName ||
        old?.localPath != clip?.localPath) {
      _failed = false;
      _release();
    }
    if (oldWidget.suspended != widget.suspended) _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unwatch();
    _AutoplayPool.forget(this);
    _disposeController();
    super.dispose();
  }

  void _watch() {
    _unwatch();
    final clip = widget.clip;
    final key = widget.manualLoadKey;
    _watched.addAll([
      ?clip?.setting,
      ?clip?.autoDownload,
      if (key != null) AutoDownloadGate.listen(key),
    ]);
    for (final listenable in _watched) {
      listenable.addListener(_sync);
    }
  }

  void _unwatch() {
    for (final listenable in _watched) {
      listenable.removeListener(_sync);
    }
    _watched.clear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _foreground = true;
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _foreground = false;
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        return;
    }
    _sync();
  }

  void _onVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction >= _visibleFraction;
    if (visible == _visible || !mounted) return;
    _visible = visible;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    if (!_allowed) {
      _release();
      return;
    }
    final controller = _controller;
    if (!_visible || !_foreground) {
      if (controller != null && controller.value.isPlaying) {
        unawaited(controller.pause());
      }
      return;
    }
    if (controller != null) {
      _AutoplayPool.touch(this);
      if (!controller.value.isPlaying) unawaited(controller.play());
      return;
    }
    _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<void> _open() async {
    final file = await _resolveFile();
    if (file == null || !mounted || !_allowed || !_visible) return;
    final controller = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
    } catch (e) {
      logger.w('MediaAutoplay: превью не открылось: $e');
      await controller.dispose();
      if (mounted) _failed = true;
      return;
    }
    if (!mounted || !_allowed) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onTick);
    setState(() => _controller = controller);
    _AutoplayPool.touch(this);
    _sync();
  }

  Future<File?> _resolveFile() async {
    final clip = widget.clip;
    if (clip == null) return null;
    final local = clip.localPath;
    if (local != null) {
      final file = File(local);
      return await file.exists() ? file : null;
    }
    final resolveUrl = clip.resolveUrl;
    if (resolveUrl == null) return null;
    try {
      return await VideoPreloader.load(
        clip.cacheName,
        resolveUrl,
        priority: true,
        cancelled: () => !mounted || !_visible,
        maxBytes: AutoplayClip.maxBytes,
      );
    } catch (e) {
      logger.w('MediaAutoplay: клип не скачался: $e');
      return null;
    }
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null || !mounted) return;
    final playing = value.isPlaying;
    final hasFrame = _hasFrame || value.position > Duration.zero;
    if (playing == _playing && hasFrame == _hasFrame) return;
    setState(() {
      _playing = playing;
      _hasFrame = hasFrame;
    });
  }

  void _release() {
    if (_controller == null) return;
    _AutoplayPool.forget(this);
    _disposeController();
    if (mounted) setState(() {});
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    _playing = false;
    _hasFrame = false;
    if (controller == null) return;
    controller.removeListener(_onTick);
    unawaited(controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    if (clip == null) {
      return widget.builder(context, const SizedBox.shrink(), false);
    }
    final controller = _controller;
    final surface = controller == null
        ? const SizedBox.shrink()
        : AnimatedOpacity(
            opacity: _hasFrame ? 1 : 0,
            duration: _fadeIn,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox.fromSize(
                size: _frameSize(controller.value.size, clip.frameSize),
                child: VideoPlayer(controller),
              ),
            ),
          );
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibility,
      child: widget.builder(context, surface, _playing && _hasFrame),
    );
  }

  static Size _frameSize(Size frame, Size fallback) =>
      frame.width.isFinite && frame.width > 0 && frame.height > 0
      ? frame
      : fallback;
}

class _AutoplayPool {
  static const int _maxLive = 4;
  static final List<_MediaAutoplayState> _live = [];

  static void touch(_MediaAutoplayState state) {
    _live
      ..remove(state)
      ..add(state);
    while (_live.length > _maxLive) {
      final evicted = _live.firstWhere(
        (candidate) => !candidate._visible,
        orElse: () => _live.first,
      );
      evicted._release();
    }
  }

  static void forget(_MediaAutoplayState state) => _live.remove(state);
}
