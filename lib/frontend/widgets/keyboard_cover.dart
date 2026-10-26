import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/utils/logger.dart';

// #***! шторка поверх открытой клавиатуры, как в телеграме. Натив рисует Flutter
// в окно выше IME, клавиатура остаётся открытой под ним. Пока накрыто, всё
// приложение видит клавиатуру закрытой, а экран-хозяин держит её место сам
class KeyboardCover with WidgetsBindingObserver {
  KeyboardCover._() {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static final KeyboardCover instance = KeyboardCover._();
  static const _channel = MethodChannel('ru.komet.app/keyboard_cover');

  static const _handOverLimit = Duration(milliseconds: 700);

  final ValueNotifier<bool> active = ValueNotifier(false);
  FocusNode? _keyboardOwner;
  Future<void>? _releasing;
  Timer? _handOverTimeout;
  bool _reopenKeyboard = false;

  bool get supported => !kIsWeb && Platform.isAndroid;

  // #***! дырку под клавиатурой рисуем кадром раньше, чем натив подменит
  // поверхность, иначе первый кадр в окне над IME закроет клавиатуру фоном
  Future<bool> engage() async {
    if (!supported) return false;
    if (active.value) return true;
    _keyboardOwner = FocusManager.instance.primaryFocus;
    active.value = true;
    await SchedulerBinding.instance.endOfFrame;
    var engaged = false;
    try {
      engaged = await _channel.invokeMethod<bool>('engage') ?? false;
    } catch (e) {
      logger.w('KeyboardCover.engage: $e');
    }
    if (!engaged) {
      _settle();
      return false;
    }
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_onFocusChanged);
    return true;
  }

  void releaseAfter(TransitionRoute<dynamic> route) {
    unawaited(route.completed.whenComplete(release));
  }

  Future<void> release() => _releasing ??= _release().whenComplete(() {
    _releasing = null;
  });

  // #***! окно над IME убираем, только когда кадр уже ушёл в обычную поверхность
  Future<void> _release() async {
    if (!active.value) return;
    final reopen = _reopenKeyboard;
    try {
      await _channel.invokeMethod<void>('restore');
    } catch (e) {
      logger.w('KeyboardCover.restore: $e');
    }
    _settle();
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    try {
      await _channel.invokeMethod<void>('dismiss');
    } catch (e) {
      logger.w('KeyboardCover.dismiss: $e');
    }
    if (reopen) {
      await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
  }

  void _settle() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChanged);
    _handOverTimeout?.cancel();
    _handOverTimeout = null;
    _reopenKeyboard = false;
    _keyboardOwner = null;
    active.value = false;
  }

  // #***! окно над IME снято системой (ушли в фон, разрешение, поворот), а
  // шторка ещё открыта: без этого клавиатура всплыла бы поверх неё
  Future<void> _onNativeCall(MethodCall call) async {
    if (call.method != 'lost' || !active.value) return;
    final owner = _keyboardOwner;
    _settle();
    owner?.unfocus();
  }

  // #***! клавиатура закрылась под шторкой — накрывать больше нечего
  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty || views.first.viewInsets.bottom > 0) return;
    unawaited(release());
  }

  // #***! фокус ушёл в другое поле, например в подпись. Как в телеграме:
  // клавиатуру прячем под шторкой, снимаем окно и открываем её заново, чтобы
  // поле ехало вместе с ней, а не прыгало на готовую высоту
  void _onFocusChanged() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || identical(focus, _keyboardOwner)) return;
    final context = focus.context;
    if (context == null) return;
    final editable =
        context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
    if (!editable) return;
    FocusManager.instance.removeListener(_onFocusChanged);
    _reopenKeyboard = true;
    _handOverTimeout = Timer(_handOverLimit, () => unawaited(release()));
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }
}

// #***! пока накрыто, для приложения клавиатуры нет: шторка и всё, что
// откроется поверх неё, раскладываются как без клавиатуры
class KeyboardCoverScope extends StatelessWidget {
  const KeyboardCoverScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: KeyboardCover.instance.active,
      child: child,
      builder: (context, covered, child) {
        final data = MediaQuery.of(context);
        return MediaQuery(
          data: covered
              ? data.copyWith(
                  viewInsets: data.viewInsets.copyWith(bottom: 0),
                  padding: data.padding.copyWith(
                    bottom: data.viewPadding.bottom,
                  ),
                )
              : data,
          child: child!,
        );
      },
    );
  }
}

// #***! прозрачная полоса на месте клавиатуры: в окне над IME сквозь неё
// видно саму клавиатуру, пока шторка её не закрыла
class KeyboardCoverHole extends SingleChildRenderObjectWidget {
  const KeyboardCoverHole({super.key, required this.height, super.child});

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderKeyboardCoverHole(height);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderKeyboardCoverHole renderObject,
  ) {
    renderObject.height = height;
  }
}

class RenderKeyboardCoverHole extends RenderProxyBox {
  RenderKeyboardCoverHole(this._height);

  double _height;

  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if (_height <= 0) return;
    final hole = Rect.fromLTWH(
      offset.dx,
      offset.dy + size.height - _height,
      size.width,
      _height,
    );
    context.canvas.drawRect(hole, Paint()..blendMode = BlendMode.clear);
  }
}
