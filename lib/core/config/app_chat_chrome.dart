import 'package:flutter/foundation.dart';

import '../../frontend/widgets/liquid_glass.dart';
import 'app_visual_style.dart';
import 'persisted_setting.dart';

// #***! чем заливается шапка чата
enum ChatChromeStyle { color, blur, none, transparent, liquidGlass }

// #***! стекло есть не везде, где нет откатываемся молча
class ChatChromeMaterial {
  static bool isLiquid(ChatChromeStyle style) =>
      style == ChatChromeStyle.liquidGlass && LiquidGlass.isSupported;
}

class AppChatChrome {
  static final ValueListenable<ChatChromeStyle> current = DerivedSetting(
    [AppVisualStyle.current],
    () => switch (AppVisualStyle.current.value) {
      VisualStyle.materialYou => ChatChromeStyle.color,
      VisualStyle.glossy => ChatChromeStyle.none,
      VisualStyle.liquidGlass => ChatChromeStyle.liquidGlass,
    },
  );
}
