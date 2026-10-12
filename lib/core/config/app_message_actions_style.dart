import 'package:flutter/foundation.dart';

import 'ios_release.dart';
import 'persisted_setting.dart';

// #***! меню действий, кругом вокруг пальца или списком
enum MessageActionsStyle { radial, list }

// #***! настройка вида меню
class AppMessageActionsStyle {
  static const prefKey = 'app_message_actions_style';

  static final _setting = PersistedEnum<MessageActionsStyle>(
    prefKey: prefKey,
    defaultValue: MessageActionsStyle.list,
    encode: (value) => value.name,
    decode: _parse,
  );

  static ValueNotifier<MessageActionsStyle> get current => _setting.current;

  /// Style the menu opens with. iOS ignores a stored radial choice and
  /// always uses the list.
  static MessageActionsStyle get effective =>
      IosRelease.messageActionsStyleChoice
      ? current.value
      : MessageActionsStyle.list;

  static Future<MessageActionsStyle> load() => _setting.load();

  static Future<void> save(MessageActionsStyle style) => _setting.save(style);

  static MessageActionsStyle _parse(String? val) =>
      enumFromName(MessageActionsStyle.values, val, MessageActionsStyle.list);

  // #***! подписи для настроек
  static String label(MessageActionsStyle style) {
    switch (style) {
      case MessageActionsStyle.radial:
        return 'Радиальное';
      case MessageActionsStyle.list:
        return 'Список';
    }
  }
}
