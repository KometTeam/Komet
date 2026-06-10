import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:komet/core/utils/image_utils.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';

const Color _kPanel = Color(0xFF0A0A0A);

class CropState {
  final int quarterTurns;
  final bool flipH;
  final double straightenDeg;
  final Rect cropNorm;

  const CropState({
    required this.quarterTurns,
    required this.flipH,
    required this.straightenDeg,
    required this.cropNorm,
  });

  bool sameAs(CropState o) =>
      quarterTurns == o.quarterTurns &&
      flipH == o.flipH &&
      (straightenDeg - o.straightenDeg).abs() < 0.05 &&
      cropNorm == o.cropNorm;
}

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

  const PhotoCropEditor({super.key, required this.source, this.initialState});

  @override
  State<PhotoCropEditor> createState() => _PhotoCropEditorState();
}

class _PhotoCropEditorState extends State<PhotoCropEditor> {
  ui.Image? _image;
  int _quarterTurns = 0;
  bool _flipH = false;
  double _straightenDeg = 0;
  Rect? _crop;
  Size _viewport = Size.zero;
  bool _baking = false;
  bool _stateApplied = false;
  int _handle = -1;
  final ValueNotifier<int> _rev = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _setCrop(Rect r) {
    _crop = r;
    _rev.value++;
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
    _rev.dispose();
    super.dispose();
  }

  double get _imgW => _image!.width.toDouble();
  double get _imgH => _image!.height.toDouble();
  double get _phi =>
      _straightenDeg * math.pi / 180 - _quarterTurns * math.pi / 2;

  Size _orientedSize() {
    final swap = _quarterTurns.isOdd;
    return swap ? Size(_imgH, _imgW) : Size(_imgW, _imgH);
  }

  double _baseScale(Size vp) {
    final o = _orientedSize();
    const margin = 0.9;
    return math.min(vp.width / o.width, vp.height / o.height) * margin;
  }

  Rect _fittedRect(Size vp) {
    final o = _orientedSize();
    final base = _baseScale(vp);
    return Rect.fromCenter(
      center: Offset(vp.width / 2, vp.height / 2),
      width: o.width * base,
      height: o.height * base,
    );
  }

  double _scaleFor(Size vp, Rect crop) {
    final base = _baseScale(vp);
    final center = Offset(vp.width / 2, vp.height / 2);
    final c = math.cos(-_phi);
    final s = math.sin(-_phi);
    var maxS = 0.0;
    for (final corner in [
      crop.topLeft,
      crop.topRight,
      crop.bottomLeft,
      crop.bottomRight,
    ]) {
      final rx = corner.dx - center.dx;
      final ry = corner.dy - center.dy;
      final lx = rx * c - ry * s;
      final ly = rx * s + ry * c;
      maxS = math.max(maxS, math.max(lx.abs() / (_imgW / 2), ly.abs() / (_imgH / 2)));
    }
    return math.max(base, maxS);
  }

  Matrix4 _matrix(Size vp, Rect crop) {
    final scale = _scaleFor(vp, crop);
    return Matrix4.identity()
      ..translateByDouble(vp.width / 2, vp.height / 2, 0, 1)
      ..multiply(
        _flipH ? Matrix4.diagonal3Values(-1, 1, 1) : Matrix4.identity(),
      )
      ..rotateZ(_phi)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-_imgW / 2, -_imgH / 2, 0, 1);
  }

  void _ensureCrop(Size vp) {
    if (_crop != null && _viewport == vp) return;
    _viewport = vp;
    final init = widget.initialState;
    if (init != null && !_stateApplied) {
      _stateApplied = true;
      _quarterTurns = init.quarterTurns;
      _flipH = init.flipH;
      _straightenDeg = init.straightenDeg;
      _crop = Rect.fromLTRB(
        init.cropNorm.left * vp.width,
        init.cropNorm.top * vp.height,
        init.cropNorm.right * vp.width,
        init.cropNorm.bottom * vp.height,
      );
    } else {
      _crop = _fittedRect(vp);
    }
  }

  CropState _currentState(Size vp, Rect crop) => CropState(
    quarterTurns: _quarterTurns,
    flipH: _flipH,
    straightenDeg: _straightenDeg,
    cropNorm: Rect.fromLTRB(
      crop.left / vp.width,
      crop.top / vp.height,
      crop.right / vp.width,
      crop.bottom / vp.height,
    ),
  );

  void _reset() {
    setState(() {
      _quarterTurns = 0;
      _flipH = false;
      _straightenDeg = 0;
      _crop = _fittedRect(_viewport);
    });
  }

  void _rotate90() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _straightenDeg = 0;
      _crop = _fittedRect(_viewport);
    });
  }

  void _flip() => setState(() => _flipH = !_flipH);

  int _hitHandle(Offset pt, Rect c) {
    const r = 34.0;
    final corners = [c.topLeft, c.topRight, c.bottomRight, c.bottomLeft];
    for (var i = 0; i < 4; i++) {
      if ((pt - corners[i]).distance < r) return i;
    }
    final insideV = pt.dy > c.top - r && pt.dy < c.bottom + r;
    final insideH = pt.dx > c.left - r && pt.dx < c.right + r;
    if ((pt.dx - c.left).abs() < r && insideV) return 4;
    if ((pt.dx - c.right).abs() < r && insideV) return 5;
    if ((pt.dy - c.top).abs() < r && insideH) return 6;
    if ((pt.dy - c.bottom).abs() < r && insideH) return 7;
    if (c.contains(pt)) return 8;
    return -1;
  }

  void _onPanStart(Offset pt) {
    final c = _crop;
    if (c == null) return;
    _handle = _hitHandle(pt, c);
  }

  void _onPanUpdate(Offset delta) {
    final c = _crop;
    if (c == null || _handle < 0) return;
    final b = _fittedRect(_viewport);
    const minSize = 64.0;

    if (_handle == 8) {
      var nl = c.left + delta.dx;
      var nt = c.top + delta.dy;
      var nr = c.right + delta.dx;
      var nb = c.bottom + delta.dy;
      if (nl < b.left) {
        nr += b.left - nl;
        nl = b.left;
      }
      if (nt < b.top) {
        nb += b.top - nt;
        nt = b.top;
      }
      if (nr > b.right) {
        nl -= nr - b.right;
        nr = b.right;
      }
      if (nb > b.bottom) {
        nt -= nb - b.bottom;
        nb = b.bottom;
      }
      _setCrop(Rect.fromLTRB(nl, nt, nr, nb));
      return;
    }

    var l = c.left;
    var t = c.top;
    var r = c.right;
    var bo = c.bottom;
    switch (_handle) {
      case 0:
        l += delta.dx;
        t += delta.dy;
      case 1:
        r += delta.dx;
        t += delta.dy;
      case 2:
        r += delta.dx;
        bo += delta.dy;
      case 3:
        l += delta.dx;
        bo += delta.dy;
      case 4:
        l += delta.dx;
      case 5:
        r += delta.dx;
      case 6:
        t += delta.dy;
      case 7:
        bo += delta.dy;
    }
    l = l.clamp(b.left, math.max(b.left, r - minSize));
    t = t.clamp(b.top, math.max(b.top, bo - minSize));
    r = r.clamp(math.min(b.right, l + minSize), b.right);
    bo = bo.clamp(math.min(b.bottom, t + minSize), b.bottom);
    _setCrop(Rect.fromLTRB(l, t, r, bo));
  }

  Future<void> _done() async {
    if (_baking) return;
    final crop = _crop;
    final vp = _viewport;
    if (crop == null || vp == Size.zero) {
      Navigator.of(context).pop();
      return;
    }
    final state = _currentState(vp, crop);
    final init = widget.initialState;
    final noChange = init != null
        ? state.sameAs(init)
        : (_quarterTurns == 0 && !_flipH && _straightenDeg == 0 && _isFullCrop());
    if (noChange) {
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
    Navigator.of(context).pop(CropResult(file, state));
  }

  bool _isFullCrop() {
    final c = _crop;
    if (c == null) return true;
    final f = _fittedRect(_viewport);
    return (c.left - f.left).abs() < 1 &&
        (c.top - f.top).abs() < 1 &&
        (c.right - f.right).abs() < 1 &&
        (c.bottom - f.bottom).abs() < 1;
  }

  Future<File?> _bake() async {
    final img = _image;
    final crop = _crop;
    final vp = _viewport;
    if (img == null || crop == null || vp == Size.zero) return null;
    try {
      final m = _matrix(vp, crop);
      final upscale = 1 / _baseScale(vp);
      var outW = crop.width * upscale;
      var outH = crop.height * upscale;
      const maxDim = 4096;
      final mx = math.max(outW, outH);
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
      final rendered = await picture.toImage(pxW, pxH);
      picture.dispose();
      final bd = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
      rendered.dispose();
      if (bd == null) return null;

      final jpeg = await encodeRgbaToJpeg(bd.buffer.asUint8List(), pxW, pxH);
      if (jpeg == null) return null;
      final dir = await getTemporaryDirectory();
      final out = File(
        p.join(dir.path, 'komet_crop_${DateTime.now().microsecondsSinceEpoch}.jpg'),
      );
      await out.writeAsBytes(jpeg);
      return out;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildViewport()),
            _buildTools(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewport() {
    final img = _image;
    if (img == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final vp = constraints.biggest;
        _ensureCrop(vp);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onPanStart(d.localPosition),
          onPanUpdate: (d) => _onPanUpdate(d.delta),
          child: ValueListenableBuilder<int>(
            valueListenable: _rev,
            builder: (context, _, _) {
              final crop = _crop!;
              return CustomPaint(
                size: vp,
                painter: _CropPainter(
                  image: img,
                  matrix: _matrix(vp, crop),
                  crop: crop,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTools() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _flip,
            icon: Icon(
              Symbols.flip,
              color: _flipH ? const Color(0xFF2F8FFF) : Colors.white,
            ),
            tooltip: 'Отразить',
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _rev,
              builder: (context, _, _) => _StraightenRuler(
                value: _straightenDeg,
                onChanged: (v) {
                  _straightenDeg = v;
                  _rev.value++;
                },
              ),
            ),
          ),
          IconButton(
            onPressed: _rotate90,
            icon: const Icon(Symbols.rotate_90_degrees_ccw, color: Colors.white),
            tooltip: 'Повернуть',
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      color: _kPanel,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'ОТМЕНА',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: _reset,
            child: const Text(
              'СБРОС',
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: _baking ? null : _done,
            child: Text(
              'ГОТОВО',
              style: TextStyle(
                color: _baking ? Colors.white38 : const Color(0xFF2F8FFF),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Matrix4 matrix;
  final Rect crop;

  _CropPainter({required this.image, required this.matrix, required this.crop});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(matrix.storage);
    canvas.drawImage(
      image,
      Offset.zero,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(crop),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 0.7;
    for (var i = 1; i < 3; i++) {
      final x = crop.left + crop.width * i / 3;
      final y = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid);
      canvas.drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
    }

    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(crop, border);

    final bracket = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const len = 20.0;
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o.translate(dx, 0), bracket);
      canvas.drawLine(o, o.translate(0, dy), bracket);
    }

    corner(crop.topLeft, len, len);
    corner(crop.topRight, -len, len);
    corner(crop.bottomLeft, len, -len);
    corner(crop.bottomRight, -len, -len);
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      old.matrix != matrix || old.crop != crop || old.image != image;
}

class _StraightenRuler extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _StraightenRuler({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: (d) {
        onChanged((value - d.delta.dx * 0.22).clamp(-45.0, 45.0));
      },
      onDoubleTap: () => onChanged(0),
      child: SizedBox(
        height: 56,
        child: CustomPaint(painter: _RulerPainter(value)),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double value;

  _RulerPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    const pxPerDeg = 6.0;
    final baseY = size.height - 6;

    final tick = Paint()..strokeWidth = 1;
    for (var deg = -60; deg <= 60; deg++) {
      final x = cx + (deg - value) * pxPerDeg;
      if (x < 0 || x > size.width) continue;
      final major = deg % 5 == 0;
      tick.color = Colors.white.withValues(alpha: major ? 0.85 : 0.4);
      final h = major ? 14.0 : 8.0;
      canvas.drawLine(Offset(x, baseY - h), Offset(x, baseY), tick);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: '${value.toStringAsFixed(1).replaceAll('.', ',')}°',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, 0));

    canvas.drawLine(
      Offset(cx, baseY - 18),
      Offset(cx, baseY + 2),
      Paint()
        ..color = const Color(0xFF2F8FFF)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) => old.value != value;
}
