import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:komet/core/utils/image_utils.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';

const Color _kPanel = Color(0xFF101010);

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

Future<(int, int)?> decodeImageFileDimensions(File file) async {
  try {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final result = (frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return result;
  } catch (_) {
    return null;
  }
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
    final controller = TextEditingController();
    final String? text;
    try {
      text = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Текст', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            decoration: const InputDecoration(
              hintText: 'Введите текст',
              hintStyle: TextStyle(color: Colors.white38),
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('ОК'),
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
      showCustomNotification(context, 'Не удалось применить изменения');
      return;
    }
    Navigator.of(context).pop(file);
  }

  Future<File?> _bake() async {
    final ro = _boundaryKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || ro.size.isEmpty) return null;
    final box = ro.size;
    try {
      // Composite at the image's native resolution rather than capturing the
      // on-screen widget, so the photo keeps its full quality.
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

      final rendered = await picture.toImage(outW, outH);
      picture.dispose();
      final byteData = await rendered.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      rendered.dispose();
      if (byteData == null) return null;

      final jpeg = await encodeRgbaToJpeg(
        byteData.buffer.asUint8List(),
        outW,
        outH,
      );
      if (jpeg == null) return null;
      final dir = await getTemporaryDirectory();
      final out = File(
        p.join(dir.path, 'komet_edit_${DateTime.now().microsecondsSinceEpoch}.jpg'),
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
                'Очистить всё',
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
        // Only this subtree repaints while drawing (driven by _canvasRev),
        // so the toolbar/tabs/slider don't rebuild on every pointer move.
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
      color: _kPanel,
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
            label: const Text(
              'Добавить текст',
              style: TextStyle(color: Colors.white, fontSize: 15),
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
              Color(0xFF34C759),
              Color(0xFF00C7BE),
              Color(0xFF2F8FFF),
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
                _buildTab('РИСУНОК', _EditTab.draw),
                _buildTab('СТИКЕРЫ', _EditTab.stickers, disabled: true),
                _buildTab('ТЕКСТ', _EditTab.text),
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
    // An isolated layer is only needed so the eraser can punch through the
    // strokes to reveal the photo beneath — skip it otherwise (it's costly).
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
      ..cubicTo(pt(0.0, 0.78).dx, pt(0.0, 0.78).dy, pt(0.0, 0.45).dx,
          pt(0.0, 0.45).dy, pt(0.22, 0.42).dx, pt(0.22, 0.42).dy)
      ..cubicTo(pt(0.2, 0.12).dx, pt(0.2, 0.12).dy, pt(0.56, 0.08).dx,
          pt(0.56, 0.08).dy, pt(0.62, 0.36).dx, pt(0.62, 0.36).dy)
      ..cubicTo(pt(0.86, 0.24).dx, pt(0.86, 0.24).dy, pt(1.02, 0.5).dx,
          pt(1.02, 0.5).dy, pt(0.8, 0.6).dx, pt(0.8, 0.6).dy)
      ..cubicTo(pt(1.02, 0.66).dx, pt(1.02, 0.66).dy, pt(0.96, 0.9).dx,
          pt(0.96, 0.9).dy, pt(0.74, 0.8).dx, pt(0.74, 0.8).dy)
      ..cubicTo(pt(0.7, 0.98).dx, pt(0.7, 0.98).dy, pt(0.34, 0.98).dx,
          pt(0.34, 0.98).dy, pt(0.25, 0.78).dx, pt(0.25, 0.78).dy)
      ..close();
    return path;
  }

  void _paintArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final headLen = math.max(paint.strokeWidth * 4, 18.0);
    const headAngle = math.pi / 7;
    final p1 = end -
        Offset(math.cos(angle - headAngle), math.sin(angle - headAngle)) *
            headLen;
    final p2 = end -
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

/// Laid-out [TextPainter] for a [TextMark], memoized per mark so a static text
/// isn't re-laid-out every frame, and the size/paint passes share one layout.
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
      ..color = const Color(0xFF2F8FFF)
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
      color: _kPanel,
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
