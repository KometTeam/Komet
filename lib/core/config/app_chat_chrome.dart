import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChatChromeStyle { color, blur, none }

class AppChatChrome {
  static const prefKey = 'app_chat_chrome';
  static final ValueNotifier<ChatChromeStyle> current =
      ValueNotifier(ChatChromeStyle.blur);

  static ChatChromeStyle _parse(String? value) {
    switch (value) {
      case 'color':
        return ChatChromeStyle.color;
      case 'none':
        return ChatChromeStyle.none;
      default:
        return ChatChromeStyle.blur;
    }
  }

  static String _encode(ChatChromeStyle value) {
    switch (value) {
      case ChatChromeStyle.color:
        return 'color';
      case ChatChromeStyle.blur:
        return 'blur';
      case ChatChromeStyle.none:
        return 'none';
    }
  }

  static Future<ChatChromeStyle> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _parse(prefs.getString(prefKey));
  }

  static Future<void> save(ChatChromeStyle value) async {
    current.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, _encode(value));
  }
}
