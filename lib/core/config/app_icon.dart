import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// #***! не_skam — только iOS, у андроида нет алиаса
enum AppIcon {
  defaultIcon(
    'default',
    'Default',
    'assets/komet_icon.png',
    'MainActivity',
    null,
  ),
  minimal(
    'minimal',
    'Minimal',
    'assets/meteor_icon.png',
    'MinimalIcon',
    'meteor_icon',
  ),
  notSkam('not_skam', 'Not Skam', 'assets/not_skam.png', null, 'not_skam');

  final String id;
  final String title;
  final String previewAsset;
  final String? androidAlias;
  final String? iosAlternateName;

  const AppIcon(
    this.id,
    this.title,
    this.previewAsset,
    this.androidAlias,
    this.iosAlternateName,
  );
}

// #***! переключение иконки
class AppIconConfig {
  static const prefKey = 'app_icon';
  static const _channel = MethodChannel('ru.komet.app/app_icon');

  static final ValueNotifier<AppIcon> current = ValueNotifier(
    AppIcon.defaultIcon,
  );

  // #***! на вебе иконку не поменять; на mac — рантайм-свап Dock-иконки
  static bool get isSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  // #***! иос может сбросить иконку сам, на старте сверяемся
  static Future<void> load() async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    var icon = _parse(prefs.getString(prefKey));
    if (Platform.isAndroid && icon.androidAlias == null) {
      icon = AppIcon.defaultIcon;
    }
    final applied = await _appliedIcon();
    if (applied != null && applied != icon) {
      icon = applied;
      await prefs.setString(prefKey, icon.id);
    }
    current.value = icon;
    // #***! Dock-иконка на mac не переживает перезапуск — восстанавливаем
    if (Platform.isMacOS) await apply(icon);
  }

  // #***! список иконок, доступных на текущей платформе
  static List<AppIcon> get available {
    if (Platform.isIOS || Platform.isMacOS) return AppIcon.values;
    if (Platform.isAndroid) {
      return AppIcon.values.where((i) => i.androidAlias != null).toList();
    }
    return const [];
  }

  // #***! меняем через натив потом сохраняем выбор
  static Future<void> apply(AppIcon icon) async {
    if (!isSupported) return;
    if (Platform.isMacOS && current.value == icon) return;
    await _channel.invokeMethod<void>('setAppIcon', {
      'name': Platform.isAndroid ? icon.androidAlias : icon.iosAlternateName,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, icon.id);
    current.value = icon;
  }

  static Future<AppIcon?> _appliedIcon() async {
    if (!Platform.isIOS) return null;
    try {
      final name = await _channel.invokeMethod<String>('getAppIcon');
      for (final icon in AppIcon.values) {
        if (icon.iosAlternateName == name) return icon;
      }
    } catch (_) {}
    return null;
  }

  static AppIcon _parse(String? val) {
    for (final icon in AppIcon.values) {
      if (icon.id == val) return icon;
    }
    return AppIcon.defaultIcon;
  }
}
