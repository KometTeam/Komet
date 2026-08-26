import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/media/video_transcoder.dart';
import 'editor_common.dart';

const List<int> kVideoQualitySteps = [144, 240, 360, 480, 720, 1080];

const Duration kMinTrimDuration = Duration(milliseconds: 800);

class VideoCropEdit {
  final CropState state;
  final Size viewport;

  const VideoCropEdit({required this.state, required this.viewport});
}

class VideoEditState {
  Duration start = Duration.zero;
  Duration end = Duration.zero;
  bool muted = false;
  VideoCropEdit? crop;
  List<EditMark> marks = [];
  Size marksCanvas = Size.zero;
  ColorAdjust adjust = ColorAdjust();
  int? maxShortSide;

  File? exported;
  String? exportedSignature;

  bool get trimmed =>
      start > Duration.zero ||
      (sourceDuration > Duration.zero && end < sourceDuration);

  Duration sourceDuration = Duration.zero;

  Duration get duration {
    final span = end - start;
    return span > Duration.zero ? span : Duration.zero;
  }

  bool get hasEdits =>
      trimmed ||
      muted ||
      crop != null ||
      marks.isNotEmpty ||
      !adjust.pristine ||
      maxShortSide != null;

  String signature(Size source) {
    final geometry = VideoGeometry.resolve(crop, source);
    final out = geometry.outputSize(maxShortSide);
    final m = adjust.matrix().map((v) => v.toStringAsFixed(3)).join(',');
    return [
      start.inMilliseconds,
      end.inMilliseconds,
      muted,
      geometry.rotationDegrees.toStringAsFixed(3),
      geometry.flipH,
      geometry.cropNorm,
      out,
      m,
      marks.length,
      marksCanvas,
      _marksFingerprint(),
    ].join('|');
  }

  String _marksFingerprint() {
    final buffer = StringBuffer();
    for (final mark in marks) {
      switch (mark) {
        case StrokeMark s:
          buffer.write('s${s.points.length}${s.tool.index}${s.width}');
        case ShapeMark sh:
          buffer.write('h${sh.kind.index}${sh.start}${sh.end}');
        case TextMark t:
          buffer.write('t${t.text}${t.position}${t.fontSize}${t.rotation}');
      }
    }
    return buffer.toString();
  }
}

class VideoGeometry {
  final Size source;

  final double phi;
  final bool flipH;
  final Rect cropNorm;

  const VideoGeometry({
    required this.source,
    required this.phi,
    required this.flipH,
    required this.cropNorm,
  });

  static VideoGeometry resolve(VideoCropEdit? edit, Size source) {
    if (edit == null || source.isEmpty) {
      return VideoGeometry(
        source: source,
        phi: 0,
        flipH: false,
        cropNorm: const Rect.fromLTRB(0, 0, 1, 1),
      );
    }
    final state = edit.state;
    final geometry = CropGeometry(
      source: source,
      quarterTurns: state.quarterTurns,
      flipH: state.flipH,
      straightenDeg: state.straightenDeg,
    );
    final vp = edit.viewport;
    final rect = Rect.fromLTRB(
      state.cropNorm.left * vp.width,
      state.cropNorm.top * vp.height,
      state.cropNorm.right * vp.width,
      state.cropNorm.bottom * vp.height,
    );
    return VideoGeometry(
      source: source,
      phi: geometry.phi,
      flipH: state.flipH,
      cropNorm: geometry.cropInRotated(vp, rect),
    );
  }

  double get rotationDegrees {
    final degrees = phi * 180 / math.pi;
    return flipH ? degrees : -degrees;
  }

  VideoGeometry withSource(Size other) =>
      VideoGeometry(source: other, phi: phi, flipH: flipH, cropNorm: cropNorm);

  Size get rotatedSize {
    final c = math.cos(phi).abs();
    final s = math.sin(phi).abs();
    return Size(
      source.width * c + source.height * s,
      source.width * s + source.height * c,
    );
  }

  Size get naturalOutput {
    final r = rotatedSize;
    return Size(cropNorm.width * r.width, cropNorm.height * r.height);
  }

  Size outputSize(int? maxShortSide) {
    var w = naturalOutput.width;
    var h = naturalOutput.height;
    if (w <= 0 || h <= 0) return const Size(2, 2);
    final short = math.min(w, h);
    if (maxShortSide != null && short > maxShortSide) {
      final k = maxShortSide / short;
      w *= k;
      h *= k;
    }
    return Size(_even(w), _even(h));
  }

  static double _even(double value) =>
      math.max(2, (value / 2).round() * 2).toDouble();

  Matrix4 sourceToOutput() {
    final r = rotatedSize;
    return Matrix4.identity()
      ..translateByDouble(
        r.width / 2 - cropNorm.left * r.width,
        r.height / 2 - cropNorm.top * r.height,
        0,
        1,
      )
      ..multiply(flipH ? Matrix4.diagonal3Values(-1, 1, 1) : Matrix4.identity())
      ..rotateZ(phi)
      ..translateByDouble(-source.width / 2, -source.height / 2, 0, 1);
  }
}

List<double>? glColorMatrix(ColorAdjust adjust) {
  if (adjust.colorPristine) return null;
  final m = adjust.matrix();
  return [
    m[0],
    m[5],
    m[10],
    0,
    m[1],
    m[6],
    m[11],
    0,
    m[2],
    m[7],
    m[12],
    0,
    m[4] / 255,
    m[9] / 255,
    m[14] / 255,
    1,
  ];
}

List<int> videoQualityOptions(int naturalShortSide) {
  final options = kVideoQualitySteps
      .where((step) => step < naturalShortSide)
      .toList();
  options.add(naturalShortSide);
  return options;
}

int estimateVideoBitrate(Size output, double fps) {
  final rate = output.width * output.height * (fps <= 0 ? 30 : fps) * 0.09;
  return rate.round().clamp(300000, 12000000);
}

int estimateVideoSizeBytes(Size output, double fps, Duration duration) {
  final bitrate = estimateVideoBitrate(output, fps);
  return (bitrate * duration.inMilliseconds / 8000).round();
}

Future<File?> bakeVideoOverlay(VideoEditState edit, Size output) async {
  if (edit.marks.isEmpty && edit.adjust.vignette <= 0) return null;
  final width = output.width.round();
  final height = output.height.round();
  if (width <= 0 || height <= 0) return null;
  try {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, output.width, output.height);
    if (edit.adjust.vignette > 0) {
      canvas.drawRect(
        rect,
        Paint()..shader = edit.adjust.vignetteGradient().createShader(rect),
      );
    }
    if (edit.marks.isNotEmpty && !edit.marksCanvas.isEmpty) {
      canvas.save();
      canvas.scale(
        output.width / edit.marksCanvas.width,
        output.height / edit.marksCanvas.height,
      );
      DrawingPainter(marks: edit.marks).paintMarks(canvas, edit.marksCanvas);
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(
        dir.path,
        'komet_vov_${DateTime.now().microsecondsSinceEpoch}.png',
      ),
    );
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  } catch (_) {
    return null;
  }
}

Future<VideoExportSpec?> buildVideoExportSpec(
  VideoEditState edit,
  String input,
  Size source,
  double fps,
) async {
  final output = await VideoTranscoder.outputFile('video');
  if (output == null) return null;
  final geometry = VideoGeometry.resolve(edit.crop, source);
  final size = geometry.outputSize(edit.maxShortSide);
  final overlay = await bakeVideoOverlay(edit, size);
  final full = geometry.cropNorm == const Rect.fromLTRB(0, 0, 1, 1);
  return VideoExportSpec(
    input: input,
    output: output.path,
    startMs: edit.start.inMilliseconds,
    endMs: edit.end > Duration.zero ? edit.end.inMilliseconds : null,
    removeAudio: edit.muted,
    rotationDegrees: geometry.rotationDegrees,
    flipH: geometry.flipH,
    crop: full ? null : geometry.cropNorm,
    outWidth: size.width.round(),
    outHeight: size.height.round(),
    rgbMatrix: glColorMatrix(edit.adjust),
    overlayPath: overlay?.path,
    bitrate: estimateVideoBitrate(size, fps),
  );
}
