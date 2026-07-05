import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'rightward_drag_recognizer.dart';

class SwipeRoute<T> extends PageRoute<T> {
  SwipeRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
    this.maintainState = true,
  });

  final WidgetBuilder builder;

  @override
  final bool maintainState;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 400);

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    return nextRoute is SwipeRoute ||
        nextRoute is CupertinoRouteTransitionMixin;
  }

  @override
  bool get popGestureInProgress => _gestureController != null;

  _SwipeBackController<T>? _gestureController;

  @override
  bool get popGestureEnabled {
    if (isFirst) return false;
    if (willHandlePopInternally) return false;
    if (popDisposition == RoutePopDisposition.doNotPop) return false;
    if (animation?.status != AnimationStatus.completed) return false;
    if (secondaryAnimation?.status != AnimationStatus.dismissed) return false;
    if (popGestureInProgress) return false;
    return true;
  }

  _SwipeBackController<T> _startPopGesture() {
    final gesture = _SwipeBackController<T>(
      navigator: navigator!,
      controller: controller!,
    );
    _gestureController = gesture;
    gesture._onEnd = () {
      if (_gestureController == gesture) {
        _gestureController = null;
      }
    };
    return gesture;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SwipeBackGestureDetector<T>(
      enabledCallback: () => popGestureEnabled,
      onStartPopGesture: _startPopGesture,
      child: CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: popGestureInProgress,
        child: child,
      ),
    );
  }
}

Future<T?> pushSwipeable<T>(
  BuildContext context,
  WidgetBuilder builder, {
  RouteSettings? settings,
}) {
  return Navigator.of(
    context,
  ).push<T>(SwipeRoute<T>(builder: builder, settings: settings));
}

class _SwipeBackGestureDetector<T> extends StatefulWidget {
  const _SwipeBackGestureDetector({
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
  });

  final ValueGetter<bool> enabledCallback;
  final ValueGetter<_SwipeBackController<T>> onStartPopGesture;
  final Widget child;

  @override
  State<_SwipeBackGestureDetector<T>> createState() =>
      _SwipeBackGestureDetectorState<T>();
}

class _SwipeBackGestureDetectorState<T>
    extends State<_SwipeBackGestureDetector<T>> {
  _SwipeBackController<T>? _backController;
  double _width = 0;

  void _handleStart(DragStartDetails details) {
    if (!widget.enabledCallback()) return;
    _width = context.size?.width ?? MediaQuery.of(context).size.width;
    if (_width <= 0) _width = 1.0;
    _backController = widget.onStartPopGesture();
  }

  void _handleUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0.0;
    _backController?.dragUpdate(delta / _width);
  }

  void _handleEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx / _width;
    _backController?.dragEnd(velocity);
    _backController = null;
  }

  void _handleCancel() {
    _backController?.dragEnd(0.0);
    _backController = null;
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        RightwardDragRecognizer:
            GestureRecognizerFactoryWithHandlers<RightwardDragRecognizer>(
              () => RightwardDragRecognizer(debugOwner: this),
              (instance) {
                instance
                  ..onStart = _handleStart
                  ..onUpdate = _handleUpdate
                  ..onEnd = _handleEnd
                  ..onCancel = _handleCancel;
              },
            ),
      },
      child: widget.child,
    );
  }
}

class _SwipeBackController<T> {
  _SwipeBackController({required this.navigator, required this.controller});

  final NavigatorState navigator;
  final AnimationController controller;
  VoidCallback? _onEnd;

  static const double _kMinFlingVelocity = 1.0;

  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  void dragEnd(double velocity) {
    const animationCurve = Curves.fastLinearToSlowEaseIn;
    final bool animateForward;

    if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      final forwardMs = math.min(
        lerpDouble(800, 0, controller.value)!.floor(),
        300,
      );
      controller.animateTo(
        1.0,
        duration: Duration(milliseconds: forwardMs),
        curve: animationCurve,
      );
    } else {
      navigator.pop();
      if (controller.isAnimating) {
        final backMs = lerpDouble(0, 800, controller.value)!.floor();
        controller.animateBack(
          0.0,
          duration: Duration(milliseconds: backMs),
          curve: animationCurve,
        );
      }
    }

    if (controller.isAnimating) {
      late AnimationStatusListener statusCb;
      statusCb = (status) {
        _onEnd?.call();
        controller.removeStatusListener(statusCb);
      };
      controller.addStatusListener(statusCb);
    } else {
      _onEnd?.call();
    }
  }
}
