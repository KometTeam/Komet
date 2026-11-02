import 'package:flutter/material.dart';

import '../../core/config/app_motion.dart';

class AppMotionScope extends StatelessWidget {
  const AppMotionScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppMotion.enabled,
      child: child,
      builder: (context, enabled, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: media.disableAnimations || !enabled,
          ),
          child: child!,
        );
      },
    );
  }
}

class MotionAwarePageTransitions extends PageTransitionsBuilder {
  const MotionAwarePageTransitions(this.animated);

  final PageTransitionsBuilder animated;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      animated.delegatedTransition;

  @override
  Duration get transitionDuration => AppMotion.of(animated.transitionDuration);

  @override
  Duration get reverseTransitionDuration =>
      AppMotion.of(animated.reverseTransitionDuration);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => animated.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    child,
  );
}
