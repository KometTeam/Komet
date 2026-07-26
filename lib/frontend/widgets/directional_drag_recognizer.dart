import 'package:flutter/gestures.dart';

class DirectionalDragRecognizer extends HorizontalDragGestureRecognizer {
  DirectionalDragRecognizer({
    required this.direction,
    this.minAcceptDistance = 20.0,
    this.minAcceptVelocity,
    super.debugOwner,
  }) {
    onlyAcceptDragOnThreshold = true;
  }

  final double direction;
  final double minAcceptDistance;
  final double? minAcceptVelocity;

  final Map<int, Offset> _initialPositions = {};
  final Map<int, VelocityTracker> _velocityTrackers = {};
  final Map<int, double> _currentDeltaX = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _initialPositions[event.pointer] = event.position;
    final tracker = VelocityTracker.withKind(event.kind);
    tracker.addPosition(event.timeStamp, event.localPosition);
    _velocityTrackers[event.pointer] = tracker;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _velocityTrackers[event.pointer]?.addPosition(
        event.timeStamp,
        event.localPosition,
      );
      final initial = _initialPositions[event.pointer];
      if (initial != null) {
        final dx = (event.position.dx - initial.dx) * direction;
        _currentDeltaX[event.pointer] = dx;
        if (dx < -kTouchSlop) {
          stopTrackingPointer(event.pointer);
          _cleanup(event.pointer);
          return;
        }
      }
    }
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    if (!super.hasSufficientGlobalDistanceToAccept(
      pointerDeviceKind,
      deviceTouchSlop,
    )) {
      return false;
    }
    double maxDx = 0;
    for (final dx in _currentDeltaX.values) {
      if (dx > maxDx) maxDx = dx;
    }
    if (maxDx < minAcceptDistance) return false;

    final minVelocity = minAcceptVelocity;
    if (minVelocity == null) return true;
    for (final tracker in _velocityTrackers.values) {
      final vx = tracker.getVelocity().pixelsPerSecond.dx * direction;
      if (vx >= minVelocity) return true;
    }
    return false;
  }

  void _cleanup(int pointer) {
    _initialPositions.remove(pointer);
    _velocityTrackers.remove(pointer);
    _currentDeltaX.remove(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _cleanup(pointer);
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void rejectGesture(int pointer) {
    _cleanup(pointer);
    super.rejectGesture(pointer);
  }
}

class RightwardDragRecognizer extends DirectionalDragRecognizer {
  RightwardDragRecognizer({super.debugOwner})
    : super(direction: 1, minAcceptVelocity: 700);
}

class LeftwardDragRecognizer extends DirectionalDragRecognizer {
  LeftwardDragRecognizer({super.debugOwner}) : super(direction: -1);
}
