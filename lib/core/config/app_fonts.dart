import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppFont {
  final String id;
  final String label;
  final String? googleFamily;

  const AppFont({
    required this.id,
    required this.label,
    this.googleFamily,
  });

  bool get isSystem => googleFamily == null;
  bool get isCustom => id.startsWith(AppFonts.customPrefix);
}

class AppFonts {
  static const String prefKey = 'app_font';
  static const String scalePrefKey = 'app_font_scale';
  static const String customPrefKey = 'app_custom_fonts';
  static const String customPrefix = 'g:';

  static const double minScale = 0.60;
  static const double maxScale = 1.35;
  static const double defaultScale = 1.0;

  static const List<AppFont> builtIn = [
    AppFont(id: 'system', label: 'Системный'),
    AppFont(id: 'inter', label: 'Inter', googleFamily: 'Inter'),
    AppFont(id: 'unbounded', label: 'Unbounded', googleFamily: 'Unbounded'),
  ];

  static AppFont get fallback => builtIn.first;

  static String customId(String family) => '$customPrefix$family';

  static AppFont resolve(String id) {
    if (id.startsWith(customPrefix)) {
      final family = id.substring(customPrefix.length);
      return AppFont(id: id, label: family, googleFamily: family);
    }
    return builtIn.firstWhere((f) => f.id == id, orElse: () => fallback);
  }

  static TextTheme textTheme(String id, TextTheme base) {
    final family = resolve(id).googleFamily;
    if (family == null) return base;
    try {
      return GoogleFonts.getTextTheme(family, base);
    } catch (_) {
      return base;
    }
  }

  static TextStyle sample(String id, {required double fontSize}) {
    final family = resolve(id).googleFamily;
    if (family == null) return TextStyle(fontSize: fontSize);
    try {
      return GoogleFonts.getFont(family, fontSize: fontSize);
    } catch (_) {
      return TextStyle(fontSize: fontSize);
    }
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

  static String? matchGoogleFamily(String family) {
    final map = GoogleFonts.asMap();
    if (map.containsKey(family)) return family;
    final lower = family.toLowerCase();
    for (final key in map.keys) {
      if (key.toLowerCase() == lower) return key;
    }
    return null;
  }

  static Future<List<String>> loadCustomFamilies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(customPrefKey) ?? const <String>[];
  }

  static Future<void> addCustomFamily(String family) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(customPrefKey) ?? <String>[];
    if (!list.contains(family)) {
      list.add(family);
      await prefs.setStringList(customPrefKey, list);
    }
  }

  static Future<void> removeCustomFamily(String family) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(customPrefKey) ?? <String>[];
    list.remove(family);
    await prefs.setStringList(customPrefKey, list);
  }
}
