import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'animated_overlay_popup.dart';
import 'custom_notification.dart';

const Duration _defaultHintDuration = Duration(milliseconds: 2200);

class HintBubbleStyle {
  static const double maxWidth = 320;
  static const double anchorGap = 8;
  static const double screenMargin = 8;
  static const double radius = 10;
  static const Size tail = Size(14, 6);
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );
  static const BoxShadow shadow = BoxShadow(
    color: Color(0x47000000),
    blurRadius: 14,
    offset: Offset(0, 4),
  );

  static Color fill(ColorScheme cs) => cs.surfaceContainerHighest;

  static Color outline(ColorScheme cs) =>
      cs.outlineVariant.withValues(alpha: 0.5);

  static BoxDecoration decoration(ColorScheme cs) => BoxDecoration(
    color: fill(cs),
    borderRadius: const BorderRadius.all(Radius.circular(radius)),
    border: Border.all(color: outline(cs)),
    boxShadow: const [shadow],
  );

  static TextStyle textStyle(ColorScheme cs) => TextStyle(
    color: cs.onSurface,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  static TooltipThemeData tooltipTheme(ColorScheme cs) => TooltipThemeData(
    decoration: decoration(cs),
    textStyle: textStyle(cs),
    padding: padding,
    margin: const EdgeInsets.all(screenMargin),
  );
}

OverlayEntry? _activeHint;
Offset? _lastPress;
bool _trackingPresses = false;

void trackHintBubblePresses() {
  if (_trackingPresses) return;
  _trackingPresses = true;
  GestureBinding.instance.pointerRouter.addGlobalRoute(_recordPress);
}

void _recordPress(PointerEvent event) {
  if (event is PointerDownEvent) _lastPress = event.position;
}

void showHintBubble(
  BuildContext anchor,
  String message, {
  Duration duration = _defaultHintDuration,
}) {
  final overlay = Overlay.of(anchor);
  final anchorRect = _anchorRectIn(overlay, anchor);
  if (anchorRect == null) {
    showCustomNotificationOnOverlay(overlay, message);
    return;
  }
  _dismissHint(_activeHint);
  final themes = InheritedTheme.capture(from: anchor, to: overlay.context);
  final pressDx = _pressDxWithin(overlay, anchorRect);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => themes.wrap(
      _HintLayer(
        overlay: overlay,
        anchor: anchor,
        initialAnchorRect: anchorRect,
        pressDx: pressDx,
        message: message,
        duration: duration,
        onDismiss: () => _dismissHint(entry),
      ),
    ),
  );
  _activeHint = entry;
  overlay.insert(entry);
}

void _dismissHint(OverlayEntry? entry) {
  if (entry == null) return;
  if (identical(_activeHint, entry)) _activeHint = null;
  if (!entry.mounted) return;
  entry
    ..remove()
    ..dispose();
}

Rect? _anchorRectIn(OverlayState overlay, BuildContext anchor) {
  if (!overlay.mounted || !anchor.mounted) return null;
  final anchorBox = anchor.findRenderObject();
  final overlayBox = overlay.context.findRenderObject();
  if (anchorBox is! RenderBox || !anchorBox.attached || !anchorBox.hasSize) {
    return null;
  }
  if (overlayBox is! RenderBox || !overlayBox.attached) return null;
  return MatrixUtils.transformRect(
    anchorBox.getTransformTo(overlayBox),
    Offset.zero & anchorBox.size,
  );
}

double? _pressDxWithin(OverlayState overlay, Rect anchorRect) {
  final press = _lastPress;
  final overlayBox = overlay.context.findRenderObject();
  if (press == null || overlayBox is! RenderBox) return null;
  final local = overlayBox.globalToLocal(press);
  return anchorRect.contains(local) ? local.dx - anchorRect.left : null;
}

class _HintLayer extends StatefulWidget {
  final OverlayState overlay;
  final BuildContext anchor;
  final Rect initialAnchorRect;
  final double? pressDx;
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;

  const _HintLayer({
    required this.overlay,
    required this.anchor,
    required this.initialAnchorRect,
    required this.pressDx,
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_HintLayer> createState() => _HintLayerState();
}

class _HintLayerState extends State<_HintLayer>
    with SingleTickerProviderStateMixin, AnimatedOverlayPopup<_HintLayer> {
  late Rect _anchorRect = widget.initialAnchorRect;
  late final Timer _lifetime;

  @override
  Duration get overlayForwardDuration => const Duration(milliseconds: 140);

  @override
  Duration get overlayReverseDuration => const Duration(milliseconds: 120);

  @override
  VoidCallback get onOverlayDismiss => widget.onDismiss;

  @override
  void initState() {
    super.initState();
    _lifetime = Timer(widget.duration, closeOverlay);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    _followAnchor();
  }

  @override
  void dispose() {
    _lifetime.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    super.dispose();
  }

  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerSignalEvent) {
      closeOverlay();
    }
  }

  void _followAnchor() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rect = _anchorRectIn(widget.overlay, widget.anchor);
      if (rect == null) {
        widget.onDismiss();
        return;
      }
      if (rect != _anchorRect) setState(() => _anchorRect = rect);
      _followAnchor();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final pressDx = widget.pressDx;
    return Positioned.fill(
      child: IgnorePointer(
        child: FadeTransition(
          opacity: overlayAnimation,
          child: Material(
            type: MaterialType.transparency,
            child: _HintBubbleBox(
              anchor: _anchorRect,
              pressX: pressDx == null ? null : _anchorRect.left + pressDx,
              insets: media.padding + media.viewInsets,
              fill: HintBubbleStyle.fill(cs),
              outline: HintBubbleStyle.outline(cs),
              growth: overlayAnimation,
              child: Semantics(
                liveRegion: true,
                child: Padding(
                  padding: HintBubbleStyle.padding,
                  child: Text(
                    widget.message,
                    style: HintBubbleStyle.textStyle(cs),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintBubbleBox extends SingleChildRenderObjectWidget {
  final Rect anchor;
  final double? pressX;
  final EdgeInsets insets;
  final Color fill;
  final Color outline;
  final Animation<double> growth;

  const _HintBubbleBox({
    required this.anchor,
    required this.pressX,
    required this.insets,
    required this.fill,
    required this.outline,
    required this.growth,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHintBubble(
    anchor: anchor,
    pressX: pressX,
    insets: insets,
    fill: fill,
    outline: outline,
    growth: growth,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHintBubble renderObject,
  ) {
    renderObject
      ..anchor = anchor
      ..pressX = pressX
      ..insets = insets
      ..fill = fill
      ..outline = outline
      ..growth = growth;
  }
}

class _RenderHintBubble extends RenderShiftedBox {
  _RenderHintBubble({
    required Rect anchor,
    required double? pressX,
    required EdgeInsets insets,
    required Color fill,
    required Color outline,
    required Animation<double> growth,
  }) : _anchor = anchor,
       _pressX = pressX,
       _insets = insets,
       _fill = fill,
       _outline = outline,
       _growth = growth,
       super(null);

  static const double _restingScale = 0.92;
  static const double _tipRounding = 1.5;

  Rect _anchor;
  set anchor(Rect value) {
    if (value == _anchor) return;
    _anchor = value;
    markNeedsLayout();
  }

  double? _pressX;
  set pressX(double? value) {
    if (value == _pressX) return;
    _pressX = value;
    markNeedsLayout();
  }

  EdgeInsets _insets;
  set insets(EdgeInsets value) {
    if (value == _insets) return;
    _insets = value;
    markNeedsLayout();
  }

  Color _fill;
  set fill(Color value) {
    if (value == _fill) return;
    _fill = value;
    markNeedsPaint();
  }

  Color _outline;
  set outline(Color value) {
    if (value == _outline) return;
    _outline = value;
    markNeedsPaint();
  }

  Animation<double> _growth;
  set growth(Animation<double> value) {
    if (identical(value, _growth)) return;
    if (attached) _growth.removeListener(markNeedsPaint);
    _growth = value;
    if (attached) _growth.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  VerticalDirection? _tailTowards;
  double _tipX = 0;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _growth.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _growth.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    final bubble = child;
    if (bubble == null) return;
    const margin = HintBubbleStyle.screenMargin;
    bubble.layout(
      BoxConstraints(
        maxWidth: math.max(
          0,
          math.min(
            HintBubbleStyle.maxWidth,
            size.width - _insets.horizontal - margin * 2,
          ),
        ),
        maxHeight: math.max(0, size.height - _insets.vertical - margin * 2),
      ),
      parentUsesSize: true,
    );
    final bubbleSize = bubble.size;
    final target = _pressX ?? _anchor.center.dx;

    final minLeft = _insets.left + margin;
    final maxLeft = math.max(
      minLeft,
      size.width - _insets.right - margin - bubbleSize.width,
    );
    final left = (target - bubbleSize.width / 2).clamp(minLeft, maxLeft);

    final topLimit = _insets.top + margin;
    final bottomLimit = size.height - _insets.bottom - margin;
    final above = _anchor.top - HintBubbleStyle.anchorGap - bubbleSize.height;
    final below = _anchor.bottom + HintBubbleStyle.anchorGap;

    final double top;
    if (above >= topLimit) {
      top = above;
      _tailTowards = VerticalDirection.down;
    } else if (below + bubbleSize.height <= bottomLimit) {
      top = below;
      _tailTowards = VerticalDirection.up;
    } else {
      top = math.max(topLimit, bottomLimit - bubbleSize.height);
      _tailTowards = null;
    }
    (bubble.parentData! as BoxParentData).offset = Offset(left, top);

    final tipInset = HintBubbleStyle.radius + HintBubbleStyle.tail.width / 2;
    _tipX = bubbleSize.width < tipInset * 2
        ? left + bubbleSize.width / 2
        : target.clamp(left + tipInset, left + bubbleSize.width - tipInset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final bubble = child;
    if (bubble == null) return;
    final bubbleOffset = (bubble.parentData! as BoxParentData).offset;
    final body = bubbleOffset & bubble.size;
    final pivot = switch (_tailTowards) {
      VerticalDirection.down => Offset(
        _tipX,
        body.bottom + HintBubbleStyle.tail.height,
      ),
      VerticalDirection.up => Offset(
        _tipX,
        body.top - HintBubbleStyle.tail.height,
      ),
      null => body.center,
    };
    final scale = _restingScale + (1 - _restingScale) * _growth.value;
    final transform = Matrix4.translationValues(pivot.dx, pivot.dy, 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1))
      ..multiply(Matrix4.translationValues(-pivot.dx, -pivot.dy, 0));
    layer = context.pushTransform(needsCompositing, offset, transform, (
      context,
      offset,
    ) {
      final shape = _shape(body.shift(offset), _tipX + offset.dx);
      context.canvas
        ..drawPath(
          shape.shift(HintBubbleStyle.shadow.offset),
          HintBubbleStyle.shadow.toPaint(),
        )
        ..drawPath(shape, Paint()..color = _fill)
        ..drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = _outline,
        );
      context.paintChild(bubble, bubbleOffset + offset);
    }, oldLayer: layer as TransformLayer?);
  }

  Path _shape(Rect body, double tipX) {
    final rounded = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          body,
          const Radius.circular(HintBubbleStyle.radius),
        ),
      );
    final towards = _tailTowards;
    if (towards == null) return rounded;

    final sign = towards == VerticalDirection.down ? 1.0 : -1.0;
    final edge = towards == VerticalDirection.down ? body.bottom : body.top;
    final half = HintBubbleStyle.tail.width / 2;
    final tipY = edge + sign * HintBubbleStyle.tail.height;
    final shoulderY =
        tipY - sign * HintBubbleStyle.tail.height * _tipRounding / half;
    final tail = Path()
      ..moveTo(tipX - half, edge - sign)
      ..lineTo(tipX - half, edge)
      ..quadraticBezierTo(
        tipX - half * 0.45,
        edge,
        tipX - _tipRounding,
        shoulderY,
      )
      ..quadraticBezierTo(tipX, tipY, tipX + _tipRounding, shoulderY)
      ..quadraticBezierTo(tipX + half * 0.45, edge, tipX + half, edge)
      ..lineTo(tipX + half, edge - sign)
      ..close();
    return Path.combine(PathOperation.union, rounded, tail);
  }
}
