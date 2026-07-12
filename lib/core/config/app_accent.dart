import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppAccent {
  static const prefKey = 'app_accent_seed';

  static const List<({String label, Color? seed})> presets = [
    (label: 'Системный', seed: null),
    (label: 'Сиреневый', seed: Color(0xFFC1C4FF)),
    (label: 'Синий', seed: Color(0xFF4F8EFF)),
    (label: 'Бирюзовый', seed: Color(0xFF00BFA5)),
    (label: 'Зелёный', seed: Color(0xFF43A047)),
    (label: 'Янтарный', seed: Color(0xFFFFB300)),
    (label: 'Розовый', seed: Color(0xFFE91E63)),
    (label: 'Красный', seed: Color(0xFFE53935)),
    (label: 'Фиолетовый', seed: Color(0xFF7E57C2)),
  ];

  static Future<Color?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt(prefKey);
    if (val == null) return null;
    return Color(val);
  }

  static Future<void> save(Color? color) async {
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(prefKey);
    } else {
      await prefs.setInt(prefKey, color.toARGB32());
    }
  }
}
