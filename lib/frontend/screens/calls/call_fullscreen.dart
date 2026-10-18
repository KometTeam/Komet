import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show RTCVideoValue;

import '../../../core/calls/remote_screens.dart';

typedef CallFullscreenBuilder =
    Widget Function(BuildContext context, bool fullscreen, VoidCallback toggle);

// #***! «на весь экран» для сцены: видна только трансляция. На телефоне широкая
// картинка включает его сама и кладёт телефон набок; узкую (экран телефона,
// портретная камера) не поворачиваем. Назад и Esc выходят обратно на сцену
class CallFullscreenScope extends StatefulWidget {
  const CallFullscreenScope({
    super.key,
    required this.stage,
    required this.builder,
    this.screen,
    this.video,
  });

  final Object? stage;
  final ValueListenable<RemoteScreen?>? screen;
  final ValueListenable<RTCVideoValue>? video;
  final CallFullscreenBuilder builder;

  @override
  State<CallFullscreenScope> createState() => _CallFullscreenScopeState();
}

class _CallFullscreenScopeState extends State<CallFullscreenScope> {
  static const double _wideAspect = 1.1;
  static const double _phoneShortestSide = 600;

  bool _mobile = false;
  bool _phone = false;
  bool _wide = false;
  bool _manual = false;
  bool _dismissed = false;
  bool _landscapeHeld = false;
  bool _barsHidden = false;

  bool get _fullscreen =>
      widget.stage != null && (_manual || (_phone && _wide && !_dismissed));

  @override
  void initState() {
    super.initState();
    _listen(widget);
    _wide = _measureWide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    _phone =
        _mobile && MediaQuery.sizeOf(context).shortestSide < _phoneShortestSide;
    _sync();
  }

  @override
  void didUpdateWidget(CallFullscreenScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage != widget.stage) {
      _manual = false;
      _dismissed = false;
    }
    if (oldWidget.screen != widget.screen || oldWidget.video != widget.video) {
      _unlisten(oldWidget);
      _listen(widget);
    }
    _wide = _measureWide();
    _sync();
  }

  @override
  void dispose() {
    _unlisten(widget);
    if (_landscapeHeld) {
      unawaited(SystemChrome.setPreferredOrientations(const []));
    }
    if (_barsHidden) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    super.dispose();
  }

  void _listen(CallFullscreenScope scope) {
    scope.screen?.addListener(_onFrame);
    scope.video?.addListener(_onFrame);
  }

  void _unlisten(CallFullscreenScope scope) {
    scope.screen?.removeListener(_onFrame);
    scope.video?.removeListener(_onFrame);
  }

  // #***! кадр трансляции, пока его нет видеотрек; размер неизвестен значит квадрат
  bool _measureWide() {
    final aspect =
        widget.screen?.value?.aspectRatio ??
        widget.video?.value.aspectRatio ??
        1;
    return aspect.isFinite && aspect > _wideAspect;
  }

  void _onFrame() {
    final wide = _measureWide();
    if (wide == _wide) return;
    setState(() => _wide = wide);
    _sync();
  }

  // #***! выход из авто-режима запоминаем до смены сцены, иначе он сразу вернётся
  void _toggle() {
    final exit = _fullscreen;
    setState(() {
      _manual = !exit;
      _dismissed = exit;
    });
    _sync();
  }

  // #***! системе пишем только на переходах, кадры идут 30 раз в секунду
  void _sync() {
    final fullscreen = _fullscreen;
    final landscape = fullscreen && _phone && _wide;
    if (landscape != _landscapeHeld) {
      _landscapeHeld = landscape;
      unawaited(
        SystemChrome.setPreferredOrientations(
          landscape
              ? const [
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]
              : const [],
        ),
      );
    }
    final hideBars = fullscreen && _mobile;
    if (hideBars != _barsHidden) {
      _barsHidden = hideBars;
      unawaited(
        SystemChrome.setEnabledSystemUIMode(
          hideBars ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullscreen = _fullscreen;
    final child = widget.builder(context, fullscreen, _toggle);
    return PopScope(
      canPop: !fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) _toggle();
      },
      child: fullscreen
          ? CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): _toggle,
              },
              child: Focus(autofocus: true, child: child),
            )
          : child,
    );
  }
}
