import 'package:flutter/widgets.dart';

class RetainOffsetScrollPhysics extends ScrollPhysics {
  const RetainOffsetScrollPhysics({super.parent, required this.retain});

  final bool Function() retain;

  @override
  RetainOffsetScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      RetainOffsetScrollPhysics(parent: buildParent(ancestor), retain: retain);

  @override
  double adjustPositionForNewDimensions({
    required ScrollMetrics oldPosition,
    required ScrollMetrics newPosition,
    required bool isScrolling,
    required double velocity,
  }) {
    final adjusted = super.adjustPositionForNewDimensions(
      oldPosition: oldPosition,
      newPosition: newPosition,
      isScrolling: isScrolling,
      velocity: velocity,
    );
    if (!retain()) return adjusted;
    final grown = newPosition.maxScrollExtent - oldPosition.maxScrollExtent;
    if (grown <= 0) return adjusted;
    return (adjusted + grown).clamp(
      newPosition.minScrollExtent,
      newPosition.maxScrollExtent,
    );
  }
}
