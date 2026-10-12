import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../core/config/ios_release.dart';

bool _focusIsText() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// Hides the keyboard when a text field has focus.
void dismissKeyboard() {
  if (_focusIsText()) FocusManager.instance.primaryFocus?.unfocus();
}

/// iOS keyboard behavior for the whole app: a short tap outside a text
/// field and a vertical drag of any list hide the keyboard, as in iOS apps.
/// Long presses, drags that start in a field and horizontal scrolling keep
/// it. Other platforms keep the Flutter defaults.
class KeyboardDismissal extends StatefulWidget {
  static const double tapSlop = 18;
  static const Duration tapTimeout = Duration(milliseconds: 500);

  final Widget child;

  const KeyboardDismissal({super.key, required this.child});

  @override
  State<KeyboardDismissal> createState() => _KeyboardDismissalState();
}

class _KeyboardDismissalState extends State<KeyboardDismissal> {
  final Map<int, PointerDownEvent> _downs = {};

  late final Map<Type, Action<Intent>> _actions = {
    EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
      onInvoke: _onTapDown,
    ),
    EditableTextTapUpOutsideIntent:
        CallbackAction<EditableTextTapUpOutsideIntent>(onInvoke: _onTapUp),
  };

  Object? _onTapDown(EditableTextTapOutsideIntent intent) {
    final event = intent.pointerDownEvent;
    if (event.kind != PointerDeviceKind.touch) {
      intent.focusNode.unfocus();
      return null;
    }
    _downs[event.pointer] = event;
    return null;
  }

  Object? _onTapUp(EditableTextTapUpOutsideIntent intent) {
    final up = intent.pointerUpEvent;
    final down = _downs.remove(up.pointer);
    if (down == null) return null;
    final moved = (up.position - down.position).distance;
    final held = up.timeStamp - down.timeStamp;
    if (moved <= KeyboardDismissal.tapSlop &&
        held <= KeyboardDismissal.tapTimeout) {
      intent.focusNode.unfocus();
    }
    return null;
  }

  bool _onScroll(ScrollUpdateNotification notification) {
    if (notification.dragDetails == null) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    final source = notification.context;
    if (source != null &&
        (source.findAncestorWidgetOfExactType<EditableText>() != null ||
            source.findAncestorWidgetOfExactType<TextFieldTapRegion>() !=
                null)) {
      return false;
    }
    dismissKeyboard();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!IosRelease.isIOS) return widget.child;
    return Actions(
      actions: _actions,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
  }
}

/// On iOS, opening a screen or starting the back swipe hides the keyboard.
class KeyboardNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (IosRelease.isIOS && route is PageRoute) dismissKeyboard();
  }

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    if (IosRelease.isIOS) dismissKeyboard();
  }
}
