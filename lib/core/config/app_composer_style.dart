import 'package:flutter/foundation.dart';

import 'app_visual_style.dart';
import 'persisted_setting.dart';

enum ComposerStyle { auto, glossy, materialYou }

class ComposerChrome {
  static bool isGlossy(ComposerStyle style) => switch (style) {
    ComposerStyle.auto => AppVisualStyle.current.value.glossyChrome,
    ComposerStyle.glossy => true,
    ComposerStyle.materialYou => false,
  };
}

class AppComposerStyle {
  static const prefKey = 'app_composer_style';

  static final _setting = PersistedEnum<ComposerStyle>(
    prefKey: prefKey,
    defaultValue: ComposerStyle.glossy,
    encode: (value) => value.name,
    decode: _parse,
  );

  static ValueNotifier<ComposerStyle> get current => _setting.current;

  static Future<ComposerStyle> load() => _setting.load();

  static Future<void> save(ComposerStyle value) => _setting.save(value);

  static ComposerStyle _parse(String? val) =>
      enumFromName(ComposerStyle.values, val, ComposerStyle.glossy);
}
