import 'package:flutter/foundation.dart';

import 'app_liquid_glass.dart';
import 'persisted_setting.dart';

// #***! общий стиль приложения, от него дефолты частных настроек
enum VisualStyle { materialYou, glossy, liquidGlass }

// #***! всё кроме Material You рисуется с глянцем
extension VisualStyleChrome on VisualStyle {
  bool get glossyChrome => this != VisualStyle.materialYou;
}

// #***! настройка общего стиля
class AppVisualStyle {
  static const prefKey = 'app_visual_style';

  static final _setting = PersistedEnum<VisualStyle>(
    prefKey: prefKey,
    defaultValue: VisualStyle.glossy,
    encode: _encode,
    decode: _parse,
  );

  static ValueNotifier<VisualStyle> get current => _setting.current;

  static Future<VisualStyle> load() => _setting.load();

  static Future<void> save(VisualStyle value) => _setting.save(value);

  static String _encode(VisualStyle value) => value.name;

  static VisualStyle _parse(String? val) {
    final style = enumFromName(VisualStyle.values, val, VisualStyle.glossy);
    return style == VisualStyle.liquidGlass && !AppLiquidGlass.enabled
        ? VisualStyle.glossy
        : style;
  }
}

class AppElementsBlur {
  static const prefKey = 'app_elements_blur';

  static final _setting = PersistedSetting<bool>(
    prefKey: prefKey,
    defaultValue: false,
    read: (prefs, key) => prefs.getBool(key),
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static ValueNotifier<bool> get current => _setting.current;

  static Future<bool> load() => _setting.load();

  static Future<void> save(bool value) => _setting.save(value);
}
