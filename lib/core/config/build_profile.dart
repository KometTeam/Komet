import 'package:flutter/services.dart' show appFlavor;

import 'ios_release.dart';

// #***! что включено в сборке, всё считается на компиляции из flavor
abstract final class BuildProfile {
  static const String storeFlavor = 'store';

  // #***! store сборка урезана, без самообновления дев инструментов и спуфа
  static const bool isStore = appFlavor == storeFlavor;

  static bool get selfUpdate => !isStore && IosRelease.selfUpdate;
  static const bool firebasePush = appFlavor == 'oneme';
  // #***! на iOS экран подмены скрыт, хендшейк при этом как у остальных
  static bool get spoofUi => !isStore && IosRelease.spoofSettings;
  static const bool tokenLogin = false;
  static const bool qrLogin = false;
  static const bool devTools = !isStore;
  static const bool insecureTransport = !isStore;
  static const bool trafficCapture = !isStore;
  static const bool pranks = !isStore;
  static const bool hiddenContentViewers = !isStore;
  static const bool digitalId = !isStore;
  static const bool ipGeoLookup = !isStore;
  static const bool sessionCityLookup = !isStore;
}
