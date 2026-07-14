import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppIcon {
  defaultIcon('default', 'Default', 'assets/komet_icon.png', 'MainActivity'),
  minimal('minimal', 'Minimal', 'assets/meteor_icon.png', 'MinimalIcon');

  final String id;
  final String title;
  final String previewAsset;
  final String platformName;

  const AppIcon(this.id, this.title, this.previewAsset, this.platformName);
}

class AppIconConfig {
  static const prefKey = 'app_icon';
  static const _channel = MethodChannel('ru.komet.app/app_icon');

  static final ValueNotifier<AppIcon> current = ValueNotifier(
    AppIcon.defaultIcon,
  );

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static Future<void> load() async {
    if (!isSupported) return;
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(prefKey);
    current.value = _parse(id);
  }

  static Future<void> apply(AppIcon icon) async {
    if (!isSupported) return;
    if (current.value == icon) return;
    await _channel.invokeMethod<void>('setAppIcon', {
      'name': icon.platformName,
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, icon.id);
    current.value = icon;
  }

  static AppIcon _parse(String? val) {
    for (final icon in AppIcon.values) {
      if (icon.id == val) return icon;
    }
    return AppIcon.defaultIcon;
  }
}
