import 'package:flutter/material.dart';

class MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<double> onHeight;

  const MeasureSize({super.key, required this.onHeight, required this.child});

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  final GlobalKey _key = GlobalKey();
  double _last = -1;

  void _report() {
    if (!mounted) return;
    final height = _key.currentContext?.size?.height;
    if (height == null) return;
    if ((height - _last).abs() > 0.5) {
      _last = height;
      widget.onHeight(height);
    }
  }

  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  Widget build(BuildContext context) {
    _scheduleReport();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleReport();
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: SizedBox(key: _key, child: widget.child),
      ),
    );
  }
}
