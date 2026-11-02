import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'sticker_panel_controller.dart';

class ComposerHeight extends ChangeNotifier implements ValueListenable<double> {
  ComposerHeight(this._stickers, {double initial = 96})
    : _bar = initial,
      _value = initial {
    _stickers.layout.addListener(_sync);
  }

  final StickerPanelController _stickers;
  double _bar;
  double _value;

  @override
  double get value => _value;

  void measured(double height) {
    _bar = height - _stickers.slotHeight;
    _sync();
  }

  void _sync() {
    final next = math.max(0.0, _bar + _stickers.slotHeight);
    if (next == _value) return;
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _stickers.layout.removeListener(_sync);
    super.dispose();
  }
}
