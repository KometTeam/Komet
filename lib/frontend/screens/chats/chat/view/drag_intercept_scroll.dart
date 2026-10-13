import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

typedef DragIntercept = double Function(ScrollMetrics position, double delta);

class DragInterceptScrollController extends ScrollController {
  DragInterceptScrollController({required this.intercept});

  final DragIntercept intercept;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _DragInterceptScrollPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    initialPixels: initialScrollOffset,
    keepScrollOffset: keepScrollOffset,
    debugLabel: debugLabel,
    intercept: intercept,
  );
}

class _DragInterceptScrollPosition extends ScrollPositionWithSingleContext {
  _DragInterceptScrollPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    super.initialPixels,
    super.keepScrollOffset,
    super.debugLabel,
    required this.intercept,
  });

  final DragIntercept intercept;

  @override
  void applyUserOffset(double delta) {
    final rest = delta - intercept(this, delta);
    if (rest != 0) {
      super.applyUserOffset(rest);
      return;
    }
    if (delta != 0) {
      updateUserScrollDirection(
        delta > 0 ? ScrollDirection.forward : ScrollDirection.reverse,
      );
    }
  }
}
