import 'dart:async';

import 'package:flutter/widgets.dart';

// #***! откладывает тяжёлое до конца анимации иначе она дёргается
class RouteSettle {
  RouteSettle({required this.isMounted});

  // #***! запас поверх анимации на случай если статус не придёт
  static const Duration _safetyMargin = Duration(milliseconds: 250);

  final bool Function() isMounted;
  final List<VoidCallback> _queued = <VoidCallback>[];
  Animation<double>? _animation;
  Timer? _timer;
  bool _bindScheduled = false;
  bool _settled = false;
  bool _disposed = false;

  bool get settled => _settled;

  // #***! цепляемся к анимации после первого кадра
  void bind(BuildContext context) {
    if (_disposed || _settled || _bindScheduled || _animation != null) return;
    _bindScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bindScheduled = false;
      if (_disposed || _settled) return;
      if (!isMounted()) {
        settleNow();
        return;
      }
      _attach(context);
    });
  }

  // #***! до конца анимации откладываем, после сразу
  void run(VoidCallback action) {
    if (_settled) {
      action();
      return;
    }
    _queued.add(action);
  }

  // #***! таймер страховкой, статус не пришёл всё равно отпускаем очередь
  void settleNow() {
    if (_disposed || _settled) return;
    _settled = true;
    _detach();
    final pending = List<VoidCallback>.of(_queued);
    _queued.clear();
    if (!isMounted()) return;
    for (final action in pending) {
      action();
    }
  }

  void dispose() {
    _disposed = true;
    _detach();
    _queued.clear();
  }

  void _attach(BuildContext context) {
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      settleNow();
      return;
    }
    _animation = animation..addStatusListener(_onStatus);
    _timer = Timer(route!.transitionDuration + _safetyMargin, settleNow);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) settleNow();
  }

  void _detach() {
    _animation?.removeStatusListener(_onStatus);
    _animation = null;
    _timer?.cancel();
    _timer = null;
  }
}
