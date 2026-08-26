import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

enum MessageActionsStyle { radial, list }

class AppMessageActionsStyle {
  static const prefKey = 'app_message_actions_style';

  static final _setting = PersistedEnum<MessageActionsStyle>(
    prefKey: prefKey,
    defaultValue: MessageActionsStyle.list,
    encode: (value) => value.name,
    decode: _parse,
  );

  static ValueNotifier<MessageActionsStyle> get current => _setting.current;

  static Future<MessageActionsStyle> load() => _setting.load();

  static Future<void> save(MessageActionsStyle style) => _setting.save(style);

  static MessageActionsStyle _parse(String? val) =>
      enumFromName(MessageActionsStyle.values, val, MessageActionsStyle.list);

  static String label(MessageActionsStyle style) {
    switch (style) {
      case MessageActionsStyle.radial:
        return 'Радиальное';
      case MessageActionsStyle.list:
        return 'Список';
    }
  }
}
