import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MessageActionsStyle { radial, list }

class AppMessageActionsStyle {
  static const prefKey = 'app_message_actions_style';
  static final ValueNotifier<MessageActionsStyle> current = ValueNotifier(
    MessageActionsStyle.radial,
  );

  static Future<MessageActionsStyle> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(prefKey));
  }

  static Future<void> save(MessageActionsStyle style) async {
    current.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, style.name);
  }

  static MessageActionsStyle _parse(String? val) {
    if (val == MessageActionsStyle.list.name) return MessageActionsStyle.list;
    return MessageActionsStyle.radial;
  }

  static String label(MessageActionsStyle style) {
    switch (style) {
      case MessageActionsStyle.radial:
        return 'Радиальное';
      case MessageActionsStyle.list:
        return 'Список';
    }
  }
}
