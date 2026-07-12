import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum ChatChromeStyle { color, blur, none, transparent }

class AppChatChrome {
  static const prefKey = 'app_chat_chrome';

  static final _setting = PersistedEnum<ChatChromeStyle>(
    prefKey: prefKey,
    defaultValue: ChatChromeStyle.none,
    encode: _encode,
    decode: _parse,
  );

  static ValueNotifier<ChatChromeStyle> get current => _setting.current;

  static ChatChromeStyle _parse(String? value) =>
      enumFromName(ChatChromeStyle.values, value, ChatChromeStyle.none);

  static String _encode(ChatChromeStyle value) => value.name;

  static Future<ChatChromeStyle> load() => _setting.load();

  static Future<void> save(ChatChromeStyle value) => _setting.save(value);
}
