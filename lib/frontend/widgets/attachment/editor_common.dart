import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:material_symbols_icons/symbols.dart';

import '../../../core/config/app_colors.dart';
import '../../../core/config/app_shape.dart';
import '../../../l10n/app_localizations.dart';
import '../custom_notification.dart';
import '../small_spinner.dart';
import 'photo_hero.dart';

const Color kEditorPanel = Color(0xFF0A0A0A);
const Color kEditorDrawPanel = Color(0xFF101010);
const Color kEditorBar = Color(0xFF1E1E1E);

const List<Color> kPenWheel = [
  Color(0xFFFF3B30),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF00C7BE),
  Color(0xFF2F8FFF),
  Color(0xFFAF52DE),
  Color(0xFFFF3B30),
];

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

class CropGeometry {
  final Size source;
  final int quarterTurns;
  final bool flipH;
  final double straightenDeg;

  const CropGeometry({
    required this.source,
    this.quarterTurns = 0,
    this.flipH = false,
    this.straightenDeg = 0,
  });

  double get phi => straightenDeg * math.pi / 180 - quarterTurns * math.pi / 2;

  Size get orientedSize =>
      quarterTurns.isOdd ? Size(source.height, source.width) : source;

  Size get rotatedSize {
    final c = math.cos(phi).abs();
    final s = math.sin(phi).abs();
    return Size(
      source.width * c + source.height * s,
      source.width * s + source.height * c,
    );
  }

  double baseScale(Size vp) {
    final o = orientedSize;
    if (o.isEmpty || vp.isEmpty) return 1;
    const margin = 0.9;
    return math.min(vp.width / o.width, vp.height / o.height) * margin;
  }

  Rect fittedRect(Size vp) {
    final o = orientedSize;
    final base = baseScale(vp);
    return Rect.fromCenter(
      center: Offset(vp.width / 2, vp.height / 2),
      width: o.width * base,
      height: o.height * base,
    );
  }

  double scaleFor(Size vp, Rect crop) {
    final base = baseScale(vp);
    final center = Offset(vp.width / 2, vp.height / 2);
    final c = math.cos(-phi);
    final s = math.sin(-phi);
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
        math.max(lx.abs() / (source.width / 2), ly.abs() / (source.height / 2)),
      );
    }
    return math.max(base, maxS);
  }

  Matrix4 viewportMatrix(Size vp, Rect crop) {
    final scale = scaleFor(vp, crop);
    return Matrix4.identity()
      ..translateByDouble(vp.width / 2, vp.height / 2, 0, 1)
      ..multiply(flipH ? Matrix4.diagonal3Values(-1, 1, 1) : Matrix4.identity())
      ..rotateZ(phi)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-source.width / 2, -source.height / 2, 0, 1);
  }

  Rect cropInRotated(Size vp, Rect crop) {
    final scale = scaleFor(vp, crop);
    final rotated = rotatedSize;
    if (scale <= 0 || rotated.isEmpty) return const Rect.fromLTRB(0, 0, 1, 1);
    final center = Offset(vp.width / 2, vp.height / 2);
    final left = rotated.width / 2 + (crop.left - center.dx) / scale;
    final top = rotated.height / 2 + (crop.top - center.dy) / scale;
    final right = rotated.width / 2 + (crop.right - center.dx) / scale;
    final bottom = rotated.height / 2 + (crop.bottom - center.dy) / scale;
    return Rect.fromLTRB(
      (left / rotated.width).clamp(0.0, 1.0),
      (top / rotated.height).clamp(0.0, 1.0),
      (right / rotated.width).clamp(0.0, 1.0),
      (bottom / rotated.height).clamp(0.0, 1.0),
    );
  }
}

class CropView {
  final double scale;
  final Offset focus;

  const CropView({required this.scale, required this.focus});

  static const double margin = 0.9;

  static CropView fit(Rect crop, Size vp) {
    if (crop.isEmpty || vp.isEmpty) {
      return CropView(scale: 1, focus: crop.center);
    }
    return CropView(
      scale: math.min(
        vp.width * margin / crop.width,
        vp.height * margin / crop.height,
      ),
      focus: crop.center,
    );
  }

  static CropView lerp(CropView a, CropView b, double t) => CropView(
    scale: a.scale + (b.scale - a.scale) * t,
    focus: Offset.lerp(a.focus, b.focus, t)!,
  );

  Matrix4 matrix(Size vp) => Matrix4.identity()
    ..translateByDouble(vp.width / 2, vp.height / 2, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1)
    ..translateByDouble(-focus.dx, -focus.dy, 0, 1);

  Offset toDisplay(Offset logical, Size vp) =>
      Offset(vp.width / 2, vp.height / 2) + (logical - focus) * scale;

  Offset toLogical(Offset display, Size vp) =>
      focus + (display - Offset(vp.width / 2, vp.height / 2)) / scale;

  Rect rect(Rect logical, Size vp) => Rect.fromPoints(
    toDisplay(logical.topLeft, vp),
    toDisplay(logical.bottomRight, vp),
  );
}

class CropWorkspace extends StatefulWidget {
  final Size imageSize;
  final Widget Function(BuildContext context, Matrix4 matrix) imageBuilder;
  final CropState? initialState;
  final Future<Object?> Function(
    CropState state,
    Size viewport,
    bool changed,
    bool identity,
  )
  onApply;

  const CropWorkspace({
    super.key,
    required this.imageSize,
    required this.imageBuilder,
    required this.onApply,
    this.initialState,
  });

  @override
  State<CropWorkspace> createState() => _CropWorkspaceState();
}

class _CropWorkspaceState extends State<CropWorkspace>
    with SingleTickerProviderStateMixin {
  int _quarterTurns = 0;
  bool _flipH = false;
  double _straightenDeg = 0;
  Rect? _crop;
  Size _viewport = Size.zero;
  bool _stateApplied = false;
  bool _busy = false;
  int _handle = -1;

  CropView _view = const CropView(scale: 1, focus: Offset.zero);
  CropView? _viewFrom;
  CropView? _viewTo;

  late final AnimationController _zoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _zoom,
    curve: Curves.easeOutCubic,
  );
  final ValueNotifier<int> _rev = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialState;
    if (initial != null) {
      _quarterTurns = initial.quarterTurns;
      _flipH = initial.flipH;
      _straightenDeg = initial.straightenDeg;
    }
    _zoom.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      final target = _viewTo;
      if (target != null) _view = target;
      _viewFrom = null;
      _viewTo = null;
    });
  }

  @override
  void dispose() {
    _zoom.dispose();
    _rev.dispose();
    super.dispose();
  }

  CropGeometry get _geometry => CropGeometry(
    source: widget.imageSize,
    quarterTurns: _quarterTurns,
    flipH: _flipH,
    straightenDeg: _straightenDeg,
  );

  CropView get _liveView {
    final from = _viewFrom;
    final to = _viewTo;
    if (from == null || to == null) return _view;
    return CropView.lerp(from, to, _curve.value);
  }

  void _setCrop(Rect r) {
    _crop = r;
    _rev.value++;
  }

  void _animateTo(CropView target) {
    _viewFrom = _liveView;
    _viewTo = target;
    _zoom.forward(from: 0);
  }

  void _ensureCrop(Size vp) {
    if (_crop != null && _viewport == vp) return;
    _viewport = vp;
    final initial = widget.initialState;
    if (initial != null && !_stateApplied) {
      _stateApplied = true;
      _crop = Rect.fromLTRB(
        initial.cropNorm.left * vp.width,
        initial.cropNorm.top * vp.height,
        initial.cropNorm.right * vp.width,
        initial.cropNorm.bottom * vp.height,
      );
    } else {
      _crop = _geometry.fittedRect(vp);
    }
    _view = CropView.fit(_crop!, vp);
    _viewFrom = null;
    _viewTo = null;
  }

  void _refit() {
    final crop = _crop;
    if (crop == null || _viewport == Size.zero) return;
    _animateTo(CropView.fit(crop, _viewport));
  }

  void _reset() {
    setState(() {
      _quarterTurns = 0;
      _flipH = false;
      _straightenDeg = 0;
      _crop = _geometry.fittedRect(_viewport);
    });
    _refit();
  }

  void _rotate90() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _straightenDeg = 0;
      _crop = _geometry.fittedRect(_viewport);
    });
    _refit();
  }

  void _flip() => setState(() => _flipH = !_flipH);

  bool get _isFullCrop {
    final c = _crop;
    if (c == null) return true;
    final f = _geometry.fittedRect(_viewport);
    return (c.left - f.left).abs() < 1 &&
        (c.top - f.top).abs() < 1 &&
        (c.right - f.right).abs() < 1 &&
        (c.bottom - f.bottom).abs() < 1;
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

  Future<void> _done() async {
    if (_busy) return;
    final crop = _crop;
    final vp = _viewport;
    if (crop == null || vp == Size.zero) {
      Navigator.of(context).pop();
      return;
    }
    final state = _currentState(vp, crop);
    final initial = widget.initialState;
    final identity =
        _quarterTurns == 0 && !_flipH && _straightenDeg == 0 && _isFullCrop;
    final changed = initial != null ? !state.sameAs(initial) : !identity;
    setState(() => _busy = true);
    final result = await widget.onApply(state, vp, changed, identity);
    if (!mounted) return;
    if (result == null && changed) {
      setState(() => _busy = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.photoEditorApplyFailed,
      );
      return;
    }
    Navigator.of(context).pop(result);
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
                Expanded(child: _buildViewport()),
                _buildTools(),
                _buildActions(),
              ],
            ),
            if (_busy) const BusyOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildViewport() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vp = constraints.biggest;
        _ensureCrop(vp);
        return Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => _onPanStart(d.localPosition, vp),
              onPanUpdate: (d) => _onPanUpdate(d.delta, vp),
              onPanEnd: (_) => _onPanEnd(),
              onPanCancel: _onPanEnd,
              child: PhotoHeroFade(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_rev, _curve]),
                  builder: (context, _) {
                    final view = _liveView;
                    final crop = _crop!;
                    final matrix = view.matrix(vp)
                      ..multiply(_geometry.viewportMatrix(vp, crop));
                    return ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.imageBuilder(context, matrix),
                          CustomPaint(
                            painter: CropChromePainter(view.rect(crop, vp)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: CropView.margin,
                  heightFactor: CropView.margin,
                  child: const PhotoHeroAnchor(child: SizedBox.expand()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _onPanStart(Offset pos, Size vp) {
    final crop = _crop;
    if (crop == null) return;
    _handle = hitCropHandle(pos, _liveView.rect(crop, vp));
  }

  void _onPanUpdate(Offset delta, Size vp) {
    final crop = _crop;
    if (crop == null || _handle < 0) return;
    final view = _liveView;
    _setCrop(
      moveCropHandle(
        crop,
        _handle,
        delta / view.scale,
        _geometry.fittedRect(vp),
      ),
    );
  }

  void _onPanEnd() {
    if (_handle < 0) return;
    _handle = -1;
    _refit();
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
              color: _flipH ? MediaAccent.of(context) : Colors.white,
            ),
            tooltip: l10n.photoEditorFlipTooltip,
          ),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: _rev,
              builder: (context, _, _) => StraightenRuler(
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
      color: kEditorPanel,
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
            onPressed: _busy ? null : _done,
            child: Text(
              l10n.photoEditorDone,
              style: TextStyle(
                color: _busy ? Colors.white38 : MediaAccent.of(context),
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

class CropChromePainter extends CustomPainter {
  final Rect crop;

  CropChromePainter(this.crop);

  @override
  void paint(Canvas canvas, Size size) => paintCropChrome(canvas, size, crop);

  @override
  bool shouldRepaint(covariant CropChromePainter old) => old.crop != crop;
}

class MatrixImagePainter extends CustomPainter {
  final ui.Image image;
  final Matrix4 matrix;

  MatrixImagePainter(this.image, this.matrix);

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
  }

  @override
  bool shouldRepaint(covariant MatrixImagePainter old) =>
      old.matrix != matrix || old.image != image;
}

class CropPainter extends CustomPainter {
  final ui.Image image;
  final Matrix4 matrix;
  final Rect crop;

  CropPainter({required this.image, required this.matrix, required this.crop});

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
    paintCropChrome(canvas, size, crop);
  }

  @override
  bool shouldRepaint(covariant CropPainter old) =>
      old.matrix != matrix || old.crop != crop || old.image != image;
}

void paintCropChrome(Canvas canvas, Size size, Rect crop) {
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

int hitCropHandle(Offset pt, Rect c) {
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

Rect moveCropHandle(Rect c, int handle, Offset delta, Rect bounds) {
  const minSize = 64.0;
  if (handle == 8) {
    var nl = c.left + delta.dx;
    var nt = c.top + delta.dy;
    var nr = c.right + delta.dx;
    var nb = c.bottom + delta.dy;
    if (nl < bounds.left) {
      nr += bounds.left - nl;
      nl = bounds.left;
    }
    if (nt < bounds.top) {
      nb += bounds.top - nt;
      nt = bounds.top;
    }
    if (nr > bounds.right) {
      nl -= nr - bounds.right;
      nr = bounds.right;
    }
    if (nb > bounds.bottom) {
      nt -= nb - bounds.bottom;
      nb = bounds.bottom;
    }
    return Rect.fromLTRB(nl, nt, nr, nb);
  }

  var l = c.left;
  var t = c.top;
  var r = c.right;
  var bo = c.bottom;
  switch (handle) {
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
  l = l.clamp(bounds.left, math.max(bounds.left, r - minSize));
  t = t.clamp(bounds.top, math.max(bounds.top, bo - minSize));
  r = r.clamp(math.min(bounds.right, l + minSize), bounds.right);
  bo = bo.clamp(math.min(bounds.bottom, t + minSize), bounds.bottom);
  return Rect.fromLTRB(l, t, r, bo);
}

class StraightenRuler extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const StraightenRuler({
    super.key,
    required this.value,
    required this.onChanged,
  });

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
        child: CustomPaint(
          painter: _RulerPainter(value, MediaAccent.of(context)),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double value;
  final Color accent;

  _RulerPainter(this.value, this.accent);

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
        ..color = accent
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.value != value || old.accent != accent;
}

enum DrawTool { pen, marker, neon, eraser }

enum ShapeKind { circle, rectangle, star, cloud, arrow }

enum EditTab { draw, stickers, text }

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

class MarkupEditor extends StatefulWidget {
  final Widget background;
  final double aspectRatio;
  final List<EditMark> initialMarks;
  final Future<Object?> Function(List<EditMark> marks, Size canvas) onApply;

  const MarkupEditor({
    super.key,
    required this.background,
    required this.aspectRatio,
    required this.onApply,
    this.initialMarks = const [],
  });

  @override
  State<MarkupEditor> createState() => _MarkupEditorState();
}

class _MarkupEditorState extends State<MarkupEditor> {
  final GlobalKey _boundaryKey = GlobalKey();
  final ValueNotifier<int> _canvasRev = ValueNotifier(0);
  late final List<EditMark> _marks = [...widget.initialMarks];
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
  EditTab _tab = EditTab.draw;
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
    if (_tab == EditTab.text) {
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
    if (_tab == EditTab.text) {
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
    if (_tab == EditTab.text) {
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
          shape: AppShape.dialogBorder,
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
    final ro = _boundaryKey.currentContext?.findRenderObject();
    final canvas = ro is RenderBox && !ro.size.isEmpty
        ? ro.size
        : const Size(300, 300);
    setState(() => _baking = true);
    final result = await widget.onApply(_marks, canvas);
    if (!mounted) return;
    if (result == null && _marks.isNotEmpty) {
      setState(() => _baking = false);
      showCustomNotification(
        context,
        AppLocalizations.of(context)!.photoEditorApplyChangesFailed,
      );
      return;
    }
    Navigator.of(context).pop(result);
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
          if (_tab == EditTab.draw) _buildSideSlider(),
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
    final aspect = widget.aspectRatio;
    return Center(
      child: AspectRatio(
        aspectRatio: aspect <= 0 ? 1.0 : aspect,
        child: ValueListenableBuilder<int>(
          valueListenable: _canvasRev,
          child: widget.background,
          builder: (context, _, image) {
            final selected = _tab == EditTab.text ? _selectedText : null;
            return Stack(
              fit: StackFit.expand,
              children: [
                PhotoHeroTarget(
                  child: RepaintBoundary(
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
                              painter: DrawingPainter(
                                marks: _marks,
                                live: _liveStroke ?? _liveShape,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (selected != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: SelectionPainter(
                          selected,
                          MediaAccent.of(context),
                        ),
                      ),
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
      color: kEditorDrawPanel,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_paletteOpen) _buildColorPicker(),
            if (_shapesOpen && _tab == EditTab.draw) _buildShapesRow(),
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
      case EditTab.draw:
        return _buildDrawToolbar();
      case EditTab.text:
        return _buildTextToolbar();
      case EditTab.stickers:
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
          gradient: SweepGradient(colors: kPenWheel),
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
    return ColorPicker(
      color: _color,
      onChanged: (c) => setState(() {
        _color = c;
        if (_tab == EditTab.text) _selectedText?.color = c;
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
                _buildTab(l10n.photoEditorTabDraw, EditTab.draw),
                _buildTab(
                  l10n.photoEditorTabStickers,
                  EditTab.stickers,
                  disabled: true,
                ),
                _buildTab(l10n.photoEditorTabText, EditTab.text),
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

  Widget _buildTab(String label, EditTab tab, {bool disabled = false}) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: disabled
          ? null
          : () => setState(() {
              _tab = tab;
              _paletteOpen = false;
              _shapesOpen = false;
              if (tab != EditTab.draw) _shapeMode = null;
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

class DrawingPainter extends CustomPainter {
  final List<EditMark> marks;
  final EditMark? live;

  DrawingPainter({required this.marks, this.live});

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
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
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

class SelectionPainter extends CustomPainter {
  final TextMark text;
  final Color accent;

  SelectionPainter(this.text, this.accent);

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
      ..color = accent
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
  bool shouldRepaint(covariant SelectionPainter oldDelegate) => true;
}

class ColorPicker extends StatefulWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const ColorPicker({super.key, required this.color, required this.onChanged});

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
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
      color: kEditorDrawPanel,
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

class ColorAdjust {
  double enhance;
  double exposure;
  double contrast;
  double saturation;
  double warmth;
  double vignette;

  ColorAdjust({
    this.enhance = 0,
    this.exposure = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.vignette = 0,
  });

  ColorAdjust copy() => ColorAdjust(
    enhance: enhance,
    exposure: exposure,
    contrast: contrast,
    saturation: saturation,
    warmth: warmth,
    vignette: vignette,
  );

  bool get pristine =>
      enhance == 0 &&
      exposure == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      warmth == 0 &&
      vignette == 0;

  bool get colorPristine =>
      enhance == 0 &&
      exposure == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      warmth == 0;

  List<double> matrix() {
    var m = identityMatrix();
    m = mulMatrix(brightnessMatrix(1 + exposure), m);
    m = mulMatrix(contrastMatrix(1 + contrast), m);
    m = mulMatrix(saturationMatrix(1 + saturation), m);
    m = mulMatrix(warmthMatrix(warmth), m);
    if (enhance > 0) {
      m = mulMatrix(contrastMatrix(1 + enhance * 0.35), m);
      m = mulMatrix(saturationMatrix(1 + enhance * 0.4), m);
      m = mulMatrix(brightnessMatrix(1 + enhance * 0.05), m);
    }
    return m;
  }

  Gradient vignetteGradient() => RadialGradient(
    radius: 0.9,
    colors: [
      Colors.transparent,
      Colors.black.withValues(alpha: (vignette * 0.6).clamp(0.0, 1.0)),
    ],
    stops: const [0.5, 1.0],
  );
}

class AdjustSliders extends StatelessWidget {
  final ColorAdjust adjust;
  final VoidCallback onChanged;

  const AdjustSliders({
    super.key,
    required this.adjust,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _slider(context, l10n.photoEditorEnhance, adjust.enhance, 0, 1, (v) {
            adjust.enhance = v;
          }),
          _slider(context, l10n.photoEditorExposure, adjust.exposure, -1, 1, (
            v,
          ) {
            adjust.exposure = v;
          }),
          _slider(context, l10n.photoEditorContrast, adjust.contrast, -1, 1, (
            v,
          ) {
            adjust.contrast = v;
          }),
          _slider(
            context,
            l10n.photoEditorSaturation,
            adjust.saturation,
            -1,
            1,
            (v) {
              adjust.saturation = v;
            },
          ),
          _slider(context, l10n.photoEditorWarmth, adjust.warmth, -1, 1, (v) {
            adjust.warmth = v;
          }),
          _slider(context, l10n.photoEditorVignette, adjust.vignette, 0, 1, (
            v,
          ) {
            adjust.vignette = v;
          }),
        ],
      ),
    );
  }

  Widget _slider(
    BuildContext context,
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> apply,
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
                apply(v);
                onChanged();
              },
            ),
          ),
        ),
      ],
    );
  }
}

List<double> identityMatrix() => [
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

List<double> brightnessMatrix(double f) => [
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

List<double> contrastMatrix(double c) {
  final t = 127.5 * (1 - c);
  return [c, 0, 0, 0, t, 0, c, 0, 0, t, 0, 0, c, 0, t, 0, 0, 0, 1, 0];
}

List<double> saturationMatrix(double s) {
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

List<double> warmthMatrix(double w) {
  final o = w * 25.0;
  return [1, 0, 0, 0, o, 0, 1, 0, 0, 0, 0, 0, 1, 0, -o, 0, 0, 0, 1, 0];
}

List<double> mulMatrix(List<double> a, List<double> b) {
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
