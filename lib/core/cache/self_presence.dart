import 'package:flutter/foundation.dart';

class SelfPresence {
  static final ValueNotifier<bool> isOnline = ValueNotifier(true);
  static final ValueNotifier<int?> lastSeenSeconds = ValueNotifier(null);

  static int get _nowSeconds =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  static void markOnline() {
    isOnline.value = true;
  }

  static void markOffline() {
    isOnline.value = false;
  }

  static void markOfflineFromPing() {
    if (isOnline.value || lastSeenSeconds.value == null) {
      lastSeenSeconds.value = _nowSeconds;
    }
    isOnline.value = false;
  }

  static void applySelfCheck({required bool online, int? seenSeconds}) {
    if (online) {
      isOnline.value = true;
    } else {
      isOnline.value = false;
      if (seenSeconds != null) lastSeenSeconds.value = seenSeconds;
    }
  }
}
