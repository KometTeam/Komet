import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/utils/haptics.dart';
import '../../l10n/app_localizations.dart';
import 'custom_notification.dart';

void _collectParagraphs(RenderObject ro, List<RenderParagraph> out) {
  if (ro is RenderParagraph) {
    out.add(ro);
    return;
  }
  ro.visitChildren((child) => _collectParagraphs(child, out));
}

bool _isSpace(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0x0C || c == 0xA0;

bool _isGlyphOnly(String text) {
  if (text.isEmpty) return true;
  for (final rune in text.runes) {
    final private =
        (rune >= 0xE000 && rune <= 0xF8FF) ||
        (rune >= 0xF0000 && rune <= 0xFFFFD) ||
        (rune >= 0x100000 && rune <= 0x10FFFD);
    if (!private) return false;
  }
  return true;
}

class _ParaSlice {
  final RenderParagraph rp;
  final int start;
  final String text;

  const _ParaSlice({required this.rp, required this.start, required this.text});

  int get end => start + text.length;

  bool get usable => rp.attached && rp.hasSize;

  Offset get origin => rp.localToGlobal(Offset.zero);

  Rect get globalRect => origin & rp.size;

  TextSelection? clip(TextSelection selection) {
    final s = selection.start.clamp(start, end) - start;
    final e = selection.end.clamp(start, end) - start;
    if (e <= s) return null;
    return TextSelection(baseOffset: s, extentOffset: e);
  }
}

class SelectableMessageText extends StatefulWidget {
  final Widget child;
  final Offset initialGlobalPosition;
  final VoidCallback onExit;
  final ValueListenable<Offset?>? dragPosition;

  const SelectableMessageText({
    super.key,
    required this.child,
    required this.initialGlobalPosition,
    required this.onExit,
    this.dragPosition,
  });

  @override
  State<SelectableMessageText> createState() => _SelectableMessageTextState();
}

class _SelectableMessageTextState extends State<SelectableMessageText>
    with SingleTickerProviderStateMixin {
  static const double _ballRadius = 10.0;
  static const double _hitInner = 20.0;
  static const double _hitOuter = 36.0;
  static const double _hitAbove = 18.0;
  static const double _hitBelow = 42.0;

  final GlobalKey _textKey = GlobalKey();
  final LayerLink _link = LayerLink();
  final ValueNotifier<bool> _toolbarVisible = ValueNotifier(false);

  late final AnimationController _entrance;
  OverlayEntry? _overlay;
  Timer? _settle;
  TextSelection _selection = const TextSelection.collapsed(offset: 0);
  bool _dragging = false;
  bool _exiting = false;
  double? _dragStartGlobalY;
  double _dragAnchorY = 0;
  double _dragLineHeight = 0;

  List<_ParaSlice>? _cachedSlices;
  String _cachedJoined = '';
  ScrollPosition? _scrollPosition;
  TextSelection? _anchor;

  List<_ParaSlice> get _slices {
    final cached = _cachedSlices;
    if (cached != null && cached.isNotEmpty && cached.every((s) => s.usable)) {
      return cached;
    }
    final root = _textKey.currentContext?.findRenderObject();
    final paragraphs = <RenderParagraph>[];
    if (root != null) _collectParagraphs(root, paragraphs);

    final slices = <_ParaSlice>[];
    var offset = 0;
    for (final rp in paragraphs) {
      if (!rp.attached || !rp.hasSize) continue;
      final text = rp.text.toPlainText();
      if (_isGlyphOnly(text)) continue;
      slices.add(_ParaSlice(rp: rp, start: offset, text: text));
      offset += text.length + 1;
    }
    _cachedJoined = slices.map((s) => s.text).join('\n');
    return _cachedSlices = slices;
  }

  String get _joined {
    _slices;
    return _cachedJoined;
  }

  _ParaSlice? _sliceAt(Offset globalPos) {
    final slices = _slices;
    if (slices.isEmpty) return null;
    _ParaSlice? nearest;
    var best = double.infinity;
    for (final slice in slices) {
      final rect = slice.globalRect;
      if (rect.contains(globalPos)) return slice;
      final dy = globalPos.dy < rect.top
          ? rect.top - globalPos.dy
          : globalPos.dy - rect.bottom;
      final distance = math.max(0.0, dy);
      if (distance < best) {
        best = distance;
        nearest = slice;
      }
    }
    return nearest;
  }

  int? _offsetAt(Offset globalPos) {
    final slice = _sliceAt(globalPos);
    if (slice == null) return null;
    final local = slice.rp.globalToLocal(globalPos);
    final off = slice.rp
        .getPositionForOffset(local)
        .offset
        .clamp(0, slice.text.length);
    return slice.start + off;
  }

  RenderBox? get _rootBox {
    final ro = _textKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    return ro;
  }

  List<Rect> _localBoxes(TextSelection selection) {
    if (!selection.isValid || selection.isCollapsed) return const [];
    final root = _rootBox;
    if (root == null) return const [];
    final rootOrigin = root.localToGlobal(Offset.zero);
    final out = <Rect>[];
    for (final slice in _slices) {
      final local = slice.clip(selection);
      if (local == null) continue;
      final delta = slice.origin - rootOrigin;
      for (final box in slice.rp.getBoxesForSelection(local)) {
        out.add(box.toRect().shift(delta));
      }
    }
    return out;
  }

  List<Rect> _globalBoxes(TextSelection selection) {
    final root = _rootBox;
    if (root == null) return const [];
    final rootOrigin = root.localToGlobal(Offset.zero);
    return [for (final rect in _localBoxes(selection)) rect.shift(rootOrigin)];
  }

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() => _overlay?.markNeedsBuild());
    widget.dragPosition?.addListener(_onDragPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init(4));
  }

  @override
  void didUpdateWidget(SelectableMessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dragPosition == widget.dragPosition) return;
    oldWidget.dragPosition?.removeListener(_onDragPosition);
    widget.dragPosition?.addListener(_onDragPosition);
  }

  void _onDragPosition() {
    if (!mounted) return;
    final pos = widget.dragPosition?.value;
    if (pos == null) {
      if (_anchor != null) _toolbarVisible.value = true;
      return;
    }
    final anchor = _anchor;
    if (anchor == null) return;
    final off = _offsetAt(pos);
    if (off == null) return;
    _toolbarVisible.value = false;
    if (off > anchor.end) {
      _applySelection(
        TextSelection(baseOffset: anchor.start, extentOffset: off),
      );
    } else if (off < anchor.start) {
      _applySelection(TextSelection(baseOffset: off, extentOffset: anchor.end));
    } else {
      _applySelection(anchor);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (identical(position, _scrollPosition)) return;
    _scrollPosition?.removeListener(_onScroll);
    _scrollPosition = position?..addListener(_onScroll);
  }

  void _onScroll() => _overlay?.markNeedsBuild();

  @override
  void dispose() {
    _settle?.cancel();
    widget.dragPosition?.removeListener(_onDragPosition);
    _scrollPosition?.removeListener(_onScroll);
    _entrance.dispose();
    _overlay?.remove();
    _overlay = null;
    _toolbarVisible.dispose();
    super.dispose();
  }

  void _init(int retries) {
    if (!mounted) return;
    if (_slices.isEmpty) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _init(retries - 1));
      } else {
        _requestExit();
      }
      return;
    }
    _selectWordAt(widget.initialGlobalPosition);
    _anchor = _selection;
    Haptics.selection();
    _ensureOverlay();
    _toolbarVisible.value = true;
  }

  void _ensureOverlay() {
    if (_overlay != null || !mounted) return;
    _overlay = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _requestExit() {
    if (_exiting) return;
    _exiting = true;
    _settle?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onExit();
    });
  }

  TextSelection _normalize(int a, int b) =>
      TextSelection(baseOffset: math.min(a, b), extentOffset: math.max(a, b));

  void _applySelection(TextSelection sel, {bool animate = false}) {
    _selection = sel;
    if (animate) _entrance.forward(from: 0);
    if (mounted) setState(() {});
    _overlay?.markNeedsBuild();
  }

  TextRange _wordRange(Offset globalPos) {
    final text = _joined;
    final len = text.length;
    if (len == 0) return const TextRange.collapsed(0);
    var off = (_offsetAt(globalPos) ?? 0).clamp(0, len);
    bool ws(int i) => i < 0 || i >= len || _isSpace(text.codeUnitAt(i));
    if (ws(off) && off > 0 && !ws(off - 1)) off -= 1;
    if (ws(off)) return TextRange.collapsed(off);
    var s = off;
    var e = off;
    while (s > 0 && !_isSpace(text.codeUnitAt(s - 1))) {
      s--;
    }
    while (e < len && !_isSpace(text.codeUnitAt(e))) {
      e++;
    }
    return TextRange(start: s, end: e);
  }

  void _selectWordAt(Offset globalPos) {
    final range = _wordRange(globalPos);
    if (range.isCollapsed) {
      _applySelection(_normalize(0, _joined.length), animate: true);
    } else {
      _applySelection(_normalize(range.start, range.end), animate: true);
    }
  }

  void _onBackgroundTap(Offset globalPos) {
    final slices = _slices;
    if (slices.isEmpty) {
      _requestExit();
      return;
    }
    final inside = slices.any((s) => s.globalRect.contains(globalPos));
    if (inside) {
      _dragging = false;
      _settle?.cancel();
      _toolbarVisible.value = true;
    } else {
      _requestExit();
    }
  }

  void _onHandleDragStart(Offset globalPos, bool isStart) {
    _dragging = true;
    _settle?.cancel();
    _entrance.value = 1.0;
    _toolbarVisible.value = false;
    _dragStartGlobalY = null;
    final boxes = _globalBoxes(_selection);
    if (boxes.isEmpty) return;
    final rect = isStart ? boxes.first : boxes.last;
    _dragStartGlobalY = globalPos.dy;
    _dragAnchorY = rect.center.dy;
    _dragLineHeight = rect.height;
  }

  double _lineSnappedY(double fingerGlobalY) {
    final startY = _dragStartGlobalY;
    if (startY == null || _dragLineHeight <= 0) return fingerGlobalY;
    final dragged = fingerGlobalY - startY;
    final direction = dragged < 0 ? -1 : 1;
    final lines = direction * (dragged.abs() / _dragLineHeight).floor();
    return _dragAnchorY + lines * _dragLineHeight;
  }

  void _onHandleDrag(Offset globalPos, bool isStart) {
    final len = _joined.length;
    if (len == 0) return;
    final off = _offsetAt(Offset(globalPos.dx, _lineSnappedY(globalPos.dy)));
    if (off == null) return;
    if (isStart) {
      final ns = off.clamp(0, math.max(0, _selection.end - 1)).toInt();
      _applySelection(
        TextSelection(baseOffset: ns, extentOffset: _selection.end),
      );
    } else {
      final ne = off.clamp(math.min(_selection.start + 1, len), len).toInt();
      _applySelection(
        TextSelection(baseOffset: _selection.start, extentOffset: ne),
      );
    }
  }

  void _onHandleDragEnd() {
    _dragging = false;
    _dragStartGlobalY = null;
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 140), () {
      if (!mounted || _dragging) return;
      _overlay?.markNeedsBuild();
      _toolbarVisible.value = true;
    });
  }

  void _copy() {
    if (_selection.isValid && !_selection.isCollapsed) {
      final text = _joined;
      final sub = text.substring(
        _selection.start.clamp(0, text.length),
        _selection.end.clamp(0, text.length),
      );
      if (sub.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: sub));
        Haptics.tap();
        showCustomNotification(
          context,
          AppLocalizations.of(context)!.msgActionsCopied,
        );
      }
    }
    _requestExit();
  }

  void _selectAll() {
    if (_slices.isEmpty) return;
    Haptics.tap();
    _applySelection(_normalize(0, _joined.length), animate: true);
    _toolbarVisible.value = true;
  }

  Widget _buildOverlay(BuildContext ctx) {
    if (_slices.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(ctx).colorScheme;
    final rects = _localBoxes(_selection);

    final children = <Widget>[
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) => _onBackgroundTap(d.globalPosition),
        ),
      ),
    ];

    if (rects.isNotEmpty) {
      final first = rects.first;
      final last = rects.last;

      children.add(
        _handle(cs, Offset(first.left, first.bottom), isStart: true),
      );
      children.add(
        _handle(cs, Offset(last.right, last.bottom), isStart: false),
      );
      children.add(_toolbar(ctx, first, last));
    }

    return Stack(children: children);
  }

  Widget _follow(Offset offset, Widget child) => Positioned(
    left: 0,
    top: 0,
    child: CompositedTransformFollower(
      link: _link,
      showWhenUnlinked: false,
      offset: offset,
      child: child,
    ),
  );

  Widget _handle(
    ColorScheme cs,
    Offset lineBottomGlobal, {
    required bool isStart,
  }) {
    final center = Offset(
      lineBottomGlobal.dx,
      lineBottomGlobal.dy + _ballRadius,
    );
    final leftInset = isStart ? _hitOuter : _hitInner;
    return _follow(
      Offset(center.dx - leftInset, center.dy - _hitAbove),
      SizedBox(
        width: _hitInner + _hitOuter,
        height: _hitAbove + _hitBelow,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _onHandleDragStart(d.globalPosition, isStart),
          onPanUpdate: (d) => _onHandleDrag(d.globalPosition, isStart),
          onPanEnd: (_) => _onHandleDragEnd(),
          onPanCancel: _onHandleDragEnd,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: leftInset - _ballRadius,
                top: _hitAbove - _ballRadius,
              ),
              child: Transform.scale(
                scale: Curves.easeOutBack.transform(
                  _entrance.value.clamp(0.0, 1.0),
                ),
                child: Container(
                  width: _ballRadius * 2,
                  height: _ballRadius * 2,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolbar(BuildContext ctx, Rect first, Rect last) {
    final media = MediaQuery.of(ctx);
    final size = media.size;
    final rootOrigin = _rootBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final safeTop = media.padding.top + 8;
    final safeBottom = size.height - media.padding.bottom - 8;
    const height = 48.0;
    const gap = 10.0;

    double top = rootOrigin.dy + first.top - gap - height;
    if (top < safeTop) top = rootOrigin.dy + last.bottom + gap;
    top = top.clamp(safeTop, math.max(safeTop, safeBottom - height));

    return _follow(
      Offset(-rootOrigin.dx, top - rootOrigin.dy),
      SizedBox(
        width: size.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ValueListenableBuilder<bool>(
            valueListenable: _toolbarVisible,
            builder: (ctx, visible, _) => IgnorePointer(
              ignoring: !visible,
              child: AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: Center(child: _pill(ctx)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final l10n = AppLocalizations.of(ctx)!;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolbarButton(cs, l10n.msgActionsCopy, _copy),
          Container(
            width: 1,
            height: 24,
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
          _toolbarButton(cs, l10n.msgActionsSelectAll, _selectAll),
        ],
      ),
    );
  }

  Widget _toolbarButton(ColorScheme cs, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        child: Text(
          label,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CompositedTransformTarget(
      link: _link,
      child: CustomPaint(
        painter: _HighlightPainter(
          rootKey: _textKey,
          slices: _slices,
          selection: _selection,
          animation: _entrance,
          fill: cs.primary.withValues(alpha: 0.28),
          stem: cs.primary,
        ),
        child: KeyedSubtree(key: _textKey, child: widget.child),
      ),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final GlobalKey rootKey;
  final List<_ParaSlice> slices;
  final TextSelection selection;
  final Animation<double> animation;
  final Color fill;
  final Color stem;

  _HighlightPainter({
    required this.rootKey,
    required this.slices,
    required this.selection,
    required this.animation,
    required this.fill,
    required this.stem,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (!selection.isValid || selection.isCollapsed) return;
    final root = rootKey.currentContext?.findRenderObject();
    if (root is! RenderBox || !root.attached || !root.hasSize) return;
    final rootOrigin = root.localToGlobal(Offset.zero);

    final rects = <Rect>[];
    for (final slice in slices) {
      if (!slice.usable) continue;
      final local = slice.clip(selection);
      if (local == null) continue;
      final delta = slice.origin - rootOrigin;
      for (final box in slice.rp.getBoxesForSelection(local)) {
        rects.add(box.toRect().shift(delta));
      }
    }
    if (rects.isEmpty) return;

    final t = animation.value.clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    final grow = 0.72 + 0.28 * eased;

    final fillPaint = Paint()..color = fill.withValues(alpha: fill.a * eased);
    for (final rect in rects) {
      final inflated = rect.inflate(0.5);
      final cy = inflated.center.dy;
      final h = inflated.height * grow;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(inflated.left, cy - h / 2, inflated.right, cy + h / 2),
          const Radius.circular(3),
        ),
        fillPaint,
      );
    }

    final stemPaint = Paint()
      ..color = stem.withValues(alpha: stem.a * eased)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final first = rects.first;
    final last = rects.last;
    canvas.drawLine(
      Offset(first.left, first.top),
      Offset(first.left, first.bottom),
      stemPaint,
    );
    canvas.drawLine(
      Offset(last.right, last.top),
      Offset(last.right, last.bottom),
      stemPaint,
    );
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.selection != selection ||
      old.slices.length != slices.length ||
      old.fill != fill ||
      old.stem != stem;
}
