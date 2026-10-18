import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../config/app_accent.dart';
import '../config/app_theme_mode.dart';
import '../config/app_theme_schedule.dart';
import '../utils/seed_scheme.dart';
import 'native_share_account_channel.dart';

// #***! тема шэринга: акцент и палитра приложения в app-group для расширения
class ShareThemeExport {
  ShareThemeExport._();

  static const _fileName = 'theme.json';
  static const _fallbackSeed = Color(0xFFC1C4FF);

  static Future<void> export() async {
    final root = await NativeShareAccountChannel.instance.shareDirectory();
    if (root == null) return;
    try {
      final seed = await AppAccent.load() ?? _fallbackSeed;
      final mode = await AppThemeModeConfig.load();
      final system =
          mode == AppThemeMode.system || mode == AppThemeMode.schedule;
      var dark = mode == AppThemeMode.dark;
      if (mode == AppThemeMode.schedule) {
        dark = AppThemeSchedule.current.value.isDarkAt(DateTime.now());
      }
      final payload = {
        'system': system,
        'current': dark ? 'dark' : 'light',
        'light': _variant(accentSchemeFromSeed(seed, Brightness.light)),
        'dark': _variant(accentSchemeFromSeed(seed, Brightness.dark)),
      };
      final file = File('$root/$_fileName');
      final part = File('${file.path}.part');
      await part.writeAsString(jsonEncode(payload), flush: true);
      await part.rename(file.path);
    } catch (_) {}
  }

  static Map<String, String> _variant(ColorScheme scheme) => {
    'accent': _hex(scheme.primary),
    'onAccent': _hex(scheme.onPrimary),
    'surface': _hex(scheme.surface),
    'card': _hex(scheme.surfaceContainerHigh),
    'text': _hex(scheme.onSurface),
    'subtext': _hex(scheme.onSurfaceVariant),
    'hairline': _hex(scheme.outlineVariant),
  };

  static String _hex(Color color) =>
      color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
}
