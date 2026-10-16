import 'package:flutter/widgets.dart';

class RouteProbe extends StatefulWidget {
  const RouteProbe({super.key, required this.onRoute, required this.child});

  final ValueChanged<ModalRoute<Object?>> onRoute;
  final Widget child;

  @override
  State<RouteProbe> createState() => _RouteProbeState();
}

class _RouteProbeState extends State<RouteProbe> {
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _route)) return;
    _route = route;
    widget.onRoute(route);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
