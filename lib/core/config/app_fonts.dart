import 'package:flutter/material.dart';

class AppFont {
  final String id;
  final String label;
  final String? fontFamily;

  const AppFont({required this.id, required this.label, this.fontFamily});

  bool get isSystem => fontFamily == null;
  bool get isCustom => id.startsWith(AppFonts.customPrefix);
}

class AppFonts {
  static const String prefKey = 'app_font';
  static const String scalePrefKey = 'app_font_scale';
  static const String customPrefix = 'g:';

  static const double minScale = 0.60;
  static const double maxScale = 1.35;
  static const double defaultScale = 1.0;

  static const List<AppFont> builtIn = [
    AppFont(id: 'system', label: 'Системный'),
    AppFont(id: 'inter', label: 'Inter', fontFamily: 'Inter'),
    AppFont(id: 'unbounded', label: 'Unbounded', fontFamily: 'Unbounded'),
  ];

  static AppFont get fallback => builtIn.first;

  static String customId(String family) => '$customPrefix$family';

  static AppFont resolve(String id) {
    if (id.startsWith(customPrefix)) {
      final family = id.substring(customPrefix.length);
      return AppFont(id: id, label: family, fontFamily: family);
    }
    return builtIn.firstWhere((f) => f.id == id, orElse: () => fallback);
  }

  static TextTheme textTheme(String id, TextTheme base) {
    final family = resolve(id).fontFamily;
    if (family == null) return base;
    return base.apply(fontFamily: family);
  }

  static TextStyle sample(String id, {required double fontSize}) {
    final family = resolve(id).fontFamily;
    return TextStyle(fontFamily: family, fontSize: fontSize);
  }

  static double clampScale(double scale) =>
      scale.clamp(minScale, maxScale).toDouble();

  static String? familyFromInput(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null && uri.host.contains('fonts.google.com')) {
      final idx = uri.pathSegments.indexOf('specimen');
      if (idx != -1 && idx + 1 < uri.pathSegments.length) {
        value = uri.pathSegments[idx + 1];
      }
    }

    try {
      value = Uri.decodeComponent(value);
    } catch (_) {}
    value = value.replaceAll('+', ' ').trim();
    return value.isEmpty ? null : value;
  }
}
