import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum VisualStyle { materialYou, glossy, liquidGlass }

extension VisualStyleChrome on VisualStyle {
  bool get glossyChrome => this != VisualStyle.materialYou;
}

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

  static VisualStyle _parse(String? val) =>
      enumFromName(VisualStyle.values, val, VisualStyle.glossy);
}
