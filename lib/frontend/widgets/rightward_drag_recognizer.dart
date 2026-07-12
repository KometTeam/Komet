import 'package:flutter/gestures.dart';

class RightwardDragRecognizer extends HorizontalDragGestureRecognizer {
  RightwardDragRecognizer({super.debugOwner}) {
    onlyAcceptDragOnThreshold = true;
  }

  static const double _kMinAcceptVelocity = 700.0;
  static const double _kMinAcceptDistance = 20.0;

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
        final dx = event.position.dx - initial.dx;
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
    if (maxDx < _kMinAcceptDistance) return false;
    for (final tracker in _velocityTrackers.values) {
      final vx = tracker.getVelocity().pixelsPerSecond.dx;
      if (vx >= _kMinAcceptVelocity) return true;
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
