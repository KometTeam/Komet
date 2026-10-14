import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

abstract final class TelegramMotion {
  static const Duration duration = Duration(milliseconds: 250);
  static const Curve move = Cubic(
    0.19919472913616398,
    0.010644531250000006,
    0.27920937042459737,
    0.91025390625,
  );
  static const Curve _easeOutQuint = Cubic(0.23, 1, 0.32, 1);
  static const Curve _easeOut = Cubic(0, 0, 0.58, 1);

  static double horizontal(double t) =>
      _easeOut.transform(_easeOutQuint.transform(t));

  static double reveal(double t) => t >= 0.4 ? 1 : t / 0.4;
}

class MessageEnter extends StatefulWidget {
  const MessageEnter({
    super.key,
    required this.entering,
    this.progress,
    this.hidden = false,
    required this.child,
  });

  final bool entering;
  final Animation<double>? progress;
  final bool hidden;
  final Widget child;

  static double pendingRiseOf(RenderObject descendant) {
    RenderObject? node = descendant;
    while (node != null && node is! _RenderMessageEnter) {
      node = node.parent;
    }
    return node is _RenderMessageEnter ? node.pendingRise : 0;
  }

  @override
  State<MessageEnter> createState() => _MessageEnterState();
}

class _MessageEnterState extends State<MessageEnter>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;
  Animation<double>? _driver;

  @override
  void initState() {
    super.initState();
    if (!widget.entering) return;
    final driver =
        widget.progress ??
        (_own = AnimationController(
          vsync: this,
          duration: TelegramMotion.duration,
        ));
    if (driver.isCompleted) return;
    _driver = driver;
    driver.addStatusListener(_onStatus);
    _own?.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (!status.isCompleted) return;
    _release();
    if (mounted) setState(() {});
  }

  void _release() {
    _driver?.removeStatusListener(_onStatus);
    _driver = null;
  }

  @override
  void dispose() {
    _release();
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _MessageEnterBox(
    animation: _driver,
    hidden: widget.hidden,
    child: widget.child,
  );
}

class _MessageEnterBox extends SingleChildRenderObjectWidget {
  const _MessageEnterBox({
    required this.animation,
    required this.hidden,
    required Widget super.child,
  });

  final Animation<double>? animation;
  final bool hidden;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageEnter(animation: animation, hidden: hidden);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMessageEnter renderObject,
  ) {
    renderObject
      ..animation = animation
      ..hidden = hidden;
  }
}

class _RenderMessageEnter extends RenderProxyBox {
  _RenderMessageEnter({
    required Animation<double>? animation,
    required bool hidden,
  }) : _animation = animation,
       _hidden = hidden;

  Animation<double>? _animation;
  set animation(Animation<double>? value) {
    if (identical(value, _animation)) return;
    if (attached) _animation?.removeListener(markNeedsLayout);
    _animation = value;
    if (attached) _animation?.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  bool _hidden;
  set hidden(bool value) {
    if (value == _hidden) return;
    _hidden = value;
    markNeedsPaint();
  }

  double get _factor {
    final animation = _animation;
    if (animation == null) return 1;
    return TelegramMotion.move.transform(animation.value.clamp(0.0, 1.0));
  }

  double get pendingRise {
    final child = this.child;
    if (child == null || !child.hasSize) return 0;
    return (1 - _factor) * child.size.height;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation?.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _animation?.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(width) * _factor;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(width) * _factor;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final size = child.getDryLayout(constraints);
    return constraints.constrain(Size(size.width, size.height * _factor));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width, child.size.height * _factor),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_hidden) return;
    super.paint(context, offset);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_hidden) return false;
    return super.hitTest(result, position: position);
  }
}
