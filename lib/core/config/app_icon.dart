import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    'MinimalIcon',
  );

  final String id;
  final String title;
  final String previewAsset;
  final String androidAlias;
  final String? iosAlternateName;

  const AppIcon(
    this.id,
    this.title,
    this.previewAsset,
    this.androidAlias,
    this.iosAlternateName,
  );
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
    var icon = _parse(prefs.getString(prefKey));
    final applied = await _appliedIcon();
    if (applied != null && applied != icon) {
      icon = applied;
      await prefs.setString(prefKey, icon.id);
    }
    current.value = icon;
  }

  static Future<void> apply(AppIcon icon) async {
    if (!isSupported) return;
    if (current.value == icon) return;
    await _channel.invokeMethod<void>('setAppIcon', {
      'name': Platform.isIOS ? icon.iosAlternateName : icon.androidAlias,
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
