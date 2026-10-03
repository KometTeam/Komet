import 'package:flutter/widgets.dart';

class VisiblePageTickers extends StatelessWidget {
  final int index;
  final bool enabled;
  final Listenable positionChanges;
  final double Function() pagePosition;
  final Widget child;

  const VisiblePageTickers({
    super.key,
    required this.index,
    required this.enabled,
    required this.positionChanges,
    required this.pagePosition,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: positionChanges,
      child: child,
      builder: (context, child) => TickerMode(
        enabled: !enabled || (index - pagePosition()).abs() < 1,
        child: child!,
      ),
    );
  }
}
