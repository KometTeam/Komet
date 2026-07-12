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
      maxS = math.max(
        maxS,
        math.max(lx.abs() / (_imgW / 2), ly.abs() / (_imgH / 2)),
      );
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
        : (_quarterTurns == 0 &&
              !_flipH &&
              _straightenDeg == 0 &&
              _isFullCrop());
    if (noChange) {
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
      return await rasterPictureToJpegFile(picture, pxW, pxH, prefix: 'crop');
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _flip,
            icon: Icon(
              Symbols.flip,
              color: _flipH ? kEditorAccent : Colors.white,
            ),
            tooltip: l10n.photoEditorFlipTooltip,
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
            icon: const Icon(
              Symbols.rotate_90_degrees_ccw,
              color: Colors.white,
            ),
            tooltip: l10n.photoEditorRotateTooltip,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: _kPanel,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.photoEditorCancel,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: _reset,
            child: Text(
              l10n.photoEditorReset,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: _baking ? null : _done,
            child: Text(
              l10n.photoEditorDone,
              style: TextStyle(
                color: _baking ? Colors.white38 : kEditorAccent,
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
        ..color = kEditorAccent
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) => old.value != value;
}

const Color _kDrawPanel = Color(0xFF101010);

enum DrawTool { pen, marker, neon, eraser }

enum ShapeKind { circle, rectangle, star, cloud, arrow }

enum _EditTab { draw, stickers, text }

sealed class EditMark {}

class StrokeMark extends EditMark {
  final List<Offset> points;
  final Color color;
  final double width;
  final DrawTool tool;

  StrokeMark({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
  });
}

class ShapeMark extends EditMark {
  final ShapeKind kind;
  final Offset start;
  final Offset end;
  final Color color;
  final double width;

  ShapeMark({
    required this.kind,
    required this.start,
    required this.end,
    required this.color,
    required this.width,
  });
}

class TextMark extends EditMark {
  String text;
  Offset position;
  Color color;
  double fontSize;
  double rotation;

  TextMark({
    required this.text,
    required this.position,
    required this.color,
    required this.fontSize,
    this.rotation = 0,
  });
}

class PhotoDrawEditor extends StatefulWidget {
  final File source;
  final int imageWidth;
  final int imageHeight;

  const PhotoDrawEditor({
    super.key,
    required this.source,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  State<PhotoDrawEditor> createState() => _PhotoDrawEditorState();
}

class _PhotoDrawEditorState extends State<PhotoDrawEditor> {
  final GlobalKey _boundaryKey = GlobalKey();
  final ValueNotifier<int> _canvasRev = ValueNotifier(0);
  final List<EditMark> _marks = [];
  StrokeMark? _liveStroke;
  ShapeMark? _liveShape;
  TextMark? _draggingText;

  DrawTool _tool = DrawTool.pen;
  Color _color = Colors.white;
  double _width = 8;
  TextMark? _selectedText;
  bool _resizingText = false;
  double _resizeBaseSize = 0;
  double _resizeBaseDist = 1;
  double _resizeBaseRotation = 0;
  double _resizeBaseAngle = 0;
  ShapeKind? _shapeMode;
  _EditTab _tab = _EditTab.draw;
  bool _paletteOpen = false;
  bool _shapesOpen = false;
  bool _baking = false;

  @override
  void dispose() {
    _canvasRev.dispose();
    super.dispose();
  }

  void _bumpCanvas() => _canvasRev.value++;

  void _undo() {
    if (_marks.isEmpty) return;
    if (identical(_marks.last, _selectedText)) _selectedText = null;
    setState(() => _marks.removeLast());
  }

  void _clearAll() {
    if (_marks.isEmpty) return;
    _selectedText = null;
    setState(_marks.clear);
  }

  void _onPanStart(Offset pos) {
    if (_tab == _EditTab.text) {
      final sel = _selectedText;
      if (sel != null && _nearHandle(sel, pos)) {
        final v = pos - sel.position;
        _resizingText = true;
        _resizeBaseSize = sel.fontSize;
        _resizeBaseDist = math.max(8, v.distance);
        _resizeBaseRotation = sel.rotation;
        _resizeBaseAngle = math.atan2(v.dy, v.dx);
        return;
      }
      final hit = _hitText(pos);
      _draggingText = hit;
      if (hit != null && !identical(hit, _selectedText)) {
        _selectedText = hit;
        _bumpCanvas();
      }
      return;
    }
    final shape = _shapeMode;
    if (shape != null) {
      _liveShape = ShapeMark(
        kind: shape,
        start: pos,
        end: pos,
        color: _color,
        width: _width,
      );
    } else {
      _liveStroke = StrokeMark(
        points: [pos],
        color: _color,
        width: _width,
        tool: _tool,
      );
    }
    _bumpCanvas();
  }

  void _onPanUpdate(Offset pos) {
    if (_tab == _EditTab.text) {
      if (_resizingText) {
        final sel = _selectedText;
        if (sel != null) {
          final v = pos - sel.position;
          final angle = math.atan2(v.dy, v.dx);
          sel.fontSize = (_resizeBaseSize * v.distance / _resizeBaseDist).clamp(
            10.0,
            200.0,
          );
          sel.rotation = _resizeBaseRotation + (angle - _resizeBaseAngle);
          _bumpCanvas();
        }
        return;
      }
      final t = _draggingText;
      if (t != null) {
        t.position = pos;
        _bumpCanvas();
      }
      return;
    }
    final shape = _liveShape;
    if (shape != null) {
      _liveShape = ShapeMark(
        kind: shape.kind,
        start: shape.start,
        end: pos,
        color: shape.color,
        width: shape.width,
      );
      _bumpCanvas();
    } else if (_liveStroke != null) {
      final pts = _liveStroke!.points;
      if (pts.isEmpty || (pos - pts.last).distance >= 2.0) {
        pts.add(pos);
        _bumpCanvas();
      }
    }
  }

  void _onPanEnd() {
    if (_tab == _EditTab.text) {
      _resizingText = false;
      _draggingText = null;
      return;
    }
    final shape = _liveShape;
    if (shape != null) {
      if ((shape.end - shape.start).distance > 4) _marks.add(shape);
      setState(() {
        _liveShape = null;
        _shapeMode = null;
      });
    } else if (_liveStroke != null) {
      if (_liveStroke!.points.isNotEmpty) _marks.add(_liveStroke!);
      setState(() => _liveStroke = null);
    }
  }

  TextMark? _hitText(Offset pos) {
    for (final m in _marks.reversed) {
      if (m is! TextMark) continue;
      final local = _toLocal(pos, m);
      final box = textMarkSize(m);
      if (local.dx.abs() <= box.width / 2 && local.dy.abs() <= box.height / 2) {
        return m;
      }
    }
    return null;
  }

  Offset _toLocal(Offset pos, TextMark t) {
    final v = pos - t.position;
    final c = math.cos(-t.rotation);
    final s = math.sin(-t.rotation);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  bool _nearHandle(TextMark t, Offset pos) {
    final (left, right) = handlePositions(t);
    return (pos - left).distance < 26 || (pos - right).distance < 26;
  }

  Future<void> _addText() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final String? text;
    try {
      text = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            l10n.photoEditorTextDialogTitle,
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: l10n.photoEditorTextDialogHint,
              hintStyle: const TextStyle(color: Colors.white38),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.spoofDialogCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l10n.photoEditorOk),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (text == null || text.trim().isEmpty || !mounted) return;
    final ro = _boundaryKey.currentContext?.findRenderObject();
    final size = ro is RenderBox ? ro.size : const Size(300, 300);
    final mark = TextMark(
      text: text.trim(),
      position: Offset(size.width / 2, size.height / 2),
      color: _color,
      fontSize: 34,
    );
    setState(() {
      _marks.add(mark);
      _selectedText = mark;
    });
  }

  Future<void> _apply() async {
    if (_baking) return;
    if (_marks.isEmpty) {
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
        AppLocalizations.of(context)!.photoEditorApplyChangesFailed,
      );
      return;
    }
    Navigator.of(context).pop(file);
  }

  Future<File?> _bake() async {
    final ro = _boundaryKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || ro.size.isEmpty) return null;
    final box = ro.size;
    try {
      final bytes = await widget.source.readAsBytes();
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
      _DrawingPainter(marks: _marks).paintMarks(canvas, box);
      final picture = recorder.endRecording();
      image.dispose();
      codec.dispose();

      return await rasterPictureToJpegFile(picture, outW, outH, prefix: 'edit');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildCanvas()),
              _buildBottomPanel(),
            ],
          ),
          if (_tab == _EditTab.draw) _buildSideSlider(),
          if (_baking) const BusyOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: _marks.isEmpty ? null : _undo,
              icon: const Icon(Symbols.undo),
              color: Colors.white,
              disabledColor: Colors.white24,
            ),
            const Spacer(),
            TextButton(
              onPressed: _marks.isEmpty ? null : _clearAll,
              child: Text(
                AppLocalizations.of(context)!.photoEditorClearAll,
                style: TextStyle(
                  color: _marks.isEmpty ? Colors.white24 : Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    final aspect = widget.imageHeight > 0
        ? widget.imageWidth / widget.imageHeight
        : 1.0;
    return Center(
      child: AspectRatio(
        aspectRatio: aspect <= 0 ? 1.0 : aspect,
        child: ValueListenableBuilder<int>(
          valueListenable: _canvasRev,
          child: Image.file(
            widget.source,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          builder: (context, _, image) {
            final selected = _tab == _EditTab.text ? _selectedText : null;
            return Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  key: _boundaryKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image!,
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (d) => _onPanStart(d.localPosition),
                          onPanUpdate: (d) => _onPanUpdate(d.localPosition),
                          onPanEnd: (_) => _onPanEnd(),
                          child: CustomPaint(
                            painter: _DrawingPainter(
                              marks: _marks,
                              live: _liveStroke ?? _liveShape,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _SelectionPainter(selected)),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSideSlider() {
    return Positioned(
      left: 2,
      top: 0,
      bottom: 0,
      child: Center(
        child: SizedBox(
          height: 220,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbColor: Colors.white,
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: Slider(
                min: 2,
                max: 40,
                value: _width,
                onChanged: (v) => setState(() => _width = v),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      color: _kDrawPanel,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_paletteOpen) _buildColorPicker(),
            if (_shapesOpen && _tab == _EditTab.draw) _buildShapesRow(),
            _buildToolbar(),
            const SizedBox(height: 2),
            _buildTabs(),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    switch (_tab) {
      case _EditTab.draw:
        return _buildDrawToolbar();
      case _EditTab.text:
        return _buildTextToolbar();
      case _EditTab.stickers:
        return const SizedBox(height: 56);
    }
  }

  Widget _buildDrawToolbar() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 10),
          _buildColorButton(),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildToolButton(DrawTool.pen, Symbols.edit),
                _buildToolButton(DrawTool.marker, Symbols.ink_highlighter),
                _buildToolButton(DrawTool.neon, Symbols.auto_awesome),
                _buildToolButton(DrawTool.eraser, Symbols.ink_eraser),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _shapesOpen = !_shapesOpen;
              _paletteOpen = false;
            }),
            icon: Icon(
              Symbols.add,
              color: _shapeMode != null ? _color : Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTextToolbar() {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 10),
          _buildColorButton(),
          const SizedBox(width: 14),
          TextButton.icon(
            onPressed: _addText,
            icon: const Icon(Symbols.add, color: Colors.white),
            label: Text(
              AppLocalizations.of(context)!.photoEditorAddText,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildColorButton() {
    return GestureDetector(
      onTap: () => setState(() {
        _paletteOpen = !_paletteOpen;
        _shapesOpen = false;
      }),
      child: Container(
        width: 32,
        height: 32,
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Color(0xFFFF3B30),
              Color(0xFFFFCC00),
              kOnlineGreen,
              Color(0xFF00C7BE),
              kEditorAccent,
              Color(0xFFAF52DE),
              Color(0xFFFF3B30),
            ],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton(DrawTool tool, IconData icon) {
    final selected = _shapeMode == null && _tool == tool;
    return GestureDetector(
      onTap: () => setState(() {
        _tool = tool;
        _shapeMode = null;
        _shapesOpen = false;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : Colors.white60,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return _ColorPicker(
      color: _color,
      onChanged: (c) => setState(() {
        _color = c;
        if (_tab == _EditTab.text) _selectedText?.color = c;
      }),
    );
  }

  Widget _buildShapesRow() {
    const shapes = <(ShapeKind, IconData)>[
      (ShapeKind.circle, Symbols.circle),
      (ShapeKind.rectangle, Symbols.rectangle),
      (ShapeKind.star, Symbols.star),
      (ShapeKind.cloud, Symbols.cloud),
      (ShapeKind.arrow, Symbols.north_east),
    ];
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final (kind, icon) in shapes)
            IconButton(
              onPressed: () => setState(() {
                _shapeMode = kind;
                _shapesOpen = false;
              }),
              icon: Icon(
                icon,
                color: _shapeMode == kind ? _color : Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Symbols.close, color: Colors.white),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTab(l10n.photoEditorTabDraw, _EditTab.draw),
                _buildTab(
                  l10n.photoEditorTabStickers,
                  _EditTab.stickers,
                  disabled: true,
                ),
                _buildTab(l10n.photoEditorTabText, _EditTab.text),
              ],
            ),
          ),
          IconButton(
            onPressed: _baking ? null : _apply,
            icon: const Icon(Symbols.check, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, _EditTab tab, {bool disabled = false}) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: disabled
          ? null
          : () => setState(() {
              _tab = tab;
              _paletteOpen = false;
              _shapesOpen = false;
              if (tab != _EditTab.draw) _shapeMode = null;
            }),
      child: Text(
        label,
        style: TextStyle(
          color: disabled
              ? Colors.white24
              : (selected ? Colors.white : Colors.white60),
          fontSize: 14,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<EditMark> marks;
  final EditMark? live;

  _DrawingPainter({required this.marks, this.live});

  @override
  void paint(Canvas canvas, Size size) => paintMarks(canvas, size);

  void paintMarks(Canvas canvas, Size size) {
    final needsLayer = _hasEraser();
    if (needsLayer) canvas.saveLayer(Offset.zero & size, Paint());
    for (final m in marks) {
      _paintMark(canvas, m);
    }
    final l = live;
    if (l != null) _paintMark(canvas, l);
    if (needsLayer) canvas.restore();
  }

  bool _hasEraser() {
    for (final m in marks) {
      if (m is StrokeMark && m.tool == DrawTool.eraser) return true;
    }
    final l = live;
    return l is StrokeMark && l.tool == DrawTool.eraser;
  }

  void _paintMark(Canvas canvas, EditMark m) {
    switch (m) {
      case StrokeMark s:
        _paintStroke(canvas, s);
      case ShapeMark sh:
        _paintShape(canvas, sh);
      case TextMark t:
        _paintText(canvas, t);
    }
  }

  void _paintStroke(Canvas canvas, StrokeMark s) {
    final paint = Paint()
      ..color = s.color
      ..strokeWidth = s.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (s.tool) {
      case DrawTool.pen:
        break;
      case DrawTool.marker:
        paint.color = s.color.withValues(alpha: 0.4);
        paint.strokeWidth = s.width * 1.6;
        paint.strokeCap = StrokeCap.square;
      case DrawTool.neon:
        final glow = Paint()
          ..color = s.color.withValues(alpha: 0.7)
          ..strokeWidth = s.width * 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        _drawStrokeGeometry(canvas, s, glow);
        paint.color = Colors.white;
      case DrawTool.eraser:
        paint.blendMode = BlendMode.clear;
    }

    _drawStrokeGeometry(canvas, s, paint);
  }

  void _drawStrokeGeometry(Canvas canvas, StrokeMark s, Paint paint) {
    if (s.points.length < 2) {
      final dot = Paint()
        ..color = paint.color
        ..blendMode = paint.blendMode
        ..maskFilter = paint.maskFilter
        ..style = PaintingStyle.fill;
      canvas.drawCircle(s.points.first, paint.strokeWidth / 2, dot);
      return;
    }
    final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
    for (var i = 1; i < s.points.length; i++) {
      path.lineTo(s.points[i].dx, s.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _paintShape(Canvas canvas, ShapeMark sh) {
    final paint = Paint()
      ..color = sh.color
      ..strokeWidth = sh.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final rect = Rect.fromPoints(sh.start, sh.end);
    switch (sh.kind) {
      case ShapeKind.circle:
        canvas.drawOval(rect, paint);
      case ShapeKind.rectangle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          paint,
        );
      case ShapeKind.star:
        canvas.drawPath(_starPath(rect), paint);
      case ShapeKind.cloud:
        canvas.drawPath(_cloudPath(rect), paint);
      case ShapeKind.arrow:
        _paintArrow(canvas, sh.start, sh.end, paint);
    }
  }

  Path _starPath(Rect rect) {
    final cx = rect.center.dx;
    final cy = rect.center.dy;
    final outer = math.min(rect.width.abs(), rect.height.abs()) / 2;
    final inner = outer * 0.45;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _cloudPath(Rect rect) {
    final w = rect.width;
    final h = rect.height;
    Offset pt(double nx, double ny) =>
        Offset(rect.left + nx * w, rect.top + ny * h);
    final path = Path()..moveTo(pt(0.25, 0.78).dx, pt(0.25, 0.78).dy);
    path
      ..cubicTo(
        pt(0.0, 0.78).dx,
        pt(0.0, 0.78).dy,
        pt(0.0, 0.45).dx,
        pt(0.0, 0.45).dy,
        pt(0.22, 0.42).dx,
        pt(0.22, 0.42).dy,
      )
      ..cubicTo(
        pt(0.2, 0.12).dx,
        pt(0.2, 0.12).dy,
        pt(0.56, 0.08).dx,
        pt(0.56, 0.08).dy,
        pt(0.62, 0.36).dx,
        pt(0.62, 0.36).dy,
      )
      ..cubicTo(
        pt(0.86, 0.24).dx,
        pt(0.86, 0.24).dy,
        pt(1.02, 0.5).dx,
        pt(1.02, 0.5).dy,
        pt(0.8, 0.6).dx,
        pt(0.8, 0.6).dy,
      )
      ..cubicTo(
        pt(1.02, 0.66).dx,
        pt(1.02, 0.66).dy,
        pt(0.96, 0.9).dx,
        pt(0.96, 0.9).dy,
        pt(0.74, 0.8).dx,
        pt(0.74, 0.8).dy,
      )
      ..cubicTo(
        pt(0.7, 0.98).dx,
        pt(0.7, 0.98).dy,
        pt(0.34, 0.98).dx,
        pt(0.34, 0.98).dy,
        pt(0.25, 0.78).dx,
        pt(0.25, 0.78).dy,
      )
      ..close();
    return path;
  }

  void _paintArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final headLen = math.max(paint.strokeWidth * 4, 18.0);
    const headAngle = math.pi / 7;
    final p1 =
        end -
        Offset(math.cos(angle - headAngle), math.sin(angle - headAngle)) *
            headLen;
    final p2 =
        end -
        Offset(math.cos(angle + headAngle), math.sin(angle + headAngle)) *
            headLen;
    canvas.drawLine(end, p1, paint);
    canvas.drawLine(end, p2, paint);
  }

  void _paintText(Canvas canvas, TextMark t) {
    final tp = layoutText(t);
    canvas.save();
    canvas.translate(t.position.dx, t.position.dy);
    canvas.rotate(t.rotation);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}

final Expando<_TextLayout> _textLayoutCache = Expando<_TextLayout>();

class _TextLayout {
  final String text;
  final double fontSize;
  final Color color;
  final TextPainter painter;

  _TextLayout(this.text, this.fontSize, this.color, this.painter);
}

TextPainter layoutText(TextMark t) {
  final cached = _textLayoutCache[t];
  if (cached != null &&
      cached.text == t.text &&
      cached.fontSize == t.fontSize &&
      cached.color == t.color) {
    return cached.painter;
  }
  final tp = TextPainter(
    text: TextSpan(
      text: t.text,
      style: TextStyle(
        color: t.color,
        fontSize: t.fontSize,
        fontWeight: FontWeight.w600,
        shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 2000);
  _textLayoutCache[t] = _TextLayout(t.text, t.fontSize, t.color, tp);
  return tp;
}

Size textMarkSize(TextMark t) {
  final tp = layoutText(t);
  return Size(tp.width + 32, tp.height + 24);
}

(Offset, Offset) handlePositions(TextMark t) {
  final hw = textMarkSize(t).width / 2;
  final c = math.cos(t.rotation);
  final s = math.sin(t.rotation);
  return (
    t.position + Offset(-hw * c, -hw * s),
    t.position + Offset(hw * c, hw * s),
  );
}

class _SelectionPainter extends CustomPainter {
  final TextMark text;

  _SelectionPainter(this.text);

  @override
  void paint(Canvas canvas, Size size) {
    final box = textMarkSize(text);
    final hw = box.width / 2;
    final hh = box.height / 2;
    canvas.save();
    canvas.translate(text.position.dx, text.position.dy);
    canvas.rotate(text.rotation);

    final border = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final tl = Offset(-hw, -hh);
    final tr = Offset(hw, -hh);
    final br = Offset(hw, hh);
    final bl = Offset(-hw, hh);
    _dashedLine(canvas, tl, tr, border);
    _dashedLine(canvas, tr, br, border);
    _dashedLine(canvas, br, bl, border);
    _dashedLine(canvas, bl, tl, border);

    final fill = Paint()
      ..color = kEditorAccent
      ..style = PaintingStyle.fill;
    final ring = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final c in [Offset(-hw, 0), Offset(hw, 0)]) {
      canvas.drawCircle(c, 7, fill);
      canvas.drawCircle(c, 7, ring);
    }
    canvas.restore();
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 7.0;
    const gap = 5.0;
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
  bool shouldRepaint(covariant _SelectionPainter oldDelegate) => true;
}

class _ColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const _ColorPicker({required this.color, required this.onChanged});

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.color);
    _hsv = hsv.saturation == 0 ? hsv.withHue(0) : hsv;
  }

  void _setSV(Offset pos, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final s = (pos.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - pos.dy / size.height).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withSaturation(s).withValue(v));
    widget.onChanged(_hsv.toColor());
  }

  void _setHue(double dx, double width) {
    if (width <= 0) return;
    setState(() => _hsv = _hsv.withHue((dx / width).clamp(0.0, 1.0) * 360));
    widget.onChanged(_hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor();
    return Container(
      color: _kDrawPanel,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 132,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (d) => _setSV(d.localPosition, size),
                  onPanUpdate: (d) => _setSV(d.localPosition, size),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [Colors.white, hueColor],
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: _hsv.saturation * size.width - 9,
                          top: (1 - _hsv.value) * size.height - 9,
                          child: _thumb(_hsv.toColor()),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 22,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (d) => _setHue(d.localPosition.dx, width),
                  onPanUpdate: (d) => _setHue(d.localPosition.dx, width),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFF0000),
                                  Color(0xFFFFFF00),
                                  Color(0xFF00FF00),
                                  Color(0xFF00FFFF),
                                  Color(0xFF0000FF),
                                  Color(0xFFFF00FF),
                                  Color(0xFFFF0000),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (_hsv.hue / 360) * width - 9,
                          top: 1,
                          bottom: 1,
                          child: _thumb(hueColor),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(Color color) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
      ),
    );
  }
}

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
            if (_baking) const BusyOverlay(),
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
      builder: (context, _, _) {
        final l10n = AppLocalizations.of(context)!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _slider(
                l10n.photoEditorEnhance,
                _enhance,
                0,
                1,
                (v) => _enhance = v,
              ),
              _slider(
                l10n.photoEditorExposure,
                _exposure,
                -1,
                1,
                (v) => _exposure = v,
              ),
              _slider(
                l10n.photoEditorContrast,
                _contrast,
                -1,
                1,
                (v) => _contrast = v,
              ),
              _slider(
                l10n.photoEditorSaturation,
                _saturation,
                -1,
                1,
                (v) => _saturation = v,
              ),
              _slider(
                l10n.photoEditorWarmth,
                _warmth,
                -1,
                1,
                (v) => _warmth = v,
              ),
              _slider(
                l10n.photoEditorVignette,
                _vignette,
                0,
                1,
                (v) => _vignette = v,
              ),
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
          Icon(icon, color: selected ? kEditorAccent : Colors.white, size: 30),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? kEditorAccent : Colors.white70,
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
      color: _kPanel,
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
                color: _baking ? Colors.white38 : kEditorAccent,
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
      color: selected ? kEditorAccent : Colors.white,
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
