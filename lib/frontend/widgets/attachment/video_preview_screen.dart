import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:video_player/video_player.dart';

import 'package:komet/core/media/gallery_source.dart';
import 'package:komet/core/media/video_transcoder.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/lottie_slash_icon.dart';

import '../../../core/config/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../small_spinner.dart';
import 'editor_common.dart';
import 'photo_hero.dart';
import 'preview_chrome.dart';
import 'video_edit.dart';
import 'video_editor.dart';

const int _kStripFrames = 12;

class VideoPreviewScreen extends StatefulWidget {
  final GalleryItem item;
  final PhotoHeroController hero;
  final String? title;
  final ValueListenable<Set<String>> selectedIds;
  final VoidCallback onToggleSelection;
  final VoidCallback onSend;
  final VideoEditState edit;
  final bool editable;
  final VoidCallback? onEditChanged;
  final String initialCaption;
  final ValueChanged<String>? onCaptionChanged;

  const VideoPreviewScreen({
    super.key,
    required this.item,
    required this.hero,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onSend,
    required this.edit,
    this.editable = true,
    this.title,
    this.onEditChanged,
    this.initialCaption = '',
    this.onCaptionChanged,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late final TextEditingController _caption = TextEditingController(
    text: widget.initialCaption,
  );

  final GlobalKey _stageKey = GlobalKey();
  final List<ui.Image> _flightImages = [];

  PhotoHeroController? _activeHero;
  ui.Image? _editorFrame;

  File? _file;
  VideoInfo? _info;
  VideoPlayerController? _controller;
  List<Uint8List?> _strip = const [];
  int _sourceBytes = 0;
  bool _busy = false;
  bool _scrubbing = false;

  VideoEditState get _edit => widget.edit;

  @override
  void initState() {
    super.initState();
    _caption.addListener(() => widget.onCaptionChanged?.call(_caption.text));
    _load();
  }

  @override
  void dispose() {
    _releaseFlights();
    _caption.dispose();
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onTick);
    controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final file = widget.item.localFile ?? await widget.item.originFile();
    if (file == null || !mounted) return;
    _file = file;
    _sourceBytes = await file.length().catchError((_) => 0);
    _info = await VideoTranscoder.probe(file.path);
    if (!mounted) return;
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
    } catch (_) {
      controller.dispose();
      if (mounted) {
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.videoEditorFrameFailed,
        );
      }
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    final duration = _duration(controller);
    if (_edit.end <= Duration.zero) {
      _edit.sourceDuration = duration;
      _edit.end = duration;
    }
    controller.addListener(_onTick);
    await controller.setVolume(_edit.muted ? 0 : 1);
    setState(() => _controller = controller);
    unawaited(controller.play());
    unawaited(_loadStrip(file, duration));
  }

  Duration _duration(VideoPlayerController controller) {
    final info = _info;
    if (info != null && info.durationMs > 0) {
      return Duration(milliseconds: info.durationMs);
    }
    return controller.value.duration;
  }

  Future<void> _loadStrip(File file, Duration duration) async {
    if (duration <= Duration.zero) return;
    final step = duration.inMilliseconds / _kStripFrames;
    final times = List<int>.generate(
      _kStripFrames,
      (i) => (step * (i + 0.5)).round(),
    );
    final frames = await VideoTranscoder.frames(file.path, times, size: 160);
    if (!mounted) return;
    setState(() => _strip = frames);
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_scrubbing) return;
    final position = controller.value.position;
    if (position >= _edit.end && _edit.end > Duration.zero) {
      controller.seekTo(_edit.start);
      if (!controller.value.isPlaying) unawaited(controller.play());
    } else if (position < _edit.start - const Duration(milliseconds: 120)) {
      controller.seekTo(_edit.start);
    }
  }

  Size get _sourceSize {
    final info = _info;
    if (info != null && info.width > 0 && info.height > 0) {
      return Size(info.width.toDouble(), info.height.toDouble());
    }
    final size = _controller?.value.size ?? Size.zero;
    return size.isEmpty ? const Size(16, 9) : size;
  }

  double get _fps => _info?.fps ?? 30;

  VideoGeometry get _geometry => VideoGeometry.resolve(_edit.crop, _sourceSize);

  Size get _outputSize => _geometry.outputSize(_edit.maxShortSide);

  int get _naturalShortSide {
    final natural = _geometry.naturalOutput;
    return math.max(2, math.min(natural.width, natural.height).round());
  }

  void _changed() {
    setState(() {});
    widget.onEditChanged?.call();
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      if (controller.value.position >= _edit.end) {
        controller.seekTo(_edit.start);
      }
      controller.play();
    }
    setState(() {});
  }

  void _toggleMute() {
    _edit.muted = !_edit.muted;
    _controller?.setVolume(_edit.muted ? 0 : 1);
    _changed();
  }

  void _send() {
    Navigator.of(context).pop();
    widget.onSend();
  }

  Future<T?> _pushEditor<T>(
    (ui.Image, ui.Image) prepared,
    Widget Function() builder,
  ) async {
    final (frame, flight) = prepared;
    final hero = PhotoHeroController(
      origin: () => photoHeroRect(_stageKey),
      image: RawImageProvider(flight),
    );
    _activeHero = hero;
    _editorFrame = frame;
    _flightImages.add(flight);
    try {
      return await Navigator.of(
        context,
      ).push<T>(PhotoHeroRoute<T>(hero: hero, builder: (_) => builder()));
    } finally {
      _activeHero = null;
      _editorFrame = null;
      frame.dispose();
      _releaseFlights();
    }
  }

  void _releaseFlights() {
    if (_flightImages.isEmpty) return;
    final images = List<ui.Image>.of(_flightImages);
    _flightImages.clear();
    for (final image in images) {
      unawaited(RawImageProvider(image).evict());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final image in images) {
        image.dispose();
      }
    });
  }

  Future<void> _preview(
    void Function() apply, {
    required bool withMarks,
  }) async {
    apply();
    if (!mounted) return;
    setState(() {});
    widget.onEditChanged?.call();
    final frame = _editorFrame;
    final hero = _activeHero;
    if (frame == null || hero == null) return;
    final image = await composeVideoStill(
      frame,
      _geometry,
      _edit.adjust,
      marks: withMarks ? _edit.marks : const [],
      marksCanvas: withMarks ? _edit.marksCanvas : Size.zero,
    );
    if (image == null) return;
    if (!mounted || !identical(_activeHero, hero)) {
      image.dispose();
      return;
    }
    _flightImages.add(image);
    hero.image.value = RawImageProvider(image);
  }

  Future<ui.Image?> _grabFrame() async {
    final file = _file;
    if (file == null) return null;
    final position = _controller?.value.position ?? _edit.start;
    final frames = await VideoTranscoder.frames(
      file.path,
      [
        position.inMilliseconds.clamp(
          _edit.start.inMilliseconds,
          math.max(_edit.start.inMilliseconds, _edit.end.inMilliseconds),
        ),
      ],
      size: 1280,
      precise: true,
    );
    final data = frames.isEmpty ? null : frames.first;
    if (data == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  Future<(ui.Image, ui.Image)?> _prepare({required bool withMarks}) async {
    _controller?.pause();
    setState(() => _busy = true);
    final frame = await _grabFrame();
    ui.Image? flight;
    if (frame != null) {
      flight = await composeVideoStill(
        frame,
        _geometry,
        _edit.adjust,
        marks: withMarks ? _edit.marks : const [],
        marksCanvas: withMarks ? _edit.marksCanvas : Size.zero,
      );
    }
    if (!mounted) {
      frame?.dispose();
      flight?.dispose();
      return null;
    }
    setState(() => _busy = false);
    if (frame == null || flight == null) {
      frame?.dispose();
      flight?.dispose();
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.videoEditorFrameFailed,
      );
      return null;
    }
    return (frame, flight);
  }

  Future<void> _openCrop() async {
    final prepared = await _prepare(withMarks: false);
    if (prepared == null) return;
    await _pushEditor<VideoCropResult>(
      prepared,
      () => VideoCropEditor(
        frame: prepared.$1,
        adjust: _edit.adjust,
        initial: _edit.crop,
        onPreview: (result) =>
            _preview(() => _edit.crop = result.crop, withMarks: true),
      ),
    );
  }

  Future<void> _openDraw() async {
    final prepared = await _prepare(withMarks: true);
    if (prepared == null) return;
    await _pushEditor<VideoMarksResult>(
      prepared,
      () => VideoDrawEditor(
        frame: prepared.$1,
        geometry: _geometry,
        adjust: _edit.adjust,
        initialMarks: _edit.marks,
        onPreview: (result) => _preview(() {
          _edit.marks = result.marks;
          _edit.marksCanvas = result.canvas;
        }, withMarks: true),
      ),
    );
  }

  Future<void> _openAdjust() async {
    final prepared = await _prepare(withMarks: true);
    if (prepared == null) return;
    await _pushEditor<ColorAdjust>(
      prepared,
      () => VideoAdjustEditor(
        frame: prepared.$1,
        geometry: _geometry,
        initial: _edit.adjust,
        marks: _edit.marks,
        marksCanvas: _edit.marksCanvas,
        onPreview: (result) =>
            _preview(() => _edit.adjust = result, withMarks: true),
      ),
    );
  }

  Future<void> _openQuality() async {
    final prepared = await _prepare(withMarks: true);
    if (prepared == null) return;
    final natural = _naturalShortSide;
    final options = videoQualityOptions(natural);
    await _pushEditor<int>(
      prepared,
      () => VideoQualityEditor(
        frame: prepared.$1,
        geometry: _geometry,
        adjust: _edit.adjust,
        marks: _edit.marks,
        marksCanvas: _edit.marksCanvas,
        options: options,
        selected: _edit.maxShortSide ?? natural,
        fps: _fps,
        duration: _edit.duration,
        title: widget.title,
        onPreview: (result) => _preview(
          () => _edit.maxShortSide = result >= natural ? null : result,
          withMarks: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: VideoHeaderTitle(
          title: widget.title,
          size: _outputSize,
          duration: _edit.duration,
          bytes: _edit.hasEdits
              ? estimateVideoSizeBytes(_outputSize, _fps, _edit.duration)
              : _sourceBytes,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: PreviewSelectionToggle(
              selectedIds: widget.selectedIds,
              id: widget.item.id,
              onTap: widget.onToggleSelection,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: PhotoHeroTarget(child: Center(child: _stage())),
              ),
              _bottomBar(),
            ],
          ),
          if (_busy) const BusyOverlay(),
        ],
      ),
    );
  }

  Widget _stage() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SmallSpinner(size: 36, color: Colors.white24);
    }
    final output = _geometry.naturalOutput;
    if (output.isEmpty) return const SizedBox.shrink();
    return AspectRatio(
      key: _stageKey,
      aspectRatio: output.width / output.height,
      child: GestureDetector(
        onTap: _togglePlay,
        behavior: HitTestBehavior.opaque,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = constraints.maxWidth / output.width;
            final matrix = Matrix4.diagonal3Values(scale, scale, 1)
              ..multiply(_geometry.sourceToOutput());
            final source = _sourceSize;
            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: ColorFilter.matrix(_edit.adjust.matrix()),
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: 0,
                      minHeight: 0,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Transform(
                        alignment: Alignment.topLeft,
                        transform: matrix,
                        child: SizedBox(
                          width: source.width,
                          height: source.height,
                          child: VideoPlayer(controller),
                        ),
                      ),
                    ),
                  ),
                  if (_edit.adjust.vignette > 0)
                    IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: _edit.adjust.vignetteGradient(),
                        ),
                      ),
                    ),
                  if (_edit.marks.isNotEmpty && !_edit.marksCanvas.isEmpty)
                    IgnorePointer(
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                          width: _edit.marksCanvas.width,
                          height: _edit.marksCanvas.height,
                          child: CustomPaint(
                            painter: DrawingPainter(marks: _edit.marks),
                          ),
                        ),
                      ),
                    ),
                  if (!controller.value.isPlaying)
                    const IgnorePointer(child: Center(child: _PlayBadge())),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final controller = _controller;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.editable) ...[
              Row(
                children: [
                  _MuteButton(muted: _edit.muted, onTap: _toggleMute),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 4),
            ],
            if (widget.editable &&
                controller != null &&
                controller.value.isInitialized)
              TrimBar(
                frames: _strip,
                controller: controller,
                duration: _edit.sourceDuration,
                start: _edit.start,
                end: _edit.end,
                onScrub: _onScrub,
                onTrim: _onTrim,
              ),
            const SizedBox(height: 10),
            _captionField(),
            const SizedBox(height: 10),
            _toolbar(),
          ],
        ),
      ),
    );
  }

  void _onScrub(Duration position, bool active) {
    _scrubbing = active;
    final controller = _controller;
    if (controller == null) return;
    if (active && controller.value.isPlaying) controller.pause();
    controller.seekTo(position);
  }

  void _onTrim(Duration start, Duration end, bool active) {
    _scrubbing = active;
    setState(() {
      _edit.start = start;
      _edit.end = end;
    });
    if (!active) widget.onEditChanged?.call();
  }

  Widget _captionField() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: kEditorBar,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _caption,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: l10n.videoEditorCaptionHint,
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<Set<String>>(
            valueListenable: widget.selectedIds,
            builder: (context, selected, _) => PreviewCountBadge(
              count: selected.isEmpty ? 1 : selected.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar() {
    final ready = _controller?.value.isInitialized == true;
    if (!widget.editable) {
      return Row(
        children: [
          const Spacer(),
          PreviewSendButton(onTap: _send),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: kEditorBar,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                PreviewToolIcon(
                  icon: Symbols.crop_rotate,
                  onTap: ready ? _openCrop : () {},
                ),
                PreviewToolIcon(
                  icon: Symbols.brush,
                  onTap: ready ? _openDraw : () {},
                ),
                _QualityBadge(
                  shortSide: _edit.maxShortSide ?? _naturalShortSide,
                  onTap: ready ? _openQuality : () {},
                ),
                PreviewToolIcon(
                  icon: Symbols.tune,
                  onTap: ready ? _openAdjust : () {},
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        PreviewSendButton(onTap: _send),
      ],
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.45),
      ),
      child: const Icon(
        Symbols.play_arrow,
        color: Colors.white,
        size: 34,
        fill: 1,
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  final bool muted;
  final VoidCallback onTap;

  const _MuteButton({required this.muted, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: AppLocalizations.of(context)!.videoEditorMuteTooltip,
      icon: LottieSlashIcon(
        asset: 'assets/lottie/ic_volume_on_to_off.json',
        slashed: muted,
        color: muted ? MediaAccent.of(context) : Colors.white,
        size: 26,
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  final int shortSide;
  final VoidCallback onTap;

  const _QualityBadge({required this.shortSide, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: AppLocalizations.of(context)!.videoEditorQualityTooltip,
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$shortSide',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              height: 1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Icon(Symbols.hd, color: Colors.white, size: 22, fill: 1),
        ],
      ),
    );
  }
}

class TrimBar extends StatefulWidget {
  final List<Uint8List?> frames;
  final VideoPlayerController controller;
  final Duration duration;
  final Duration start;
  final Duration end;
  final void Function(Duration position, bool active) onScrub;
  final void Function(Duration start, Duration end, bool active) onTrim;

  const TrimBar({
    super.key,
    required this.frames,
    required this.controller,
    required this.duration,
    required this.start,
    required this.end,
    required this.onScrub,
    required this.onTrim,
  });

  @override
  State<TrimBar> createState() => _TrimBarState();
}

class _TrimBarState extends State<TrimBar> {
  static const double _handle = 13;
  static const double _height = 48;

  int _target = -1;

  double _fraction(Duration value) {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (value.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration _at(double fraction) => Duration(
    milliseconds: (fraction.clamp(0.0, 1.0) * widget.duration.inMilliseconds)
        .round(),
  );

  void _down(Offset pos, double width) {
    final startX = _fraction(widget.start) * width;
    final endX = _fraction(widget.end) * width;
    final toStart = (pos.dx - startX).abs();
    final toEnd = (pos.dx - endX).abs();
    if (toStart <= toEnd && toStart < 28) {
      _target = 0;
    } else if (toEnd < 28) {
      _target = 1;
    } else {
      _target = 2;
      widget.onScrub(_clamp(_at(pos.dx / width)), true);
    }
  }

  Duration _clamp(Duration value) {
    if (value < widget.start) return widget.start;
    if (widget.end > Duration.zero && value > widget.end) return widget.end;
    return value;
  }

  void _move(Offset pos, double width) {
    if (width <= 0) return;
    final value = _at(pos.dx / width);
    switch (_target) {
      case 0:
        final limit = widget.end - kMinTrimDuration;
        widget.onTrim(
          value > limit
              ? (limit > Duration.zero ? limit : Duration.zero)
              : value,
          widget.end,
          true,
        );
        widget.onScrub(value, true);
      case 1:
        final limit = widget.start + kMinTrimDuration;
        widget.onTrim(widget.start, value < limit ? limit : value, true);
        widget.onScrub(value < limit ? limit : value, true);
      case 2:
        widget.onScrub(_clamp(value), true);
    }
  }

  void _up() {
    if (_target < 0) return;
    if (_target != 2) widget.onTrim(widget.start, widget.end, false);
    widget.onScrub(_clamp(widget.controller.value.position), false);
    _target = -1;
  }

  @override
  Widget build(BuildContext context) {
    final accent = MediaAccent.of(context);
    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final startX = _fraction(widget.start) * width;
          final endX = _fraction(widget.end) * width;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _down(d.localPosition, width),
            onPanUpdate: (d) => _move(d.localPosition, width),
            onPanEnd: (_) => _up(),
            onPanCancel: _up,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  Positioned.fill(child: _filmstrip()),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: math.max(0, startX),
                    child: const ColoredBox(color: Color(0x99000000)),
                  ),
                  Positioned(
                    left: endX,
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: const ColoredBox(color: Color(0x99000000)),
                  ),
                  Positioned(
                    left: startX,
                    right: math.max(0, width - endX),
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal: BorderSide(color: accent, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: widget.controller,
                    child: const IgnorePointer(child: _Playhead()),
                    builder: (context, value, child) => Positioned(
                      left: (_fraction(value.position) * width - 1.5).clamp(
                        0.0,
                        math.max(0, width - 3),
                      ),
                      top: 2,
                      bottom: 2,
                      width: 3,
                      child: child!,
                    ),
                  ),
                  Positioned(
                    left: (startX - _handle).clamp(0.0, width),
                    top: 0,
                    bottom: 0,
                    width: _handle,
                    child: _Handle(color: accent, leading: true),
                  ),
                  Positioned(
                    left: endX.clamp(0.0, math.max(0, width - _handle)),
                    top: 0,
                    bottom: 0,
                    width: _handle,
                    child: _Handle(color: accent, leading: false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filmstrip() {
    if (widget.frames.isEmpty) {
      return const ColoredBox(color: Color(0xFF1E1E1E));
    }
    return Row(
      children: [
        for (final frame in widget.frames)
          Expanded(
            child: frame == null
                ? const ColoredBox(color: Color(0xFF1E1E1E))
                : Image.memory(
                    frame,
                    fit: BoxFit.cover,
                    height: double.infinity,
                    gaplessPlayback: true,
                  ),
          ),
      ],
    );
  }
}

class _Playhead extends StatelessWidget {
  const _Playhead();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final Color color;
  final bool leading;

  const _Handle({required this.color, required this.leading});

  @override
  Widget build(BuildContext context) {
    final radius = leading
        ? const BorderRadius.horizontal(left: Radius.circular(8))
        : const BorderRadius.horizontal(right: Radius.circular(8));
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: radius),
      child: Center(
        child: Container(
          width: 2,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
