import 'package:flutter/foundation.dart';

/// Прогресс активных загрузок вложений, ключ — имя в кэше.
///
/// Значение: `null` — не загружается; `0..1` — доля загруженного.
class MediaDownloadProgress {
  static final Map<String, ValueNotifier<double?>> _notifiers = {};

  static ValueNotifier<double?> notifier(String key) =>
      _notifiers.putIfAbsent(key, () => ValueNotifier<double?>(null));

  static void set(String key, double? value) {
    notifier(key).value = value;
  }
}
