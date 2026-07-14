import 'package:flutter/foundation.dart';

import '../../frontend/widgets/liquid_glass.dart';
import 'persisted_setting.dart';

enum ComposerBackground { standard, frostBlur, liquidGlass }

class ComposerMaterial {
  static bool isLiquid(ComposerBackground value) =>
      value == ComposerBackground.liquidGlass && LiquidGlass.isSupported;

  static bool isFrost(ComposerBackground value) =>
      value == ComposerBackground.frostBlur ||
      (value == ComposerBackground.liquidGlass && !LiquidGlass.isSupported);
}

class AppComposerBackground {
  static const prefKey = 'app_composer_background';

  static final _setting = PersistedEnum<ComposerBackground>(
    prefKey: prefKey,
    defaultValue: ComposerBackground.standard,
    encode: (value) => value.name,
    decode: _parse,
  );

  static ValueNotifier<ComposerBackground> get current => _setting.current;

  static Future<ComposerBackground> load() => _setting.load();

  static Future<void> save(ComposerBackground value) => _setting.save(value);

  static ComposerBackground _parse(String? val) =>
      enumFromName(ComposerBackground.values, val, ComposerBackground.standard);
}
