import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'quote_glyph_box.dart';

class TextWithMeta extends MultiChildRenderObjectWidget {
  final bool fillWidth;

  TextWithMeta({
    super.key,
    required Widget text,
    required Widget meta,
    this.fillWidth = false,
  }) : super(children: [text, meta]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderTextWithMeta(fillWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTextWithMeta renderObject,
  ) {
    renderObject.fillWidth = fillWidth;
  }
}

bool isPlainParagraph(RenderParagraph paragraph) =>
    paragraph.firstChild == null &&
    paragraph.maxLines == null &&
    paragraph.textWidthBasis == TextWidthBasis.parent;

class TextWithMetaParentData extends ContainerBoxParentData<RenderBox> {}

class RenderTextWithMeta extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, TextWithMetaParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, TextWithMetaParentData> {
  RenderTextWithMeta(this._fillWidth);

  static const double _gap = 8;
  static const double _baselineNudge = 2;

  bool _fillWidth;
  set fillWidth(bool value) {
    if (value == _fillWidth) return;
    _fillWidth = value;
    markNeedsLayout();
  }

  RenderBox get _text => firstChild!;
  RenderBox get _meta => lastChild!;

  InlineSpan? _measuredSpan;
  int _measuredLength = 0;
  double? _layoutIntrinsicWidth;

  double? get layoutIntrinsicWidth => _layoutIntrinsicWidth;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! TextWithMetaParentData) {
      child.parentData = TextWithMetaParentData();
    }
  }

  RenderParagraph? _soleParagraph() {
    final text = _text;
    if (text is RenderParagraph) return text;
    RenderParagraph? found;
    var seen = 0;
    void visit(RenderObject node) {
      if (seen > 1) return;
      if (node is RenderParagraph) {
        found = node;
        seen++;
        return;
      }
      if (node is RenderQuoteGlyphBox) seen++;
      node.visitChildren(visit);
    }

    text.visitChildren(visit);
    return seen == 1 ? found : null;
  }

  int _plainLength(RenderParagraph paragraph) {
    final span = paragraph.text;
    if (!identical(span, _measuredSpan)) {
      _measuredSpan = span;
      _measuredLength = span.toPlainText().length;
    }
    return _measuredLength;
  }

  double? _intrinsicWidthFromLayout(double textWidth) {
    final text = _text;
    if (constraints.minWidth > 0 ||
        text is! RenderParagraph ||
        !isPlainParagraph(text)) {
      return null;
    }
    if (textWidth >= constraints.maxWidth) return double.infinity;
    return textWidth + _gap + _meta.getMaxIntrinsicWidth(double.infinity);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _text.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _text.getMaxIntrinsicWidth(height) +
      _gap +
      _meta.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _text.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _text.getMaxIntrinsicHeight(width) + _meta.getMaxIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      BaselineOffset(_text.getDistanceToActualBaseline(baseline)).offset;

  @override
  void performLayout() {
    _meta.layout(const BoxConstraints(), parentUsesSize: true);
    final metaSize = _meta.size;

    _text.layout(constraints.loosen(), parentUsesSize: true);
    final textSize = _text.size;

    final lineWidth = _fillWidth && constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : textSize.width;
    final paragraph = _soleParagraph();
    final needed = _gap + metaSize.width;

    double width;
    double height;
    var metaOnOwnLine = false;

    if (paragraph != null) {
      final length = _plainLength(paragraph);
      final caret = paragraph.getOffsetForCaret(
        TextPosition(offset: length),
        Rect.zero,
      );
      final lastLine = caret.dx;
      final singleLine = caret.dy < 0.5;
      if (lastLine + needed <= lineWidth) {
        width = lineWidth;
        height = textSize.height;
      } else if (singleLine && lastLine + needed <= constraints.maxWidth) {
        width = lastLine + needed;
        height = textSize.height;
      } else {
        width = math.max(lineWidth, metaSize.width);
        height = textSize.height + metaSize.height;
        metaOnOwnLine = true;
      }
    } else {
      width = math.max(lineWidth, metaSize.width);
      height = textSize.height + metaSize.height;
      metaOnOwnLine = true;
    }

    size = constraints.constrain(Size(width, height));
    _layoutIntrinsicWidth = _intrinsicWidthFromLayout(textSize.width);

    (_text.parentData! as TextWithMetaParentData).offset = Offset.zero;
    (_meta.parentData! as TextWithMetaParentData).offset = Offset(
      math.max(0, size.width - metaSize.width),
      metaOnOwnLine
          ? size.height - metaSize.height
          : size.height - metaSize.height - _baselineNudge,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
