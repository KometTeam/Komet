import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

enum BubbleSlot { root, background, text }

class BubbleGeometry {
  RenderBox? root;
  RenderBox? background;
  RenderBox? text;
  double? textBaseline;
  Widget? bubble;

  RenderBox? boxOf(BubbleSlot slot) => switch (slot) {
    BubbleSlot.root => root,
    BubbleSlot.background => background,
    BubbleSlot.text => text,
  };

  void _attach(BubbleSlot slot, RenderBox box) {
    switch (slot) {
      case BubbleSlot.root:
        root = box;
      case BubbleSlot.background:
        background = box;
      case BubbleSlot.text:
        text = box;
    }
  }

  void _detach(BubbleSlot slot, RenderBox box) {
    if (boxOf(slot) != box) return;
    switch (slot) {
      case BubbleSlot.root:
        root = null;
        bubble = null;
      case BubbleSlot.background:
        background = null;
      case BubbleSlot.text:
        text = null;
        textBaseline = null;
    }
  }
}

class BubbleChrome extends InheritedWidget {
  const BubbleChrome({super.key, required super.child});

  static bool hiddenOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BubbleChrome>() != null;

  @override
  bool updateShouldNotify(BubbleChrome oldWidget) => false;
}

class BubbleGeometryReporter extends SingleChildRenderObjectWidget {
  const BubbleGeometryReporter({
    super.key,
    required this.geometry,
    required this.slot,
    this.bubble,
    required Widget super.child,
  });

  final BubbleGeometry? geometry;
  final BubbleSlot slot;
  final Widget? bubble;

  @override
  RenderBubbleGeometryReporter createRenderObject(BuildContext context) =>
      RenderBubbleGeometryReporter(slot)..report(geometry, bubble);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBubbleGeometryReporter renderObject,
  ) {
    renderObject.report(geometry, bubble);
  }
}

class RenderBubbleGeometryReporter extends RenderProxyBox {
  RenderBubbleGeometryReporter(this._slot);

  final BubbleSlot _slot;
  BubbleGeometry? _geometry;

  void report(BubbleGeometry? geometry, Widget? bubble) {
    if (!identical(geometry, _geometry)) {
      _geometry?._detach(_slot, this);
      _geometry = geometry;
    }
    final target = _geometry;
    if (target == null) return;
    target._attach(_slot, this);
    if (_slot == BubbleSlot.root) target.bubble = bubble;
  }

  @override
  void detach() {
    _geometry?._detach(_slot, this);
    super.detach();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _geometry?._attach(_slot, this);
  }

  @override
  void performLayout() {
    super.performLayout();
    final geometry = _geometry;
    final child = this.child;
    if (geometry == null || child == null || _slot != BubbleSlot.text) return;
    geometry.textBaseline = child.getDistanceToBaseline(
      TextBaseline.alphabetic,
      onlyReal: true,
    );
  }
}
