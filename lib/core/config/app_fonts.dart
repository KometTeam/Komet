import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFont {
  final String id;
  final String label;
  final String googleFamily;

  const AppFont({
    required this.id,
    required this.label,
    required this.googleFamily,
  });
}

class AppFonts {
  static const String prefKey = 'app_font';

  static const List<AppFont> all = [
    AppFont(id: 'inter', label: 'Inter', googleFamily: 'Inter'),
    AppFont(id: 'unbounded', label: 'Unbounded', googleFamily: 'Unbounded'),
  ];

  static AppFont get fallback => all.first;

  static AppFont byId(String? id) {
    return all.firstWhere((f) => f.id == id, orElse: () => fallback);
  }

  static TextTheme textTheme(String id, TextTheme base) {
    return GoogleFonts.getTextTheme(byId(id).googleFamily, base);
  }

  static TextStyle sample(String id, {required double fontSize}) {
    return GoogleFonts.getFont(byId(id).googleFamily, fontSize: fontSize);
  }
}
