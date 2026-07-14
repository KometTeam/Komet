import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum ComposerStyle { glossy, materialYou }

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
