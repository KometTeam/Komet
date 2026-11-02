import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../widgets/bubble_geometry.dart';
import 'view/message_enter.dart';

class ComposerSnapshot {
  const ComposerSnapshot._({
    required this.text,
    required this.style,
    required this.textScaler,
    required this.textOrigin,
    required this.textWidth,
    required this.fieldTop,
    required this.fieldBottom,
    required this.fieldColor,
  });

  static const double _fieldPadding = 10;
  static const double _surfaceInset = 4;

  final String text;
  final TextStyle style;
  final TextScaler? textScaler;
  final Offset textOrigin;
  final double textWidth;
  final double fieldTop;
  final double fieldBottom;
  final Color fieldColor;

  static ComposerSnapshot? capture(
    FocusNode focusNode, {
    required Color fieldColor,
  }) {
    final editable = focusNode.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (editable == null) return null;
    final render = editable.renderEditable;
    if (!render.attached || !render.hasSize) return null;
    final text = editable.textEditingValue.text;
    if (text.trim().isEmpty) return null;
    final origin = render.localToGlobal(Offset.zero);
    return ComposerSnapshot._(
      text: text,
      style: editable.widget.style,
      textScaler: editable.widget.textScaler,
      textOrigin: origin.translate(0, -render.offset.pixels),
      textWidth: render.size.width,
      fieldTop: origin.dy - _fieldPadding + _surfaceInset,
      fieldBottom: origin.dy + render.size.height + _fieldPadding,
      fieldColor: fieldColor,
    );
  }
}

class MessageFlight extends ChangeNotifier {
  MessageFlight({
    required this.messageId,
    required this.from,
    required TickerProvider vsync,
  }) : controller = AnimationController(
         vsync: vsync,
         duration: TelegramMotion.duration,
       ) {
    controller.addStatusListener(_onStatus);
  }

  String messageId;
  final ComposerSnapshot? from;
  final AnimationController controller;
  final BubbleGeometry geometry = BubbleGeometry();
  bool _landed = false;

  bool get done => controller.isCompleted;

  bool get carriesBubble => from != null && !_landed && !done;

  void start() {
    if (done) return;
    final g = geometry;
    if (from != null &&
        (g.root == null ||
            g.background == null ||
            g.text == null ||
            g.bubble == null)) {
      _land();
    } else {
      notifyListeners();
    }
    controller.forward();
  }

  void complete() {
    if (done) return;
    controller.value = controller.upperBound;
  }

  void retarget(String previousId, String nextId) {
    if (messageId == previousId) messageId = nextId;
  }

  void _land() {
    if (_landed) return;
    _landed = true;
    notifyListeners();
  }

  void _onStatus(AnimationStatus status) {
    if (status.isCompleted) notifyListeners();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class MessageFlightLayer extends StatelessWidget {
  const MessageFlightLayer({
    super.key,
    required this.flight,
    required this.child,
  });

  final ValueListenable<MessageFlight?> flight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(child: _scene()),
      ],
    );
  }

  Widget _scene() {
    return ValueListenableBuilder<MessageFlight?>(
      valueListenable: flight,
      builder: (context, flight, _) {
        final from = flight?.from;
        if (flight == null || from == null) return const SizedBox.expand();
        return ListenableBuilder(
          listenable: flight,
          builder: (context, _) {
            final bubble = flight.geometry.bubble;
            return _FlightScene(
              flight: flight,
              textDirection: Directionality.of(context),
              children: [
                Text(from.text, style: from.style, textScaler: from.textScaler),
                if (bubble != null) BubbleChrome(child: bubble),
              ],
            );
          },
        );
      },
    );
  }
}

class _FlightScene extends MultiChildRenderObjectWidget {
  const _FlightScene({
    required this.flight,
    required this.textDirection,
    required super.children,
  });

  final MessageFlight flight;
  final TextDirection textDirection;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFlightScene(flight, textDirection);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFlightScene renderObject,
  ) {
    renderObject
      ..flight = flight
      ..textDirection = textDirection;
  }
}

class _FlightSceneParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderFlightScene extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FlightSceneParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FlightSceneParentData> {
  _RenderFlightScene(this._flight, this._textDirection);

  static const double _trailingSlack = 4;
  static const double _contentInset = 4;

  MessageFlight _flight;
  set flight(MessageFlight value) {
    if (identical(value, _flight)) return;
    if (attached) _unlisten();
    _flight = value;
    if (attached) _listen();
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
  }

  final Paint _fill = Paint();
  double? _fromBaseline;
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<OpacityLayer> _textFade = LayerHandle<OpacityLayer>();
  final LayerHandle<OpacityLayer> _bubbleFade = LayerHandle<OpacityLayer>();

  void _listen() {
    _flight.controller.addListener(markNeedsPaint);
    _flight.addListener(markNeedsPaint);
  }

  void _unlisten() {
    _flight.controller.removeListener(markNeedsPaint);
    _flight.removeListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _listen();
  }

  @override
  void detach() {
    _unlisten();
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    _textFade.layer = null;
    _bubbleFade.layer = null;
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FlightSceneParentData) {
      child.parentData = _FlightSceneParentData();
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  @override
  void performLayout() {
    final text = firstChild;
    final from = _flight.from;
    if (text != null && from != null) {
      text.layout(
        BoxConstraints.tightFor(width: from.textWidth),
        parentUsesSize: true,
      );
      _fromBaseline = text.getDistanceToBaseline(
        TextBaseline.alphabetic,
        onlyReal: true,
      );
    }
    final bubble = text == null ? null : childAfter(text);
    bubble?.layout(BoxConstraints.tightFor(width: size.width));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final frame = _frame();
    if (frame == null) {
      _clip.layer = null;
      _textFade.layer = null;
      _bubbleFade.layer = null;
      return;
    }
    final canvas = context.canvas;
    if (frame.reveal < 1) {
      _fill.color = frame.fieldColor;
      canvas.drawRRect(frame.radius.toRRect(frame.shape.shift(offset)), _fill);
    }
    _fill.color = frame.bubbleColor.withValues(
      alpha: frame.bubbleColor.a * frame.reveal,
    );
    canvas.drawRRect(frame.radius.toRRect(frame.shape.shift(offset)), _fill);

    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      frame.shape.deflate(_contentInset),
      (context, offset) => _paintContent(context, offset, frame),
      oldLayer: _clip.layer,
    );
  }

  void _paintContent(PaintingContext context, Offset offset, _Frame frame) {
    final text = firstChild;
    final bubble = text == null ? null : childAfter(text);
    if (text != null && frame.reveal < 1) {
      _textFade.layer = context.pushOpacity(
        offset + frame.textAt,
        ((1 - frame.reveal) * 255).round(),
        (context, offset) => context.paintChild(text, offset),
        oldLayer: _textFade.layer,
      );
    } else {
      _textFade.layer = null;
    }
    if (bubble != null) {
      _bubbleFade.layer = context.pushOpacity(
        offset + frame.bubbleAt,
        (frame.reveal * 255).round(),
        (context, offset) => context.paintChild(bubble, offset),
        oldLayer: _bubbleFade.layer,
      );
    } else {
      _bubbleFade.layer = null;
    }
  }

  _Frame? _frame() {
    final flight = _flight;
    final from = flight.from;
    final g = flight.geometry;
    final root = g.root;
    final background = g.background;
    final text = g.text;
    if (from == null ||
        !flight.carriesBubble ||
        root == null ||
        background == null ||
        text == null ||
        !root.attached ||
        !background.attached ||
        !text.attached ||
        !root.hasSize ||
        !background.hasSize) {
      return null;
    }
    final decoration = _decorationOf(background);
    if (decoration == null) return null;

    final rise = MessageEnter.pendingRiseOf(root);
    Offset local(Offset global) => globalToLocal(global);
    Offset placed(RenderBox box) =>
        local(box.localToGlobal(Offset.zero)).translate(0, -rise);
    final rootAt = placed(root);
    final bubbleRect = placed(background) & background.size;
    final textTo = placed(text);
    final textFrom = local(from.textOrigin);
    final fieldTop = local(Offset(0, from.fieldTop)).dy;
    final fieldBottom = local(Offset(0, from.fieldBottom)).dy;

    final t = flight.controller.value;
    final vertical = TelegramMotion.move.transform(t);
    final horizontal = TelegramMotion.horizontal(t);
    final shift = Offset(
      (textFrom.dx - textTo.dx) * (1 - horizontal),
      (textFrom.dy - textTo.dy) * (1 - vertical),
    );
    final fromBaseline = _fromBaseline;
    final toBaseline = g.textBaseline;
    final baselineGap = fromBaseline == null || toBaseline == null
        ? 0.0
        : toBaseline - fromBaseline;
    return _Frame(
      shape: Rect.fromLTRB(
        bubbleRect.left + shift.dx,
        _lerp(fieldTop, bubbleRect.top, vertical),
        bubbleRect.right + _trailingSlack * (1 - horizontal),
        _lerp(fieldBottom, bubbleRect.bottom, vertical),
      ),
      radius: (decoration.borderRadius ?? BorderRadius.zero).resolve(
        _textDirection,
      ),
      fieldColor: from.fieldColor,
      bubbleColor: decoration.color ?? const Color(0x00000000),
      reveal: TelegramMotion.reveal(t),
      textAt: textTo + shift + Offset(0, baselineGap * vertical),
      bubbleAt: rootAt + shift - Offset(0, baselineGap * (1 - vertical)),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static BoxDecoration? _decorationOf(RenderBox box) {
    RenderObject? node = box;
    while (node != null) {
      if (node is RenderDecoratedBox) {
        final decoration = node.decoration;
        return decoration is BoxDecoration ? decoration : null;
      }
      node = node is RenderObjectWithChildMixin ? node.child : null;
    }
    return null;
  }
}

class _Frame {
  const _Frame({
    required this.shape,
    required this.radius,
    required this.fieldColor,
    required this.bubbleColor,
    required this.reveal,
    required this.textAt,
    required this.bubbleAt,
  });

  final Rect shape;
  final BorderRadius radius;
  final Color fieldColor;
  final Color bubbleColor;
  final double reveal;
  final Offset textAt;
  final Offset bubbleAt;
}
