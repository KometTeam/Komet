import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:komet/main.dart';

import '../../../../core/media/media_playback.dart';
import '../../../../core/media/video_note_frame.dart';
import '../../../../core/media/video_note_preloader.dart';
import '../../../../core/utils/format.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/media_cache.dart';
import '../../../../backend/modules/messages.dart'
    show TranscriptionCache, TranscriptionResult;
import '../../../../models/attachment.dart';
import '../../small_spinner.dart';
import '../../upload_progress_ring.dart';

class VideoNoteBubble extends StatefulWidget {
  final VideoAttachment attachment;
  final String messageId;
  final int chatId;
  final String? sourceMessageId;
  final int? sourceChatId;
  final int senderId;
  final bool isMe;
  final int time;
  final ColorScheme cs;
  final Color textColor;
  final Widget meta;
  final ValueListenable<List<double>>? uploadProgress;

  const VideoNoteBubble({
    super.key,
    required this.attachment,
    required this.messageId,
    required this.chatId,
    this.sourceMessageId,
    this.sourceChatId,
    required this.senderId,
    required this.isMe,
    required this.time,
    required this.cs,
    required this.textColor,
    required this.meta,
    this.uploadProgress,
  });

  @override
  State<VideoNoteBubble> createState() => _VideoNoteBubbleState();
}

class _VideoNoteBubbleState extends State<VideoNoteBubble>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const double _baseSize = 210;
  static const double _expandedScale = 1.7;
  static const Duration _expandDuration = Duration(milliseconds: 280);
  static const Duration _swapDuration = Duration(milliseconds: 220);

  static _VideoNoteBubbleState? _playingNote;

  late final AnimationController _expand;
  final ValueNotifier<double> _ringProgress = ValueNotifier(0);
  Uint8List? _preview;
  Size _frameSize = Size.zero;
  VideoPlayerController? _controller;
  VideoPlayerController? _local;
  Future<void>? _initializing;
  Duration? _pendingSeek;
  double? _lastAngle;
  bool _playing = false;
  bool _loading = false;
  bool _error = false;
  bool _scrubbing = false;
  bool _seekInFlight = false;
  bool _resumeAfterScrub = false;
  bool _muted = false;
  bool _visible = false;
  bool _retriedCache = false;
  bool _transcriptionLoading = false;
  bool _transcriptionVisible = false;
  String? _transcriptionText;

  static const double _visibleFraction = 0.6;

  String get _sourceMessageId => widget.sourceMessageId ?? widget.messageId;
  int get _sourceChatId => widget.sourceChatId ?? widget.chatId;

  int? get _videoId => widget.attachment.videoId;
  String get _cacheName => 'videonote_$_videoId.mp4';
  int get _attachmentDurationMs => widget.attachment.duration ?? 0;
  String? get _localPath => widget.attachment.localPath;

  String? get _posterUrl {
    for (final candidate in [
      widget.attachment.thumbnail,
      widget.attachment.baseUrl,
    ]) {
      if (candidate == null || candidate.isEmpty) continue;
      if (candidate.startsWith('data:')) continue;
      return candidate;
    }
    return null;
  }

  bool get _ready {
    final controller = _controller;
    return controller != null &&
        controller.value.isInitialized &&
        !controller.value.hasError;
  }

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(vsync: this, duration: _expandDuration);
    _preview = _previewBytes(widget.attachment.previewData);
    TranscriptionCache.listen(_sourceMessageId, _onTranscriptionPush);
    _adoptCachedTranscription();
    WidgetsBinding.instance.addObserver(this);
    final local = _localPath;
    if (local != null) {
      unawaited(_openLocalPreview(File(local)));
      return;
    }
    if (VideoNotePreloader.autoLoads(widget.attachment.duration)) {
      unawaited(_warmCache());
    }
  }

  @override
  void didUpdateWidget(VideoNoteBubble old) {
    super.didUpdateWidget(old);
    if (old.attachment.previewData != widget.attachment.previewData) {
      _preview = _previewBytes(widget.attachment.previewData);
    }
    if (old.attachment.localPath != _localPath) _dropLocalPreview();
  }

  @override
  void dispose() {
    TranscriptionCache.unlisten(_sourceMessageId, _onTranscriptionPush);
    WidgetsBinding.instance.removeObserver(this);
    if (_playingNote == this) _playingNote = null;
    _PreviewPool.unregister(this);
    _expand.dispose();
    _ringProgress.dispose();
    _dropLocalPreview();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onTick);
      MediaPlayback.instance.releaseVideoNote(controller);
    }
    super.dispose();
  }

  Future<void> _openLocalPreview(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
    } catch (e) {
      logger.w('VideoNoteBubble: локальное превью не открылось: $e');
      await controller.dispose();
      return;
    }
    if (!mounted || file.path != _localPath) {
      await controller.dispose();
      return;
    }
    await controller.setVolume(0);
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _local = controller);
  }

  void _dropLocalPreview() {
    final local = _local;
    if (local == null) return;
    _local = null;
    unawaited(local.dispose());
  }

  void _claimPlayback() {
    final controller = _controller;
    if (controller == null) return;
    MediaPlayback.instance.activateVideoNote(
      VideoNoteTrack(
        cacheName: _cacheName,
        chatId: widget.chatId,
        messageId: widget.messageId,
        senderId: widget.senderId,
        isMe: widget.isMe,
        time: widget.time,
        controller: controller,
        preview: _preview,
      ),
    );
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
    if (value.size != _frameSize || value.isPlaying != _playing) {
      setState(() {
        _frameSize = value.size;
        _playing = value.isPlaying;
      });
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

  Future<void> _warmCache() => _fetch(priority: false);

  Future<File?> _fetch({required bool priority}) {
    final videoId = _videoId;
    final token = widget.attachment.videoToken;
    if (videoId == null || token == null) return Future.value(null);
    return VideoNotePreloader.load(
      _cacheName,
      () => messagesModule.getVideoUrl(
        messageId: widget.sourceMessageId ?? widget.messageId,
        chatId: widget.sourceChatId ?? widget.chatId,
        token: token,
        videoId: videoId,
      ),
      priority: priority,
      cancelled: priority ? null : () => !mounted,
    );
  }

  Future<VideoPlayerController?> _ensureController(File file) async {
    if (!mounted) return null;
    if (_controller != null) return _controller;
    final live = MediaPlayback.instance.liveVideoNote(_cacheName);
    if (live != null) {
      _controller = live;
      live.addListener(_onTick);
      _PreviewPool.pin(this);
      if (mounted) setState(() => _frameSize = live.value.size);
      return live;
    }
    final running = _initializing;
    if (running != null) {
      try {
        await running;
      } catch (_) {}
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
      return null;
    } finally {
      if (identical(_initializing, future)) _initializing = null;
    }

    if (!mounted) {
      await controller.dispose();
      return null;
    }

    _controller = controller;
    MediaPlayback.instance.holdVideoNote(controller);
    await controller.setLooping(true);
    await controller.seekTo(Duration.zero);
    controller.addListener(_onTick);
    _PreviewPool.register(this);
    if (mounted) setState(() => _frameSize = controller.value.size);
    return controller;
  }

  void _releasePreview() {
    final controller = _controller;
    if (controller == null) return;
    if (MediaPlayback.instance.isActiveVideoNote(controller)) return;
    _controller = null;
    controller.removeListener(_onTick);
    MediaPlayback.instance.releaseVideoNote(controller);
    if (mounted) setState(() => _frameSize = Size.zero);
  }

  // #***! файл из кэша могли вычистить прямо под играющим контроллером,
  // после такой ошибки он уже не оживает — выбрасываем и качаем заново
  void _dropFailedController() {
    final controller = _controller;
    if (controller == null || !controller.value.hasError) return;
    logger.w('VideoNoteBubble: ${controller.value.errorDescription}');
    if (MediaPlayback.instance.isActiveVideoNote(controller)) {
      MediaPlayback.instance.closeVideoNote();
    }
    if (_playingNote == this) _playingNote = null;
    _controller = null;
    controller.removeListener(_onTick);
    _PreviewPool.unregister(this);
    MediaPlayback.instance.releaseVideoNote(controller);
    _frameSize = Size.zero;
    _playing = false;
    _ringProgress.value = 0;
  }

  Future<VideoPlayerController?> _openController() async {
    try {
      final file = await _fetch(priority: true);
      if (!mounted || file == null) return null;
      final controller = await _ensureController(file);
      if (controller != null || !mounted || _retriedCache) return controller;
      _retriedCache = true;
      logger.w('VideoNoteBubble: файл в кэше не открылся, качаю заново');
      await MediaCache.discard(_cacheName);
      final fresh = await _fetch(priority: true);
      if (!mounted || fresh == null) return null;
      return await _ensureController(fresh);
    } catch (e) {
      logger.w('VideoNoteBubble: кружок не открылся: $e');
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_visible) unawaited(_startMuted());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_stopMuted());
    }
  }

  void _onVisibility(VisibilityInfo info) {
    final visible = info.visibleFraction >= _visibleFraction;
    if (visible == _visible || !mounted) return;
    _visible = visible;
    unawaited(visible ? _startMuted() : _stopMuted());
  }

  Future<void> _startMuted() async {
    if (_videoId == null ||
        widget.uploadProgress != null ||
        _local != null ||
        _error ||
        _loading) {
      return;
    }
    final existing = _controller;
    if (existing != null && existing.value.isPlaying) return;
    final controller = existing ?? await _openController();
    if (controller == null || !mounted || !_visible) return;
    if (controller.value.isPlaying ||
        MediaPlayback.instance.isActiveVideoNote(controller)) {
      return;
    }
    await controller.setVolume(0);
    _muted = true;
    await controller.play();
    if (mounted) setState(() {});
  }

  Future<void> _stopMuted() async {
    final controller = _controller;
    if (!_muted || controller == null) return;
    await controller.pause();
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (_videoId == null) return;
    _dropFailedController();
    if (_ready) {
      final controller = _controller!;
      if (_muted) {
        _muted = false;
        await controller.seekTo(Duration.zero);
        await _play();
      } else if (controller.value.isPlaying) {
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

    final controller = await _openController();
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = controller == null;
    });
    if (controller != null) {
      _muted = false;
      await _play();
    }
  }

  void _adoptCachedTranscription() {
    final cached = TranscriptionCache.get(_sourceMessageId);
    if (cached == null || cached.status != 1) return;
    _transcriptionText = cached.text ?? TranscriptionResult.emptyText;
    _transcriptionVisible = TranscriptionCache.isExpanded(_sourceMessageId);
  }

  void _onTranscriptionPush() {
    if (!mounted) return;
    setState(() {
      _transcriptionLoading = false;
      _adoptCachedTranscription();
    });
  }

  void _showTranscription(String text) {
    _transcriptionText = text;
    _transcriptionVisible = true;
    TranscriptionCache.setExpanded(_sourceMessageId, true);
  }

  Future<void> _requestTranscription() async {
    final videoId = _videoId;
    if (videoId == null || _transcriptionLoading) return;
    Haptics.tap();
    if (_transcriptionVisible && _transcriptionText != null) {
      setState(() {
        _transcriptionVisible = false;
        TranscriptionCache.setExpanded(_sourceMessageId, false);
      });
      return;
    }
    final cached = TranscriptionCache.get(_sourceMessageId);
    if (cached != null && cached.status == 1) {
      setState(
        () => _showTranscription(cached.text ?? TranscriptionResult.emptyText),
      );
      return;
    }

    setState(() => _transcriptionLoading = true);
    try {
      final result = await messagesModule.requestTranscription(
        _sourceChatId,
        int.tryParse(_sourceMessageId) ?? 0,
        videoId,
      );
      TranscriptionCache.put(_sourceMessageId, result);
      if (!mounted) return;
      setState(() {
        _transcriptionLoading = false;
        if (result.status == 1) {
          final text = result.text;
          _showTranscription(
            text == null || text.isEmpty ? TranscriptionResult.emptyText : text,
          );
        } else if (result.status == 0) {
          _transcriptionLoading = true;
        } else {
          _showTranscription('Не удалось распознать');
        }
      });
    } catch (e) {
      logger.w('VideoNoteBubble._requestTranscription: $e');
      if (!mounted) return;
      setState(() {
        _transcriptionLoading = false;
        _showTranscription('Не удалось распознать');
      });
    }
  }

  Future<void> _play() async {
    if (_controller == null) return;
    _PreviewPool.pin(this);
    final other = _playingNote;
    if (other != null && other != this) await other._pause();
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    _muted = false;
    _playingNote = this;
    _claimPlayback();
    await controller.setVolume(1);
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
                VisibilityDetector(
                  key: ValueKey('note-visibility-${widget.messageId}'),
                  onVisibilityChanged: _onVisibility,
                  child: _buildCircle(size),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _transcriptionVisible
                      ? _buildTranscription(size)
                      : const SizedBox(width: 0),
                ),
                const SizedBox(height: 6),
                SizedBox(width: size, child: _buildMetaRow()),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTranscription(double size) {
    return Container(
      width: size,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.cs.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      constraints: const BoxConstraints(maxHeight: 132),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Text(
          _transcriptionText ?? '',
          style: TextStyle(
            color: widget.textColor.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildTranscribeButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _requestTranscription,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
        ),
        child: _transcriptionLoading
            ? const SmallSpinner(size: 14, color: Colors.white)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _transcriptionVisible
                        ? Symbols.keyboard_arrow_up
                        : Symbols.arrow_right_alt,
                    size: 15,
                    color: Colors.white,
                  ),
                  const Text(
                    'T',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMutedBadge() {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Colors.black45,
        shape: BoxShape.circle,
      ),
      child: const Icon(Symbols.volume_off, size: 17, color: Colors.white),
    );
  }

  Widget _buildCircle(double size) {
    final ready = _ready;
    final muted = ready && _muted;
    final playing = ready && _playing && !_scrubbing;
    final preview = _preview;
    final local = _local;
    final uploading = widget.uploadProgress;

    return GestureDetector(
      onTap: uploading == null ? _toggle : null,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: ClipOval(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: AnimatedSwitcher(
                    duration: _swapDuration,
                    child: ready
                        ? _videoSurface(
                            _controller!,
                            const ValueKey('note-video'),
                            size,
                          )
                        : local != null && local.value.isInitialized
                        ? _videoSurface(
                            local,
                            const ValueKey('note-local'),
                            size,
                          )
                        : _buildPoster(preview),
                  ),
                ),
              ),
            ),
            if (uploading != null) ...[
              Positioned.fill(
                child: ClipOval(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
              ),
              UploadProgressRing(
                progress: uploading,
                color: Colors.white,
                trackColor: Colors.white24,
              ),
            ] else ...[
              if (ready && !muted) _buildRing(size),
              if (muted && playing)
                Positioned(bottom: 12, child: _buildMutedBadge()),
              if (_videoId != null && _local == null)
                Positioned(top: 0, right: 0, child: _buildTranscribeButton()),
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
          ],
        ),
      ),
    );
  }

  Widget _buildPoster(Uint8List? preview) {
    final url = _posterUrl;
    if (url == null) {
      return _inlinePreview(preview, const ValueKey('note-preview'));
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox.expand(
      key: const ValueKey('note-poster'),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: (_baseSize * dpr).round(),
        fadeInDuration: _swapDuration,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (_, _) => _inlinePreview(preview, null),
        errorWidget: (_, _, _) => _inlinePreview(preview, null),
      ),
    );
  }

  Widget _inlinePreview(Uint8List? preview, Key? key) {
    if (preview == null) {
      return SizedBox.expand(
        key: key,
        child: ColoredBox(color: widget.cs.surfaceContainerHighest),
      );
    }
    return SizedBox.expand(
      key: key,
      child: Image.memory(
        preview,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  Widget _videoSurface(
    VideoPlayerController controller,
    Key key,
    double fallback,
  ) {
    final frame = videoNoteFrameSize(controller.value.size, fallback);
    return SizedBox.expand(
      key: key,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: frame.width,
          height: frame.height,
          child: VideoPlayer(controller),
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
