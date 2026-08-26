import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../small_spinner.dart';
import 'editor_common.dart';
import 'photo_hero.dart';
import 'video_edit.dart';

class VideoStill extends StatelessWidget {
  final ui.Image frame;
  final VideoGeometry geometry;
  final ColorAdjust adjust;
  final List<EditMark> marks;
  final Size marksCanvas;

  const VideoStill({
    super.key,
    required this.frame,
    required this.geometry,
    required this.adjust,
    this.marks = const [],
    this.marksCanvas = Size.zero,
  });

  @override
  Widget build(BuildContext context) {
    final local = geometry.withSource(
      Size(frame.width.toDouble(), frame.height.toDouble()),
    );
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(adjust.matrix()),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _StillPainter(frame, local)),
          if (adjust.vignette > 0)
            DecoratedBox(
              decoration: BoxDecoration(gradient: adjust.vignetteGradient()),
            ),
          if (marks.isNotEmpty && !marksCanvas.isEmpty)
            FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: marksCanvas.width,
                height: marksCanvas.height,
                child: CustomPaint(painter: DrawingPainter(marks: marks)),
              ),
            ),
        ],
      ),
    );
  }
}

class _StillPainter extends CustomPainter {
  final ui.Image frame;
  final VideoGeometry geometry;

  _StillPainter(this.frame, this.geometry);

  @override
  void paint(Canvas canvas, Size size) {
    final out = geometry.naturalOutput;
    if (out.isEmpty || size.isEmpty) return;
    canvas.clipRect(Offset.zero & size);
    canvas.save();
    canvas.scale(size.width / out.width, size.height / out.height);
    canvas.transform(geometry.sourceToOutput().storage);
    canvas.drawImage(
      frame,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StillPainter old) =>
      old.frame != frame || old.geometry != geometry;
}

Future<ui.Image?> composeVideoStill(
  ui.Image frame,
  VideoGeometry geometry,
  ColorAdjust adjust, {
  List<EditMark> marks = const [],
  Size marksCanvas = Size.zero,
}) async {
  final local = geometry.withSource(
    Size(frame.width.toDouble(), frame.height.toDouble()),
  );
  final out = local.naturalOutput;
  final width = out.width.round();
  final height = out.height.round();
  if (width <= 0 || height <= 0) return null;
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, out.width, out.height);
    canvas.saveLayer(
      rect,
      Paint()..colorFilter = ColorFilter.matrix(adjust.matrix()),
    );
    canvas.save();
    canvas.clipRect(rect);
    canvas.transform(local.sourceToOutput().storage);
    canvas.drawImage(
      frame,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
    canvas.restore();
    if (adjust.vignette > 0) {
      canvas.drawRect(
        rect,
        Paint()..shader = adjust.vignetteGradient().createShader(rect),
      );
    }
    if (marks.isNotEmpty && !marksCanvas.isEmpty) {
      canvas.save();
      canvas.scale(
        out.width / marksCanvas.width,
        out.height / marksCanvas.height,
      );
      DrawingPainter(marks: marks).paintMarks(canvas, marksCanvas);
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  } catch (_) {
    return null;
  }
}

class VideoCropEditor extends StatelessWidget {
  final ui.Image frame;
  final ColorAdjust adjust;
  final VideoCropEdit? initial;
  final Future<void> Function(VideoCropResult result)? onPreview;

  const VideoCropEditor({
    super.key,
    required this.frame,
    required this.adjust,
    this.initial,
    this.onPreview,
  });

  Future<Object?> _apply(
    CropState state,
    Size viewport,
    bool changed,
    bool identity,
  ) async {
    if (!changed && !identity) return null;
    final result = identity
        ? const VideoCropResult(null)
        : VideoCropResult(VideoCropEdit(state: state, viewport: viewport));
    await onPreview?.call(result);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return CropWorkspace(
      imageSize: Size(frame.width.toDouble(), frame.height.toDouble()),
      initialState: initial?.state,
      onApply: _apply,
      imageBuilder: (context, matrix) => ColorFiltered(
        colorFilter: ColorFilter.matrix(adjust.matrix()),
        child: CustomPaint(painter: MatrixImagePainter(frame, matrix)),
      ),
    );
  }
}

class VideoCropResult {
  final VideoCropEdit? crop;

  const VideoCropResult(this.crop);
}

class VideoMarksResult {
  final List<EditMark> marks;
  final Size canvas;

  const VideoMarksResult(this.marks, this.canvas);
}

class VideoDrawEditor extends StatelessWidget {
  final ui.Image frame;
  final VideoGeometry geometry;
  final ColorAdjust adjust;
  final List<EditMark> initialMarks;
  final Future<void> Function(VideoMarksResult result)? onPreview;

  const VideoDrawEditor({
    super.key,
    required this.frame,
    required this.geometry,
    required this.adjust,
    this.initialMarks = const [],
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final out = geometry.naturalOutput;
    return MarkupEditor(
      aspectRatio: out.height > 0 ? out.width / out.height : 1.0,
      initialMarks: initialMarks,
      background: VideoStill(frame: frame, geometry: geometry, adjust: adjust),
      onApply: (marks, canvas) async {
        final result = VideoMarksResult([...marks], canvas);
        await onPreview?.call(result);
        return result;
      },
    );
  }
}

class VideoAdjustEditor extends StatefulWidget {
  final ui.Image frame;
  final VideoGeometry geometry;
  final ColorAdjust initial;
  final List<EditMark> marks;
  final Size marksCanvas;
  final Future<void> Function(ColorAdjust result)? onPreview;

  const VideoAdjustEditor({
    super.key,
    required this.frame,
    required this.geometry,
    required this.initial,
    this.marks = const [],
    this.marksCanvas = Size.zero,
    this.onPreview,
  });

  @override
  State<VideoAdjustEditor> createState() => _VideoAdjustEditorState();
}

class _VideoAdjustEditorState extends State<VideoAdjustEditor> {
  late final ColorAdjust _adjust = widget.initial.copy();
  final ValueNotifier<int> _rev = ValueNotifier(0);
  bool _busy = false;

  Future<void> _done() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onPreview?.call(_adjust);
    if (!mounted) return;
    Navigator.of(context).pop(_adjust);
  }

  @override
  void dispose() {
    _rev.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final out = widget.geometry.naturalOutput;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: out.height > 0
                          ? out.width / out.height
                          : 1.0,
                      child: PhotoHeroTarget(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _rev,
                          builder: (context, _, _) => VideoStill(
                            frame: widget.frame,
                            geometry: widget.geometry,
                            adjust: _adjust,
                            marks: widget.marks,
                            marksCanvas: widget.marksCanvas,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _rev,
                  builder: (context, _, _) => AdjustSliders(
                    adjust: _adjust,
                    onChanged: () => _rev.value++,
                  ),
                ),
                Container(
                  color: kEditorPanel,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          l10n.photoEditorCancel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Symbols.tune, color: MediaAccent.of(context)),
                      const Spacer(),
                      TextButton(
                        onPressed: _busy ? null : _done,
                        child: Text(
                          l10n.photoEditorDone,
                          style: TextStyle(
                            color: _busy
                                ? Colors.white38
                                : MediaAccent.of(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_busy) const BusyOverlay(),
          ],
        ),
      ),
    );
  }
}

class VideoQualityEditor extends StatefulWidget {
  final ui.Image frame;
  final VideoGeometry geometry;
  final ColorAdjust adjust;
  final List<EditMark> marks;
  final Size marksCanvas;
  final List<int> options;
  final int selected;
  final double fps;
  final Duration duration;
  final String? title;
  final Future<void> Function(int result)? onPreview;

  const VideoQualityEditor({
    super.key,
    required this.frame,
    required this.geometry,
    required this.adjust,
    required this.options,
    required this.selected,
    this.marks = const [],
    this.marksCanvas = Size.zero,
    required this.fps,
    required this.duration,
    this.title,
    this.onPreview,
  });

  @override
  State<VideoQualityEditor> createState() => _VideoQualityEditorState();
}

class _VideoQualityEditorState extends State<VideoQualityEditor> {
  late int _index = math.max(0, widget.options.indexOf(widget.selected));
  bool _busy = false;

  Future<void> _done() async {
    if (_busy) return;
    final value = widget.options[_index];
    setState(() => _busy = true);
    await widget.onPreview?.call(value);
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  Size get _outputSize => widget.geometry.outputSize(widget.options[_index]);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final out = widget.geometry.naturalOutput;
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
          duration: widget.duration,
          bytes: estimateVideoSizeBytes(
            _outputSize,
            widget.fps,
            widget.duration,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: out.height > 0 ? out.width / out.height : 1.0,
                    child: PhotoHeroTarget(
                      child: VideoStill(
                        frame: widget.frame,
                        geometry: widget.geometry,
                        adjust: widget.adjust,
                        marks: widget.marks,
                        marksCanvas: widget.marksCanvas,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.videoEditorQualityLow,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            l10n.videoEditorQualityHigh,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _QualitySlider(
                      count: widget.options.length,
                      index: _index,
                      onChanged: (value) => setState(() => _index = value),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            l10n.photoEditorCancel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _done,
                          child: Text(
                            l10n.photoEditorDone,
                            style: TextStyle(
                              color: _busy
                                  ? Colors.white38
                                  : MediaAccent.of(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_busy) const BusyOverlay(),
        ],
      ),
    );
  }
}

class _QualitySlider extends StatelessWidget {
  final int count;
  final int index;
  final ValueChanged<int> onChanged;

  const _QualitySlider({
    required this.count,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accent = MediaAccent.of(context);
    return SizedBox(
      height: 40,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const inset = 16.0;
          final span = math.max(1.0, constraints.maxWidth - inset * 2);
          void pick(double dx) {
            if (count <= 1) return;
            final t = ((dx - inset) / span).clamp(0.0, 1.0);
            final next = (t * (count - 1)).round();
            if (next != index) onChanged(next);
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => pick(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
            child: CustomPaint(
              painter: _QualitySliderPainter(
                count: count,
                index: index,
                accent: accent,
                inset: inset,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QualitySliderPainter extends CustomPainter {
  final int count;
  final int index;
  final Color accent;
  final double inset;

  _QualitySliderPainter({
    required this.count,
    required this.index,
    required this.accent,
    required this.inset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final left = inset;
    final right = size.width - inset;
    final track = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(left, y),
      Offset(right, y),
      track..color = Colors.white24,
    );
    final step = count <= 1 ? 0.0 : (right - left) / (count - 1);
    final active = left + step * index;
    canvas.drawLine(Offset(left, y), Offset(active, y), track..color = accent);
    for (var i = 0; i < count; i++) {
      final x = left + step * i;
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = i <= index ? accent : Colors.white38,
      );
    }
    canvas.drawCircle(Offset(active, y), 9, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _QualitySliderPainter old) =>
      old.index != index || old.count != count || old.accent != accent;
}

class VideoHeaderTitle extends StatelessWidget {
  final String? title;
  final Size size;
  final Duration duration;
  final int bytes;

  const VideoHeaderTitle({
    super.key,
    required this.size,
    required this.duration,
    required this.bytes,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final name = title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (name != null && name.isNotEmpty)
          Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        Text(
          '${size.width.round()}x${size.height.round()}, '
          '${_duration(duration)}, ~${_bytes(bytes)}',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  static String _duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String _bytes(int value) {
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(value / 1024).toStringAsFixed(1)} KB';
  }
}
