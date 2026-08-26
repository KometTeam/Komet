import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show OverScrollHeaderStretchConfiguration;

class HeaderPullScrollPhysics extends ScrollPhysics {
  final double delta;
  final ValueGetter<bool> isArmed;

  const HeaderPullScrollPhysics({
    required this.delta,
    required this.isArmed,
    super.parent,
  });

  static final SpringDescription _expressiveSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 380, ratio: 0.9);

  static const double _flingVelocity = 400;

  @override
  HeaderPullScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return HeaderPullScrollPhysics(
      delta: delta,
      isArmed: isArmed,
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (delta <= 0) {
      if (value < position.pixels &&
          position.pixels <= position.minScrollExtent) {
        return value - position.pixels;
      }
      if (value < position.minScrollExtent &&
          position.minScrollExtent < position.pixels) {
        return value - position.minScrollExtent;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (delta <= 0 || offset <= 0 || position.pixels <= 0) {
      return super.applyPhysicsToUserOffset(position, offset);
    }
    final px = position.pixels;
    final free = math.max(0.0, px - delta);
    if (offset <= free) return offset;
    if (!isArmed()) return free;
    final inZone = offset - free;
    final expandedFraction = (1 - math.min(px, delta) / delta).clamp(0.0, 1.0);
    final friction = lerpDouble(0.58, 0.3, expandedFraction)!;
    return free + inZone * friction;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (delta > 0) {
      final px = position.pixels;
      final tolerance = toleranceFor(position);
      if (px > 0 && px < delta) {
        final collapsed = math.min(delta, position.maxScrollExtent);
        final double target;
        if (velocity <= -_flingVelocity) {
          target = 0;
        } else if (velocity >= _flingVelocity) {
          target = collapsed;
        } else {
          target = px < delta / 2 ? 0 : collapsed;
        }
        if ((target - px).abs() < tolerance.distance &&
            velocity.abs() < tolerance.velocity) {
          return null;
        }
        return ScrollSpringSimulation(
          _expressiveSpring,
          px,
          target,
          velocity,
          tolerance: tolerance,
        );
      }
      if (px >= delta && velocity < 0) {
        return BouncingScrollSimulation(
          position: px,
          velocity: velocity,
          leadingExtent: delta,
          trailingExtent: math.max(delta, position.maxScrollExtent),
          spring: spring,
          tolerance: tolerance,
        );
      }
    }
    return super.createBallisticSimulation(position, velocity);
  }
}

class MorphHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double collapsedExtent;
  final double expandedExtent;
  final Widget Function(BuildContext context, double t) headerBuilder;

  MorphHeaderDelegate({
    required this.collapsedExtent,
    required this.expandedExtent,
    required this.headerBuilder,
  });

  @override
  double get minExtent => collapsedExtent;

  @override
  double get maxExtent => expandedExtent;

  @override
  OverScrollHeaderStretchConfiguration? get stretchConfiguration =>
      expandedExtent > collapsedExtent
      ? OverScrollHeaderStretchConfiguration()
      : null;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = expandedExtent - collapsedExtent;
    final t = range <= 0 ? 0.0 : (1 - shrinkOffset / range).clamp(0.0, 1.0);
    return headerBuilder(context, t);
  }

  @override
  bool shouldRebuild(covariant MorphHeaderDelegate oldDelegate) => true;
}
