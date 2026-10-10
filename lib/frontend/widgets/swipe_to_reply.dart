import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/utils/haptics.dart';
import 'directional_drag_recognizer.dart';

class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.child, required this.onReply});

  final Widget child;
  final VoidCallback onReply;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _triggerDistance = 56;
  static const double _resistanceLength = 32;
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 500,
    ratio: 1,
  );

  late final AnimationController _offset;
  double _distance = 0;
  bool _triggered = false;
  bool _hapticSent = false;

  @override
  void initState() {
    super.initState();
    _offset = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _offset.stop();
    final visibleDistance = (-_offset.value).clamp(0.0, double.infinity);
    final extra = (visibleDistance - _triggerDistance).clamp(
      0.0,
      _resistanceLength - 0.01,
    );
    _distance = extra == 0
        ? visibleDistance
        : _triggerDistance + extra / (1 - extra / _resistanceLength);
    _triggered = false;
    _hapticSent = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _distance = (_distance - details.delta.dx).clamp(0.0, double.infinity);
    final extra = (_distance - _triggerDistance).clamp(0.0, double.infinity);
    _offset.value = extra == 0
        ? -_distance
        : -(_triggerDistance + extra / (1 + extra / _resistanceLength));
    _triggered = _distance >= _triggerDistance;
    if (_triggered && !_hapticSent) {
      _hapticSent = true;
      Haptics.medium();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final shouldReply = _triggered;
    _settle(details.velocity.pixelsPerSecond.dx);
    if (shouldReply) widget.onReply();
  }

  void _settle([double velocity = 0]) {
    _triggered = false;
    final extra = (_distance - _triggerDistance).clamp(0.0, double.infinity);
    final resistance = 1 + extra / _resistanceLength;
    _offset.animateWith(
      SpringSimulation(
        _spring,
        _offset.value,
        0,
        velocity.clamp(-1500.0, 1500.0) / (resistance * resistance),
        tolerance: const Tolerance(distance: 0.1, velocity: 0.1),
        snapToEnd: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Listener(
      onPointerCancel: (_) => _settle(),
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          LeftwardDragRecognizer:
              GestureRecognizerFactoryWithHandlers<LeftwardDragRecognizer>(
                () => LeftwardDragRecognizer(debugOwner: this),
                (instance) {
                  instance
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = _onDragStart
                    ..onUpdate = _onDragUpdate
                    ..onEnd = _onDragEnd
                    ..onCancel = _settle;
                },
              ),
        },
        child: AnimatedBuilder(
          animation: _offset,
          child: RepaintBoundary(child: widget.child),
          builder: (context, child) {
            final offset = _offset.value.clamp(-double.infinity, 0.0);
            final progress = (-offset / _triggerDistance).clamp(0.0, 1.0);
            return Stack(
              alignment: Alignment.centerRight,
              children: [
                Positioned(
                  right: 16,
                  child: Opacity(
                    opacity: progress,
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * progress,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Symbols.reply, size: 20, color: cs.primary),
                      ),
                    ),
                  ),
                ),
                Transform.translate(offset: Offset(offset, 0), child: child),
              ],
            );
          },
        ),
      ),
    );
  }
}
