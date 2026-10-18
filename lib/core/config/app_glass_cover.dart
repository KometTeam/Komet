import 'package:flutter/widgets.dart';

// #***! счётчик открытых fullscreen-blur поверх дока
class AppGlassCover {
  AppGlassCover._();

  static final ValueNotifier<int> depth = ValueNotifier(0);

  static bool get covered => depth.value > 0;

  static void open() => depth.value++;

  static void close() => depth.value = depth.value > 0 ? depth.value - 1 : 0;
}

// #***! открывает cover на время жизни состояния (попапы, шиты)
mixin GlassCoveredState<T extends StatefulWidget> on State<T> {
  bool _covered = false;

  void _setCovered(bool value) {
    if (_covered == value) return;
    _covered = value;
    if (value) {
      AppGlassCover.open();
    } else {
      AppGlassCover.close();
    }
  }

  bool get glassCovered => _covered;

  set glassCovered(bool value) => _setCovered(value);

  @override
  void dispose() {
    _setCovered(false);
    super.dispose();
  }
}

class GlassCoveredScope extends StatefulWidget {
  final Widget child;

  const GlassCoveredScope({super.key, required this.child});

  @override
  State<GlassCoveredScope> createState() => _GlassCoveredScopeState();
}

class _GlassCoveredScopeState extends State<GlassCoveredScope>
    with GlassCoveredState {
  @override
  void initState() {
    super.initState();
    glassCovered = true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
