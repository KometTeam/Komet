import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/utils/haptics.dart';
import '../../l10n/app_localizations.dart';
import 'custom_notification.dart';

RenderParagraph? _findParagraph(RenderObject? ro) {
  if (ro == null) return null;
  if (ro is RenderParagraph) return ro;
  RenderParagraph? found;
  ro.visitChildren((child) {
    found ??= _findParagraph(child);
  });
  return found;
}

bool _isSpace(int c) =>
    c == 0x20 ||
    c == 0x09 ||
    c == 0x0A ||
    c == 0x0D ||
    c == 0x0C ||
    c == 0xA0;

class SelectableMessageText extends StatefulWidget {
  final Widget child;
  final Offset initialGlobalPosition;
  final VoidCallback onExit;

  const SelectableMessageText({
    super.key,
    required this.child,
    required this.initialGlobalPosition,
    required this.onExit,
  });

  @override
  State<SelectableMessageText> createState() => _SelectableMessageTextState();
}

class _SelectableMessageTextState extends State<SelectableMessageText>
    with SingleTickerProviderStateMixin {
  static const double _ballRadius = 8.0;
  static const double _hitSize = 44.0;

  final GlobalKey _textKey = GlobalKey();
  final ValueNotifier<bool> _toolbarVisible = ValueNotifier(false);

  late final AnimationController _entrance;
  OverlayEntry? _overlay;
  Timer? _settle;
  TextSelection _selection = const TextSelection.collapsed(offset: 0);
  String? _cachedText;
  bool _dragging = false;
  bool _exiting = false;

  RenderParagraph? _cachedParagraph;

  RenderParagraph? get _paragraph {
    final cached = _cachedParagraph;
    if (cached != null && cached.attached) return cached;
    return _cachedParagraph = _findParagraph(
      _textKey.currentContext?.findRenderObject(),
    );
  }

  String _text(RenderParagraph rp) => _cachedText ??= rp.text.toPlainText();

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() => _overlay?.markNeedsBuild());
    WidgetsBinding.instance.addPostFrameCallback((_) => _init(4));
  }

  @override
  void dispose() {
    _settle?.cancel();
    _entrance.dispose();
    _overlay?.remove();
    _overlay = null;
    _toolbarVisible.dispose();
    super.dispose();
  }

  void _init(int retries) {
    if (!mounted) return;
    final rp = _paragraph;
    if (rp == null || !rp.hasSize) {
      if (retries > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _init(retries - 1));
      } else {
        _requestExit();
      }
      return;
    }
    _selectWordAt(widget.initialGlobalPosition, rp);
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

  TextSelection _normalize(int a, int b) => TextSelection(
    baseOffset: math.min(a, b),
    extentOffset: math.max(a, b),
  );

  void _applySelection(TextSelection sel, {bool animate = false}) {
    _selection = sel;
    if (animate) _entrance.forward(from: 0);
    if (mounted) setState(() {});
    _overlay?.markNeedsBuild();
  }

  TextRange _wordRange(RenderParagraph rp, Offset globalPos) {
    final text = _text(rp);
    final len = text.length;
    if (len == 0) return const TextRange.collapsed(0);
    final local = rp.globalToLocal(globalPos);
    var off = rp.getPositionForOffset(local).offset.clamp(0, len);
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

  void _selectWordAt(Offset globalPos, RenderParagraph rp) {
    final range = _wordRange(rp, globalPos);
    if (range.isCollapsed) {
      _applySelection(_normalize(0, _text(rp).length), animate: true);
    } else {
      _applySelection(_normalize(range.start, range.end), animate: true);
    }
  }

  void _onBackgroundTap(Offset globalPos) {
    final rp = _paragraph;
    if (rp == null || !rp.hasSize) {
      _requestExit();
      return;
    }
    final local = rp.globalToLocal(globalPos);
    if (rp.size.contains(local)) {
      _dragging = false;
      _settle?.cancel();
      _selectWordAt(globalPos, rp);
      _toolbarVisible.value = true;
    } else {
      _requestExit();
    }
  }

  void _onHandleDragStart() {
    _dragging = true;
    _settle?.cancel();
    _entrance.value = 1.0;
    _toolbarVisible.value = false;
  }

  void _onHandleDrag(Offset globalPos, bool isStart) {
    final rp = _paragraph;
    if (rp == null || !rp.hasSize) return;
    final len = _text(rp).length;
    final off = rp.getPositionForOffset(rp.globalToLocal(globalPos)).offset;
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
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 140), () {
      if (!mounted || _dragging) return;
      _overlay?.markNeedsBuild();
      _toolbarVisible.value = true;
    });
  }

  void _copy() {
    final rp = _paragraph;
    if (rp != null && _selection.isValid && !_selection.isCollapsed) {
      final text = _text(rp);
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
    final rp = _paragraph;
    if (rp == null) return;
    Haptics.tap();
    _applySelection(_normalize(0, _text(rp).length), animate: true);
    _toolbarVisible.value = true;
  }

  Widget _buildOverlay(BuildContext ctx) {
    final rp = _paragraph;
    if (rp == null || !rp.hasSize || !rp.attached) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(ctx).colorScheme;

    final List<ui.TextBox> boxes =
        (_selection.isValid && !_selection.isCollapsed)
        ? rp.getBoxesForSelection(_selection)
        : const [];

    final children = <Widget>[
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _onBackgroundTap(d.globalPosition),
        ),
      ),
    ];

    if (boxes.isNotEmpty) {
      final first = boxes.first.toRect();
      final last = boxes.last.toRect();
      final startBottom = rp.localToGlobal(Offset(first.left, first.bottom));
      final endBottom = rp.localToGlobal(Offset(last.right, last.bottom));

      children.add(_handle(cs, startBottom, isStart: true));
      children.add(_handle(cs, endBottom, isStart: false));
      children.add(_toolbar(ctx, rp, first, last));
    }

    return Stack(children: children);
  }

  Widget _handle(ColorScheme cs, Offset lineBottomGlobal, {required bool isStart}) {
    final center = Offset(
      lineBottomGlobal.dx,
      lineBottomGlobal.dy + _ballRadius,
    );
    return Positioned(
      left: center.dx - _hitSize / 2,
      top: center.dy - _hitSize / 2,
      width: _hitSize,
      height: _hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _onHandleDragStart(),
        onPanUpdate: (d) => _onHandleDrag(d.globalPosition, isStart),
        onPanEnd: (_) => _onHandleDragEnd(),
        onPanCancel: _onHandleDragEnd,
        child: Center(
          child: Transform.scale(
            scale: Curves.easeOutBack.transform(_entrance.value.clamp(0.0, 1.0)),
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
    );
  }

  Widget _toolbar(BuildContext ctx, RenderParagraph rp, Rect first, Rect last) {
    final media = MediaQuery.of(ctx);
    final size = media.size;
    final safeTop = media.padding.top + 8;
    final safeBottom = size.height - media.padding.bottom - 8;
    const height = 48.0;
    const gap = 10.0;

    final topGlobal = rp.localToGlobal(first.topLeft).dy;
    final bottomGlobal = rp.localToGlobal(Offset(last.right, last.bottom)).dy;

    double top = topGlobal - gap - height;
    if (top < safeTop) top = bottomGlobal + gap;
    top = top.clamp(safeTop, math.max(safeTop, safeBottom - height));

    return Positioned(
      left: 12,
      right: 12,
      top: top,
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
    return CustomPaint(
      painter: _HighlightPainter(
        paragraph: _paragraph,
        selection: _selection,
        animation: _entrance,
        fill: cs.primary.withValues(alpha: 0.28),
        stem: cs.primary,
      ),
      child: KeyedSubtree(key: _textKey, child: widget.child),
    );
  }
}

class _HighlightPainter extends CustomPainter {
  final RenderParagraph? paragraph;
  final TextSelection selection;
  final Animation<double> animation;
  final Color fill;
  final Color stem;

  _HighlightPainter({
    required this.paragraph,
    required this.selection,
    required this.animation,
    required this.fill,
    required this.stem,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (!selection.isValid || selection.isCollapsed) return;
    final rp = paragraph;
    if (rp == null || !rp.hasSize || !rp.attached) return;
    final boxes = rp.getBoxesForSelection(selection);
    if (boxes.isEmpty) return;

    final t = animation.value.clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    final grow = 0.72 + 0.28 * eased;

    final fillPaint = Paint()..color = fill.withValues(alpha: fill.a * eased);
    for (final box in boxes) {
      final rect = box.toRect().inflate(0.5);
      final cy = rect.center.dy;
      final h = rect.height * grow;
      final animRect = Rect.fromLTRB(
        rect.left,
        cy - h / 2,
        rect.right,
        cy + h / 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(animRect, const Radius.circular(3)),
        fillPaint,
      );
    }

    final stemPaint = Paint()
      ..color = stem.withValues(alpha: stem.a * eased)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final first = boxes.first.toRect();
    final last = boxes.last.toRect();
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
      old.paragraph != paragraph ||
      old.fill != fill ||
      old.stem != stem;
}
