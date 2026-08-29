import 'package:flutter/foundation.dart';

/// Признак «приложение на переднем плане» для подсистем, которые обязаны
/// экономить в фоне: реконнект, пинг ядра, запись отладочного лога.
abstract class AppForeground {
  static final ValueNotifier<bool> notifier = ValueNotifier(true);

  static bool get value => notifier.value;

  static void update({required bool foreground}) => notifier.value = foreground;
}
