import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:komet/core/utils/image_utils.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';

const Color _kAccent = Color(0xFF2F8FFF);
const Color _kPanel = Color(0xFF0A0A0A);

enum BlurMode { off, radial, linear }

enum _Tab { adjust, blur, curves }

class PhotoAdjustEditor extends StatefulWidget {
  final File source;

  const PhotoAdjustEditor({super.key, required this.source});

  @override
  State<PhotoAdjustEditor> createState() => _PhotoAdjustEditorState();
}

class _PhotoAdjustEditorState extends State<PhotoAdjustEditor> {
  ui.Image? _image;
  final ValueNotifier<int> _rev = ValueNotifier(0);

  double _enhance = 0;
  double _exposure = 0;
  double _contrast = 0;
  double _saturation = 0;
  double _warmth = 0;
  double _vignette = 0;
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
      _enhance == 0 &&
      _exposure == 0 &&
      _contrast == 0 &&
      _saturation == 0 &&
      _warmth == 0 &&
      _vignette == 0 &&
      _blur == BlurMode.off &&
      _curvesIdentity;

  List<double> _colorMatrix() {
    var m = _identity();
    m = _mulMatrix(_brightness(1 + _exposure), m);
    m = _mulMatrix(_contrastMatrix(1 + _contrast), m);
    m = _mulMatrix(_saturationMatrix(1 + _saturation), m);
    m = _mulMatrix(_warmthMatrix(_warmth), m);
    if (_enhance > 0) {
      m = _mulMatrix(_contrastMatrix(1 + _enhance * 0.35), m);
      m = _mulMatrix(_saturationMatrix(1 + _enhance * 0.4), m);
      m = _mulMatrix(_brightness(1 + _enhance * 0.05), m);
    }
    return m;
  }

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
    final out = await compute(
      _applyLutsToBytes,
      (bd.buffer.asUint8List(), rl, gl, bl),
    );
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

  Gradient _vignetteGradient() => RadialGradient(
    radius: 0.9,
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: (_vignette * 0.6).clamp(0.0, 1.0)),
    ],
    stops: const [0.5, 1.0],
  );

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
        Paint()..colorFilter = ColorFilter.matrix(_colorMatrix()),
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

      if (_vignette > 0) {
        canvas.drawRect(
          rect,
          Paint()..shader = _vignetteGradient().createShader(rect),
        );
      }

      final picture = recorder.endRecording();
      final rendered = await picture.toImage(outW, outH);
      picture.dispose();
      if (curved != img) curved.dispose();
      final bd = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
      rendered.dispose();
      if (bd == null) return null;

      final jpeg = await encodeRgbaToJpeg(bd.buffer.asUint8List(), outW, outH);
      if (jpeg == null) return null;
      final dir = await getTemporaryDirectory();
      final out = File(
        p.join(
          dir.path,
          'komet_adj_${DateTime.now().microsecondsSinceEpoch}.jpg',
        ),
      );
      await out.writeAsBytes(jpeg);
      return out;
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
      showCustomNotification(context, 'Не удалось применить');
      return;
    }
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
                Expanded(child: ClipRect(child: _buildPreview())),
                _buildTabContent(),
                _buildBottomBar(),
              ],
            ),
            if (_baking)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final img = _image;
    if (img == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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
                  colorFilter: ColorFilter.matrix(_colorMatrix()),
                  child: _buildBlurLayer(shown),
                ),
                if (_vignette > 0)
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: _vignetteGradient()),
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
    const labels = ['Все', 'Красный', 'Зелёный', 'Синий'];
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
      builder: (context, _, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _slider('Улучшение', _enhance, 0, 1, (v) => _enhance = v),
              _slider('Экспозиция', _exposure, -1, 1, (v) => _exposure = v),
              _slider('Контраст', _contrast, -1, 1, (v) => _contrast = v),
              _slider(
                'Насыщенность',
                _saturation,
                -1,
                1,
                (v) => _saturation = v,
              ),
              _slider('Тёплость', _warmth, -1, 1, (v) => _warmth = v),
              _slider('Виньетка', _vignette, 0, 1, (v) => _vignette = v),
            ],
          ),
        );
      },
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbColor: Colors.white,
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              min: min,
              max: max,
              value: value.clamp(min, max),
              onChanged: (v) {
                onChanged(v);
                _rev.value++;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlurOptions() {
    return SizedBox(
      height: 110,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _blurOption('Откл.', Symbols.block, BlurMode.off),
          _blurOption('Радиальное', Symbols.blur_circular, BlurMode.radial),
          _blurOption('Линейное', Symbols.blur_linear, BlurMode.linear),
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
          Icon(icon, color: selected ? _kAccent : Colors.white, size: 30),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? _kAccent : Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: _kPanel,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'ОТМЕНА',
              style: TextStyle(color: Colors.white, fontSize: 15),
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
              'ГОТОВО',
              style: TextStyle(
                color: _baking ? Colors.white38 : _kAccent,
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
      color: selected ? _kAccent : Colors.white,
      disabledColor: Colors.white24,
    );
  }
}

List<double> _identity() => [
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

List<double> _brightness(double f) => [
  f,
  0,
  0,
  0,
  0,
  0,
  f,
  0,
  0,
  0,
  0,
  0,
  f,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

List<double> _contrastMatrix(double c) {
  final t = 127.5 * (1 - c);
  return [c, 0, 0, 0, t, 0, c, 0, 0, t, 0, 0, c, 0, t, 0, 0, 0, 1, 0];
}

List<double> _saturationMatrix(double s) {
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final i = 1 - s;
  return [
    lr * i + s,
    lg * i,
    lb * i,
    0,
    0,
    lr * i,
    lg * i + s,
    lb * i,
    0,
    0,
    lr * i,
    lg * i,
    lb * i + s,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

List<double> _warmthMatrix(double w) {
  final o = w * 25.0;
  return [1, 0, 0, 0, o, 0, 1, 0, 0, 0, 0, 0, 1, 0, -o, 0, 0, 0, 1, 0];
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

List<double> _mulMatrix(List<double> a, List<double> b) {
  double at(List<double> m, int r, int c) =>
      r < 4 ? m[r * 5 + c] : (c == 4 ? 1.0 : 0.0);
  final out = List<double>.filled(20, 0);
  for (var r = 0; r < 4; r++) {
    for (var c = 0; c < 5; c++) {
      var sum = 0.0;
      for (var k = 0; k < 5; k++) {
        sum += at(a, r, k) * at(b, k, c);
      }
      out[r * 5 + c] = sum;
    }
  }
  return out;
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
