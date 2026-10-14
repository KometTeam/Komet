import 'package:flutter/foundation.dart';

import 'app_visual_style.dart';
import 'persisted_setting.dart';

// #***! оформление поля ввода, auto повторяет общий стиль
enum ComposerStyle { auto, glossy, materialYou }

// #***! глянец или чистый Material You, решаем тут а не в виджете
class ComposerChrome {
  static bool isGlossy(ComposerStyle style) => switch (style) {
    ComposerStyle.auto => AppVisualStyle.current.value.glossyChrome,
    ComposerStyle.glossy => true,
    ComposerStyle.materialYou => false,
  };
}

class AppComposerStyle {
  static final ValueListenable<ComposerStyle> current = DerivedSetting(
    [AppVisualStyle.current],
    () => AppVisualStyle.current.value.glossyChrome
        ? ComposerStyle.glossy
        : ComposerStyle.materialYou,
  );
}
