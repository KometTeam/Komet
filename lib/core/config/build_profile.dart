import 'package:flutter/services.dart' show appFlavor;

abstract final class BuildProfile {
  static const String storeFlavor = 'store';

  static const bool isStore = appFlavor == storeFlavor;

  static const bool selfUpdate = !isStore;
  static const bool firebasePush = appFlavor == 'oneme';
  static const bool spoofUi = !isStore;
  static const bool tokenLogin = !isStore;
  static const bool devTools = !isStore;
  static const bool insecureTransport = !isStore;
  static const bool trafficCapture = !isStore;
  static const bool pranks = !isStore;
  static const bool hiddenContentViewers = !isStore;
  static const bool digitalId = !isStore;
}
