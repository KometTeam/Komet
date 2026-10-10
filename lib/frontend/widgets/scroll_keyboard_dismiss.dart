import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class ScrollKeyboardDismiss extends StatefulWidget {
  const ScrollKeyboardDismiss({
    super.key,
    required this.onDismiss,
    required this.child,
  });

  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<ScrollKeyboardDismiss> createState() => _ScrollKeyboardDismissState();
}

class _ScrollKeyboardDismissState extends State<ScrollKeyboardDismiss> {
  static const _minimumSpeed = 300.0;
  static const _minimumDistance = 18.0;
  VelocityTracker? _tracker;
  Offset? _origin;
  bool _dismissed = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      final details = notification.dragDetails;
      _tracker = details == null
          ? null
          : VelocityTracker.withKind(details.kind ?? PointerDeviceKind.touch);
      _origin = details?.globalPosition;
      _dismissed = false;
      if (details?.sourceTimeStamp case final time?) {
        _tracker?.addPosition(time, details!.globalPosition);
      }
    } else if (notification is ScrollEndNotification) {
      _tracker = null;
      _origin = null;
    } else if (!_dismissed) {
      final details = switch (notification) {
        ScrollUpdateNotification() => notification.dragDetails,
        OverscrollNotification() => notification.dragDetails,
        _ => null,
      };
      final time = details?.sourceTimeStamp;
      final tracker = _tracker;
      final origin = _origin;
      if (details != null &&
          time != null &&
          tracker != null &&
          origin != null) {
        tracker.addPosition(time, details.globalPosition);
        if ((details.globalPosition.dy - origin.dy).abs() >= _minimumDistance &&
            tracker.getVelocity().pixelsPerSecond.dy.abs() >= _minimumSpeed) {
          _dismissed = true;
          widget.onDismiss();
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      );
}
