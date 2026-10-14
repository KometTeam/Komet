import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class QuoteGlyphBox extends SingleChildRenderObjectWidget {
  const QuoteGlyphBox({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    required Widget super.child,
  });

  final IconData icon;
  final double size;
  final Color color;

  QuoteGlyph _glyphOf(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final iconSize = (iconTheme.applyTextScaling ?? false)
        ? MediaQuery.textScalerOf(context).scale(size)
        : size;
    final opacity = iconTheme.opacity ?? 1.0;
    final weight = iconTheme.weight;
    final grade = iconTheme.grade;
    final opticalSize = iconTheme.opticalSize;
    return QuoteGlyph(
      size: iconSize,
      locale: Localizations.maybeLocaleOf(context),
      span: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontVariations: [
            const FontVariation('FILL', 1),
            if (weight != null) FontVariation('wght', weight),
            if (grade != null) FontVariation('GRAD', grade),
            if (opticalSize != null) FontVariation('opsz', opticalSize),
          ],
          inherit: false,
          color: opacity == 1.0
              ? color
              : color.withValues(alpha: color.a * opacity),
          fontSize: iconSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontFamilyFallback: icon.fontFamilyFallback,
          shadows: iconTheme.shadows,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }

  @override
  RenderQuoteGlyphBox createRenderObject(BuildContext context) =>
      RenderQuoteGlyphBox(
        glyph: _glyphOf(context),
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderQuoteGlyphBox renderObject,
  ) {
    renderObject
      ..glyph = _glyphOf(context)
      ..textDirection = Directionality.of(context);
  }
}

@immutable
class QuoteGlyph {
  const QuoteGlyph({
    required this.span,
    required this.size,
    required this.locale,
  });

  final TextSpan span;
  final double size;
  final Locale? locale;

  @override
  bool operator ==(Object other) =>
      other is QuoteGlyph &&
      other.span == span &&
      other.size == size &&
      other.locale == locale;

  @override
  int get hashCode => Object.hash(span, size, locale);
}

class RenderQuoteGlyphBox extends RenderShiftedBox {
  RenderQuoteGlyphBox({
    required QuoteGlyph glyph,
    required TextDirection textDirection,
    RenderBox? child,
  }) : _glyph = glyph,
       _textDirection = textDirection,
       super(child);

  final TextPainter _painter = TextPainter();
  final LayerHandle<ClipRectLayer> _clipLayer = LayerHandle<ClipRectLayer>();
  bool _painterDirty = true;

  QuoteGlyph _glyph;
  set glyph(QuoteGlyph value) {
    if (value == _glyph) return;
    _glyph = value;
    _painterDirty = true;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _painterDirty = true;
    markNeedsLayout();
  }

  TextPainter get _laidOutGlyph {
    if (_painterDirty) {
      _painter
        ..text = _glyph.span
        ..textDirection = _textDirection
        ..locale = _glyph.locale
        ..layout(maxWidth: _glyph.size);
      _painterDirty = false;
    }
    return _painter;
  }

  Offset get _glyphInset {
    final painter = _laidOutGlyph;
    final box = Size.square(_glyph.size);
    final text = BoxConstraints.loose(box).constrain(painter.size);
    return Alignment.center.alongOffset(box - text as Offset);
  }

  Offset _glyphOffset(Size boxSize) =>
      Offset(boxSize.width - _glyph.size, 0) + _glyphInset;

  double get _glyphBaseline =>
      _laidOutGlyph.computeDistanceToActualBaseline(TextBaseline.alphabetic) +
      _glyphInset.dy;

  bool get _glyphOverflows =>
      size.width < _glyph.size || size.height < _glyph.size;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(child.getDryLayout(constraints.loosen()));
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final child = this.child;
    final fromChild = child == null
        ? BaselineOffset.noBaseline
        : BaselineOffset(child.getDryBaseline(constraints.loosen(), baseline));
    return fromChild.minOf(BaselineOffset(_glyphBaseline)).offset;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final child = this.child;
    final fromChild = child == null
        ? BaselineOffset.noBaseline
        : BaselineOffset(child.getDistanceToActualBaseline(baseline)) +
              (child.parentData! as BoxParentData).offset.dy;
    return fromChild.minOf(BaselineOffset(_glyphBaseline)).offset;
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints.loosen(), parentUsesSize: true);
    size = constraints.constrain(child.size);
    (child.parentData! as BoxParentData).offset = AlignmentDirectional.topStart
        .resolve(_textDirection)
        .alongOffset(size - child.size as Offset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_glyphOverflows) {
      _clipLayer.layer = null;
      _paintContents(context, offset);
      return;
    }
    _clipLayer.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintContents,
      oldLayer: _clipLayer.layer,
    );
  }

  void _paintContents(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _laidOutGlyph.paint(context.canvas, offset + _glyphOffset(size));
  }

  @override
  void dispose() {
    _clipLayer.layer = null;
    _painter.dispose();
    super.dispose();
  }
}
