import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/komet_settings.dart';

// #***! панель стикеров встаёт на место клавиатуры: низ композера всегда
// max(клавиатура, видимая панель), поэтому поле ввода не дёргается
class StickerPanelController {
  StickerPanelController({
    required TickerProvider vsync,
    required this.onSendTyping,
    this.softKeyboard = true,
  }) {
    anim = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 200),
    );
    expandAnim = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 300),
    );
    layout = Listenable.merge([
      anim,
      expandAnim,
      panelHeight,
      searching,
      keyboardInset,
    ]);
    anim.addStatusListener(_onAnimStatus);
    showPanel.addListener(_onToggle);
    searching.addListener(_onSearchingChanged);
    unawaited(_KeyboardHeight.load());
  }

  final VoidCallback onSendTyping;
  final bool softKeyboard;

  static const double _minPanelHeight = 120;
  static const double _fallbackHeight = 300;
  static const Duration _keyboardSettle = Duration(milliseconds: 150);
  static const Duration _keyboardWait = Duration(seconds: 1);

  late final AnimationController anim;
  late final AnimationController expandAnim;
  late final Listenable layout;
  final ValueNotifier<bool> showPanel = ValueNotifier(false);
  final ValueNotifier<bool> panelHold = ValueNotifier(true);
  final ValueNotifier<double> panelHeight = ValueNotifier(_fallbackHeight);
  final ValueNotifier<bool> searching = ValueNotifier(false);
  final ValueNotifier<double> keyboardInset = ValueNotifier(0);
  double _baseHeight = _fallbackHeight;
  double maxHeight = _fallbackHeight;
  bool _landscape = false;
  bool _yielding = false;
  Timer? _typingTimer;
  Timer? _settleTimer;
  Timer? _yieldTimeout;

  double get currentHeight {
    final base = panelHeight.value;
    final upper = maxHeight < base ? base : maxHeight;
    final t = Curves.easeOutCubic.transform(expandAnim.value);
    return lerpDouble(base, upper, t)!;
  }

  double get visibleHeight =>
      currentHeight * Curves.easeOutCubic.transform(anim.value.clamp(0.0, 1.0));

  // #***! клавиатура была открыта: панель сразу во всю её высоту, клавиатура
  // уезжает поверх и открывает её
  void showInPlaceOfKeyboard(double keyboard) {
    _setBaseHeight(keyboard);
    showPanel.value = true;
    anim.value = 1;
  }

  // #***! клавиатуры не было: выезжает снизу
  void show({required bool landscape}) {
    _landscape = landscape;
    final remembered = _KeyboardHeight.of(landscape: landscape);
    _setBaseHeight(remembered > 0 ? remembered : _fallbackHeight);
    showPanel.value = true;
  }

  void hide() {
    _stopYielding();
    searching.value = false;
    showPanel.value = false;
  }

  // #***! пошли печатать: панель держим, пока клавиатура не встанет на место
  void yieldToKeyboard() {
    if (!showPanel.value) return;
    if (!softKeyboard) {
      hide();
      return;
    }
    searching.value = false;
    if (_yielding) return;
    _yielding = true;
    _yieldTimeout = Timer(_keyboardWait, hide);
    if (keyboardInset.value > 0) {
      _settleTimer?.cancel();
      _settleTimer = Timer(_keyboardSettle, _onKeyboardSettled);
    }
    _checkKeyboard();
  }

  void keyboardChanged(double inset, {required bool landscape}) {
    _landscape = landscape;
    keyboardInset.value = inset;
    _settleTimer?.cancel();
    _settleTimer = Timer(_keyboardSettle, _onKeyboardSettled);
    if (_yielding) _checkKeyboard();
  }

  void _checkKeyboard() {
    if (keyboardInset.value <= 0) return;
    if (keyboardInset.value < visibleHeight - 1) return;
    hide();
    anim.value = 0;
  }

  void _onKeyboardSettled() {
    final inset = keyboardInset.value;
    if (inset >= _minPanelHeight) {
      _KeyboardHeight.remember(inset, landscape: _landscape);
    }
    if (_yielding && inset > 0) hide();
  }

  void _stopYielding() {
    _yielding = false;
    _yieldTimeout?.cancel();
    _yieldTimeout = null;
  }

  void _setBaseHeight(double value) {
    if (value < _minPanelHeight) return;
    _baseHeight = value;
    panelHeight.value = value;
  }

  void resizeBy(double delta) {
    final upper = maxHeight < _baseHeight ? _baseHeight : maxHeight;
    final next = (panelHeight.value + delta).clamp(_baseHeight, upper);
    if (next != panelHeight.value) panelHeight.value = next;
  }

  void _onSearchingChanged() {
    if (searching.value) {
      expandAnim.forward();
    } else {
      expandAnim.reverse();
    }
  }

  void _onAnimStatus(AnimationStatus status) {
    final held = status != AnimationStatus.completed;
    if (panelHold.value != held) panelHold.value = held;
  }

  void _onToggle() {
    if (showPanel.value) {
      anim.forward();
      _sendTyping();
      _typingTimer?.cancel();
      _typingTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _sendTyping(),
      );
    } else {
      anim.reverse();
      _typingTimer?.cancel();
      _typingTimer = null;
    }
  }

  void _sendTyping() {
    if (KometSettings.ghostMode.value) return;
    onSendTyping();
  }

  void dispose() {
    _typingTimer?.cancel();
    _settleTimer?.cancel();
    _yieldTimeout?.cancel();
    showPanel.removeListener(_onToggle);
    searching.removeListener(_onSearchingChanged);
    anim.removeStatusListener(_onAnimStatus);
    anim.dispose();
    expandAnim.dispose();
    showPanel.dispose();
    panelHold.dispose();
    panelHeight.dispose();
    searching.dispose();
    keyboardInset.dispose();
  }
}

// #***! высота клавиатуры с прошлого раза, отдельно для портрета и альбома
class _KeyboardHeight {
  static const _portraitKey = 'komet_keyboard_height_portrait';
  static const _landscapeKey = 'komet_keyboard_height_landscape';

  static double _portrait = 0;
  static double _landscape = 0;
  static Future<void>? _loading;

  static double of({required bool landscape}) =>
      landscape ? _landscape : _portrait;

  static Future<void> load() => _loading ??= _read();

  static Future<void> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _portrait = prefs.getDouble(_portraitKey) ?? _portrait;
      _landscape = prefs.getDouble(_landscapeKey) ?? _landscape;
    } catch (_) {}
  }

  static void remember(double height, {required bool landscape}) {
    final current = of(landscape: landscape);
    if ((current - height).abs() < 1) return;
    if (landscape) {
      _landscape = height;
    } else {
      _portrait = height;
    }
    unawaited(_write(landscape ? _landscapeKey : _portraitKey, height));
  }

  static Future<void> _write(String key, double height) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(key, height);
    } catch (_) {}
  }
}
