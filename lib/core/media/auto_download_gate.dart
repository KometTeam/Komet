import 'package:flutter/foundation.dart';

class AutoDownloadGate {
  AutoDownloadGate._();

  static final Map<String, ValueNotifier<bool>> _loaded = {};

  static ValueListenable<bool> listen(String key) =>
      _loaded.putIfAbsent(key, () => ValueNotifier(false));

  static bool allows(bool autoEnabled, String key) =>
      autoEnabled || (_loaded[key]?.value ?? false);

  static void loadManually(String key) {
    final notifier = _loaded.putIfAbsent(key, () => ValueNotifier(false));
    notifier.value = true;
  }
}
