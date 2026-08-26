import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:komet/core/media/raster.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';

import '../../../core/config/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../small_spinner.dart';
import 'editor_common.dart';
import 'photo_hero.dart';

export 'editor_common.dart' show CropState;

class CropResult {
  final File file;
  final CropState state;

  const CropResult(this.file, this.state);
}

class PhotoEditState {
  final File? working;
  final File? cropSource;
  final CropState? cropState;

  const PhotoEditState({this.working, this.cropSource, this.cropState});
}

class PhotoCropEditor extends StatefulWidget {
  final File source;
  final CropState? initialState;
  final Future<void> Function(CropResult result)? onPreview;

  const PhotoCropEditor({
    super.key,
    required this.source,
    this.initialState,
    this.onPreview,
  });

  @override
  State<PhotoCropEditor> createState() => _PhotoCropEditorState();
}

class _PhotoCropEditorState extends State<PhotoCropEditor> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.source.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<Object?> _apply(
    CropState state,
    Size vp,
    bool changed,
    bool identity,
  ) async {
    if (!changed) return null;
    final file = await _bakeCrop(_image!, state, vp);
    if (file == null) return null;
    final result = CropResult(file, state);
    await widget.onPreview?.call(result);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: SmallSpinner(size: 36, color: Colors.white)),
      );
    }
    return CropWorkspace(
      imageSize: Size(image.width.toDouble(), image.height.toDouble()),
      initialState: widget.initialState,
      onApply: _apply,
      imageBuilder: (context, matrix) =>
          CustomPaint(painter: MatrixImagePainter(image, matrix)),
    );
  }
}

Future<File?> _bakeCrop(ui.Image img, CropState state, Size vp) async {
  if (vp == Size.zero) return null;
  try {
    final geometry = CropGeometry(
      source: Size(img.width.toDouble(), img.height.toDouble()),
      quarterTurns: state.quarterTurns,
      flipH: state.flipH,
      straightenDeg: state.straightenDeg,
    );
    final crop = Rect.fromLTRB(
      state.cropNorm.left * vp.width,
      state.cropNorm.top * vp.height,
      state.cropNorm.right * vp.width,
      state.cropNorm.bottom * vp.height,
    );
    final m = geometry.viewportMatrix(vp, crop);
    final upscale = 1 / geometry.baseScale(vp);
    const maxDim = 4096;
    final mx = math.max(crop.width * upscale, crop.height * upscale);
    final cap = mx > maxDim ? maxDim / mx : 1.0;
    final eff = upscale * cap;
    final pxW = (crop.width * eff).round();
    final pxH = (crop.height * eff).round();
    if (pxW <= 0 || pxH <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(eff);
    canvas.translate(-crop.left, -crop.top);
    canvas.transform(m.storage);
    canvas.drawImage(
      img,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    return await rasterPictureToJpegFile(picture, pxW, pxH, prefix: 'crop');
  } catch (_) {
    return null;
  }
}

class PhotoDrawEditor extends StatelessWidget {
  final File source;
  final int imageWidth;
  final int imageHeight;
  final Future<void> Function(File result)? onPreview;

  const PhotoDrawEditor({
    super.key,
    required this.source,
    required this.imageWidth,
    required this.imageHeight,
    this.onPreview,
  });

  Future<Object?> _apply(List<EditMark> marks, Size canvas) async {
    if (marks.isEmpty) return null;
    final file = await _bakeMarks(source, marks, canvas);
    if (file == null) return null;
    await onPreview?.call(file);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    return MarkupEditor(
      aspectRatio: imageHeight > 0 ? imageWidth / imageHeight : 1.0,
      background: Image.file(source, fit: BoxFit.cover, gaplessPlayback: true),
      onApply: _apply,
    );
  }
}

Future<File?> _bakeMarks(File source, List<EditMark> marks, Size box) async {
  if (box.isEmpty) return null;
  try {
    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    const maxDim = 4096;
    final srcMax = math.max(image.width, image.height);
    final cap = srcMax > maxDim ? maxDim / srcMax : 1.0;
    final outW = (image.width * cap).round();
    final outH = (image.height * cap).round();
    final scale = outW / box.width;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, box.width, box.height),
      Paint(),
    );
    DrawingPainter(marks: marks).paintMarks(canvas, box);
    final picture = recorder.endRecording();
    image.dispose();
    codec.dispose();

    return await rasterPictureToJpegFile(picture, outW, outH, prefix: 'edit');
  } catch (_) {
    return null;
  }
}

enum BlurMode { off, radial, linear }

enum _Tab { adjust, blur, curves }

class PhotoAdjustEditor extends StatefulWidget {
  final File source;
  final Future<void> Function(File result)? onPreview;

  const PhotoAdjustEditor({super.key, required this.source, this.onPreview});

  @override
  State<PhotoAdjustEditor> createState() => _PhotoAdjustEditorState();
}

class _PhotoAdjustEditorState extends State<PhotoAdjustEditor> {
  ui.Image? _image;
  final ValueNotifier<int> _rev = ValueNotifier(0);

  final ColorAdjust _adjust = ColorAdjust();
  BlurMode _blur = BlurMode.off;
  Offset _blurCenter = const Offset(0.5, 0.5);
  double _blurInner = 0.18;
  double _blurOuter = 0.34;
  static const double _blurAngle = 0;
  int _blurHandle = 0;

  final List<List<Offset>> _curves = List.generate(
    4,
    (_) => [const Offset(0, 0), const Offset(1, 1)],
  );
  int _channel = 0;
  int _curveDrag = -1;
  Uint8List? _smallRgba;
  int _smallW = 0;
  int _smallH = 0;
  ui.Image? _curvedImage;
  Uint8List? _curveOut;
  bool _curveBusy = false;
  bool _curveDirty = false;

  _Tab _tab = _Tab.adjust;
  bool _baking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.source.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      final smallCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 480,
      );
      final smallFrame = await smallCodec.getNextFrame();
      smallCodec.dispose();
      final small = smallFrame.image;
      final sbd = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
      _smallW = small.width;
      _smallH = small.height;
      _smallRgba = sbd?.buffer.asUint8List();
      small.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _curvedImage?.dispose();
    _rev.dispose();
    super.dispose();
  }

  bool _curveIdentity(List<Offset> pts) =>
      pts.length == 2 &&
      pts.first == const Offset(0, 0) &&
      pts.last == const Offset(1, 1);

  bool get _curvesIdentity => _curves.every(_curveIdentity);

  bool get _pristine =>
      _adjust.pristine && _blur == BlurMode.off && _curvesIdentity;

  Gradient _maskGradient() {
    if (_blur == BlurMode.linear) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: _linearStops(),
        transform: _RotateAround(_blurAngle, _blurCenter),
      );
    }
    final innerStop = _blurOuter > 0
        ? (_blurInner / _blurOuter).clamp(0.0, 1.0)
        : 1.0;
    return RadialGradient(
      center: Alignment(_blurCenter.dx * 2 - 1, _blurCenter.dy * 2 - 1),
      radius: _blurOuter,
      colors: const [Colors.white, Colors.white, Colors.transparent],
      stops: [0.0, innerStop, 1.0],
    );
  }

  List<double> _linearStops() {
    final c = _blurCenter.dy;
    var s0 = (c - _blurOuter).clamp(0.0, 1.0);
    var s1 = (c - _blurInner).clamp(0.0, 1.0);
    var s2 = (c + _blurInner).clamp(0.0, 1.0);
    var s3 = (c + _blurOuter).clamp(0.0, 1.0);
    s1 = math.max(s1, s0);
    s2 = math.max(s2, s1);
    s3 = math.max(s3, s2);
    return [s0, s1, s2, s3];
  }

  Rect _imageRect(Size box, ui.Image img) {
    final iw = img.width.toDouble();
    final ih = img.height.toDouble();
    if (iw <= 0 || ih <= 0) return Offset.zero & box;
    final scale = math.min(box.width / iw, box.height / ih);
    final w = iw * scale;
    final h = ih * scale;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  double _blurAlong(Offset pos, Size imgSize) {
    final c = Offset(
      _blurCenter.dx * imgSize.width,
      _blurCenter.dy * imgSize.height,
    );
    if (_blur == BlurMode.radial) return (pos - c).distance;
    final axis = Offset(-math.sin(_blurAngle), math.cos(_blurAngle));
    return ((pos - c).dx * axis.dx + (pos - c).dy * axis.dy).abs();
  }

  double _blurDenom(Size imgSize) =>
      _blur == BlurMode.radial ? imgSize.shortestSide : imgSize.height;

  void _onBlurPanStart(Offset pos, Size imgSize) {
    final denom = _blurDenom(imgSize);
    final along = _blurAlong(pos, imgSize);
    final di = (along - _blurInner * denom).abs();
    final doo = (along - _blurOuter * denom).abs();
    if (di < doo && di < 44) {
      _blurHandle = 1;
    } else if (doo < 44) {
      _blurHandle = 2;
    } else {
      _blurHandle = 0;
    }
  }

  void _onBlurPanUpdate(Offset pos, Offset delta, Size imgSize) {
    final denom = _blurDenom(imgSize);
    if (_blurHandle == 1) {
      _blurInner = (_blurAlong(pos, imgSize) / denom).clamp(0.02, _blurOuter);
    } else if (_blurHandle == 2) {
      _blurOuter = (_blurAlong(pos, imgSize) / denom).clamp(_blurInner, 1.6);
    } else {
      _blurCenter = Offset(
        (_blurCenter.dx + delta.dx / imgSize.width).clamp(0.0, 1.0),
        (_blurCenter.dy + delta.dy / imgSize.height).clamp(0.0, 1.0),
      );
    }
    _rev.value++;
  }

  double _curveY(List<Offset> pts, double x) {
    if (x <= pts.first.dx) return pts.first.dy;
    if (x >= pts.last.dx) return pts.last.dy;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      if (x >= a.dx && x <= b.dx) {
        final span = b.dx - a.dx;
        final t = span < 1e-6 ? 0.0 : (x - a.dx) / span;
        return a.dy + (b.dy - a.dy) * t;
      }
    }
    return pts.last.dy;
  }

  List<int> _lut(List<Offset> pts) => List<int>.generate(
    256,
    (i) => (_curveY(pts, i / 255.0) * 255).round().clamp(0, 255),
  );

  (List<int>, List<int>, List<int>) _combinedLuts() {
    final m = _lut(_curves[0]);
    final r = _lut(_curves[1]);
    final g = _lut(_curves[2]);
    final b = _lut(_curves[3]);
    return (
      List<int>.generate(256, (i) => m[r[i]]),
      List<int>.generate(256, (i) => m[g[i]]),
      List<int>.generate(256, (i) => m[b[i]]),
    );
  }

  void _scheduleCurvePreview() {
    _rev.value++;
    if (_curvesIdentity) {
      _curvedImage?.dispose();
      _curvedImage = null;
      return;
    }
    if (_curveBusy) {
      _curveDirty = true;
      return;
    }
    _runCurvePreview();
  }

  Future<void> _runCurvePreview() async {
    final base = _smallRgba;
    if (base == null) return;
    _curveBusy = true;
    final (rl, gl, bl) = _combinedLuts();
    final out = _curveOut ??= Uint8List(base.length);
    out.setAll(0, base);
    _applyLutsToBytes((out, rl, gl, bl));
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      out,
      _smallW,
      _smallH,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    final img = await completer.future;
    _curveBusy = false;
    if (!mounted) {
      img.dispose();
      return;
    }
    _curvedImage?.dispose();
    _curvedImage = img;
    _rev.value++;
    if (_curveDirty) {
      _curveDirty = false;
      _runCurvePreview();
    }
  }

  Future<ui.Image> _curvedFull(ui.Image img) async {
    if (_curvesIdentity) return img;
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return img;
    final (rl, gl, bl) = _combinedLuts();
    final out = await compute(_applyLutsToBytes, (
      bd.buffer.asUint8List(),
      rl,
      gl,
      bl,
    ));
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      out,
      img.width,
      img.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  void _onCurvePanStart(Offset pos, Size size) {
    final pts = _curves[_channel];
    var hit = -1;
    for (var i = 0; i < pts.length; i++) {
      final sp = Offset(pts[i].dx * size.width, (1 - pts[i].dy) * size.height);
      if ((pos - sp).distance < 28) {
        hit = i;
        break;
      }
    }
    if (hit == -1 && pts.length < 10) {
      final x = (pos.dx / size.width).clamp(0.0, 1.0);
      final y = (1 - pos.dy / size.height).clamp(0.0, 1.0);
      var idx = pts.indexWhere((pt) => pt.dx > x);
      if (idx == -1) idx = pts.length;
      pts.insert(idx, Offset(x, y));
      hit = idx;
    }
    _curveDrag = hit;
  }

  void _onCurvePanUpdate(Offset pos, Size size) {
    if (_curveDrag < 0) return;
    final pts = _curves[_channel];
    final y = (1 - pos.dy / size.height).clamp(0.0, 1.0);
    double x;
    if (_curveDrag == 0) {
      x = 0;
    } else if (_curveDrag == pts.length - 1) {
      x = 1;
    } else {
      final lo = pts[_curveDrag - 1].dx + 0.01;
      final hi = pts[_curveDrag + 1].dx - 0.01;
      x = (pos.dx / size.width).clamp(lo, math.max(lo, hi));
    }
    pts[_curveDrag] = Offset(x, y);
    _scheduleCurvePreview();
  }

  void _onCurveRemove(Offset pos, Size size) {
    final pts = _curves[_channel];
    for (var i = 1; i < pts.length - 1; i++) {
      final sp = Offset(pts[i].dx * size.width, (1 - pts[i].dy) * size.height);
      if ((pos - sp).distance < 28) {
        pts.removeAt(i);
        _scheduleCurvePreview();
        return;
      }
    }
  }

  Future<File?> _bake() async {
    final img = _image;
    if (img == null) return null;
    try {
      const maxDim = 4096;
      final srcMax = img.width > img.height ? img.width : img.height;
      final cap = srcMax > maxDim ? maxDim / srcMax : 1.0;
      final outW = (img.width * cap).round();
      final outH = (img.height * cap).round();
      if (outW <= 0 || outH <= 0) return null;
      final rect = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());
      final src = Rect.fromLTWH(
        0,
        0,
        img.width.toDouble(),
        img.height.toDouble(),
      );
      final curved = await _curvedFull(img);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      canvas.saveLayer(
        rect,
        Paint()..colorFilter = ColorFilter.matrix(_adjust.matrix()),
      );
      if (_blur == BlurMode.off) {
        canvas.drawImageRect(curved, src, rect, Paint());
      } else {
        final sigma = outW * 0.02;
        canvas.drawImageRect(
          curved,
          src,
          rect,
          Paint()
            ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        );
        canvas.saveLayer(rect, Paint());
        canvas.drawImageRect(curved, src, rect, Paint());
        canvas.drawRect(
          rect,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = _maskGradient().createShader(rect),
        );
        canvas.restore();
      }
      canvas.restore();

      if (_adjust.vignette > 0) {
        canvas.drawRect(
          rect,
          Paint()..shader = _adjust.vignetteGradient().createShader(rect),
        );
      }

      final picture = recorder.endRecording();
      return await rasterPictureToJpegFile(
        picture,
        outW,
        outH,
        prefix: 'adj',
        onPictureDisposed: () {
          if (curved != img) curved.dispose();
        },
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _done() async {
    if (_baking) return;
    if (_pristine) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _baking = true);
    final file = await _bake();
    if (!mounted) return;
    if (file == null) {
      setState(() => _baking = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.photoEditorApplyFailed,
      );
      return;
    }
    await widget.onPreview?.call(file);
    if (!mounted) return;
    Navigator.of(context).pop(file);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PhotoHeroTarget(
                    child: ClipRect(child: _buildPreview()),
                  ),
                ),
                _buildTabContent(),
                _buildBottomBar(),
              ],
            ),
            if (_baking) const BusyOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final img = _image;
    if (img == null) {
      return const Center(child: SmallSpinner(size: 36, color: Colors.white));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final rect = _imageRect(constraints.biggest, img);
        return ValueListenableBuilder<int>(
          valueListenable: _rev,
          builder: (context, _, _) {
            final blurTab = _tab == _Tab.blur && _blur != BlurMode.off;
            final curvesTab = _tab == _Tab.curves;
            final shown = _curvedImage ?? img;
            final content = Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(_adjust.matrix()),
                  child: _buildBlurLayer(shown),
                ),
                if (_adjust.vignette > 0)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: _adjust.vignetteGradient(),
                      ),
                    ),
                  ),
                if (blurTab)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _BlurGuidePainter(
                        mode: _blur,
                        center: _blurCenter,
                        inner: _blurInner,
                        outer: _blurOuter,
                        angle: _blurAngle,
                      ),
                    ),
                  ),
                if (curvesTab)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _CurvePainter(
                        points: _curves[_channel],
                        color: _channelColor(_channel),
                      ),
                    ),
                  ),
              ],
            );
            Widget child = content;
            if (blurTab) {
              child = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _onBlurPanStart(d.localPosition, rect.size),
                onPanUpdate: (d) =>
                    _onBlurPanUpdate(d.localPosition, d.delta, rect.size),
                child: content,
              );
            } else if (curvesTab) {
              child = GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (d) => _onCurvePanStart(d.localPosition, rect.size),
                onPanUpdate: (d) =>
                    _onCurvePanUpdate(d.localPosition, rect.size),
                onPanEnd: (_) => _curveDrag = -1,
                onDoubleTapDown: (d) =>
                    _onCurveRemove(d.localPosition, rect.size),
                child: content,
              );
            }
            return Stack(
              children: [Positioned.fromRect(rect: rect, child: child)],
            );
          },
        );
      },
    );
  }

  Widget _buildBlurLayer(ui.Image img) {
    if (_blur == BlurMode.off) {
      return RawImage(image: img, fit: BoxFit.contain);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: RawImage(image: img, fit: BoxFit.contain),
        ),
        ShaderMask(
          shaderCallback: (r) => _maskGradient().createShader(r),
          blendMode: BlendMode.dstIn,
          child: RawImage(image: img, fit: BoxFit.contain),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case _Tab.adjust:
        return _buildSliders();
      case _Tab.blur:
        return _buildBlurOptions();
      case _Tab.curves:
        return _buildCurves();
    }
  }

  Color _channelColor(int ch) {
    switch (ch) {
      case 1:
        return const Color(0xFFFF4D4D);
      case 2:
        return const Color(0xFF45D964);
      case 3:
        return const Color(0xFF4D9DFF);
      default:
        return Colors.white;
    }
  }

  Widget _buildCurves() {
    final l10n = AppLocalizations.of(context)!;
    final labels = [
      l10n.photoEditorChannelAll,
      l10n.photoEditorChannelRed,
      l10n.photoEditorChannelGreen,
      l10n.photoEditorChannelBlue,
    ];
    return SizedBox(
      height: 110,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var ch = 0; ch < 4; ch++) _channelOption(labels[ch], ch),
        ],
      ),
    );
  }

  Widget _channelOption(String label, int ch) {
    final selected = _channel == ch;
    final color = _channelColor(ch);
    return GestureDetector(
      onTap: () => setState(() => _channel = ch),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
            alignment: Alignment.center,
            child: selected
                ? Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? color : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliders() {
    return ValueListenableBuilder<int>(
      valueListenable: _rev,
      builder: (context, _, _) =>
          AdjustSliders(adjust: _adjust, onChanged: () => _rev.value++),
    );
  }

  Widget _buildBlurOptions() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 110,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _blurOption(l10n.photoEditorBlurOff, Symbols.block, BlurMode.off),
          _blurOption(
            l10n.photoEditorBlurRadial,
            Symbols.blur_circular,
            BlurMode.radial,
          ),
          _blurOption(
            l10n.photoEditorBlurLinear,
            Symbols.blur_linear,
            BlurMode.linear,
          ),
        ],
      ),
    );
  }

  Widget _blurOption(String label, IconData icon, BlurMode mode) {
    final selected = _blur == mode;
    return GestureDetector(
      onTap: () => setState(() => _blur = mode),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected ? MediaAccent.of(context) : Colors.white,
            size: 30,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? MediaAccent.of(context) : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: kEditorPanel,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.photoEditorCancel,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          const Spacer(),
          _tabIcon(Symbols.tune, _Tab.adjust),
          const SizedBox(width: 26),
          _tabIcon(Symbols.water_drop, _Tab.blur),
          const SizedBox(width: 26),
          _tabIcon(Symbols.show_chart, _Tab.curves),
          const Spacer(),
          TextButton(
            onPressed: _baking ? null : _done,
            child: Text(
              l10n.photoEditorDone,
              style: TextStyle(
                color: _baking ? Colors.white38 : MediaAccent.of(context),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabIcon(IconData icon, _Tab tab, {bool disabled = false}) {
    final selected = _tab == tab;
    return IconButton(
      onPressed: disabled ? null : () => setState(() => _tab = tab),
      icon: Icon(icon),
      color: selected ? MediaAccent.of(context) : Colors.white,
      disabledColor: Colors.white24,
    );
  }
}

Uint8List _applyLutsToBytes((Uint8List, List<int>, List<int>, List<int>) args) {
  final (rgba, rl, gl, bl) = args;
  for (var i = 0; i < rgba.length; i += 4) {
    rgba[i] = rl[rgba[i]];
    rgba[i + 1] = gl[rgba[i + 1]];
    rgba[i + 2] = bl[rgba[i + 2]];
  }
  return rgba;
}

class _RotateAround extends GradientTransform {
  final double radians;
  final Offset center;

  const _RotateAround(this.radians, this.center);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.left + center.dx * bounds.width;
    final cy = bounds.top + center.dy * bounds.height;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..rotateZ(radians)
      ..translateByDouble(-cx, -cy, 0, 1);
  }
}

class _BlurGuidePainter extends CustomPainter {
  final BlurMode mode;
  final Offset center;
  final double inner;
  final double outer;
  final double angle;

  _BlurGuidePainter({
    required this.mode,
    required this.center,
    required this.inner,
    required this.outer,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size sz) {
    canvas.clipRect(Offset.zero & sz);
    final c = Offset(center.dx * sz.width, center.dy * sz.height);
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    if (mode == BlurMode.radial) {
      final ss = sz.shortestSide;
      _dashedCircle(canvas, c, inner * ss, line);
      _dashedCircle(canvas, c, outer * ss, line);
    } else {
      final axis = Offset(-math.sin(angle), math.cos(angle));
      final perp = Offset(math.cos(angle), math.sin(angle));
      final innerPx = inner * sz.height;
      final outerPx = outer * sz.height;
      for (final o in [-outerPx, -innerPx, innerPx, outerPx]) {
        final mid = c + axis * o;
        _dashedLine(canvas, mid - perp * 4000, mid + perp * 4000, line);
      }
    }

    canvas.drawCircle(c, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      c,
      9,
      Paint()
        ..color = Colors.black26
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    if (r <= 1) return;
    const seg = 48;
    const sweep = 2 * math.pi / seg;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < seg; i += 2) {
      canvas.drawArc(rect, i * sweep, sweep, false, paint);
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 9.0;
    const gap = 7.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final start = a + dir * d;
      final end = a + dir * math.min(d + dash, total);
      canvas.drawLine(start, end, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _BlurGuidePainter old) =>
      old.mode != mode ||
      old.center != center ||
      old.inner != inner ||
      old.outer != outer ||
      old.angle != angle;
}

class _CurvePainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  _CurvePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size sz) {
    canvas.clipRect(Offset.zero & sz);
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 0.7;
    for (var i = 1; i < 3; i++) {
      final x = sz.width * i / 3;
      final y = sz.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, sz.height), grid);
      canvas.drawLine(Offset(0, y), Offset(sz.width, y), grid);
    }

    Offset sp(Offset pt) => Offset(pt.dx * sz.width, (1 - pt.dy) * sz.height);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final s = sp(points[i]);
      if (i == 0) {
        path.moveTo(s.dx, s.dy);
      } else {
        path.lineTo(s.dx, s.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    final fill = Paint()..color = color;
    final ring = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final pt in points) {
      final s = sp(pt);
      canvas.drawCircle(s, 6, fill);
      canvas.drawCircle(s, 6, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _CurvePainter old) => true;
}
