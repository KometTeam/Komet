import 'package:flutter/widgets.dart';

class CloseOnBack extends PopEntry<Object?> {
  CloseOnBack(this.onBack);

  final VoidCallback onBack;

  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier<bool>(false);

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (!didPop) onBack();
  }
}
