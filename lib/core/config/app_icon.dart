import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppIcon {
  defaultIcon('default', 'Default', 'assets/komet_icon.png', null),
  minimal('minimal', 'Minimal', 'assets/meteor_icon.png', 'MinimalIcon');

  final String id;
  final String title;
  final String previewAsset;
  final String? platformName;

  const AppIcon(this.id, this.title, this.previewAsset, this.platformName);
}

class AppIconConfig {
  static const prefKey = 'app_icon';
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
    await FlutterDynamicIconPlus.setAlternateIconName(
      iconName: icon.platformName,
    );
    current.value = icon;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, icon.id);
  }

  static AppIcon _parse(String? val) {
    for (final icon in AppIcon.values) {
      if (icon.id == val) return icon;
    }
    return AppIcon.defaultIcon;
  }
}
