import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/format.dart';

class ThemeSchedule {
  final TimeOfDay darkStart;
  final TimeOfDay darkEnd;

  const ThemeSchedule({required this.darkStart, required this.darkEnd});

  bool isDarkAt(DateTime now) {
    final nowMin = now.hour * 60 + now.minute;
    final startMin = darkStart.hour * 60 + darkStart.minute;
    final endMin = darkEnd.hour * 60 + darkEnd.minute;
    if (startMin == endMin) return false;
    if (startMin < endMin) {
      return nowMin >= startMin && nowMin < endMin;
    }
    return nowMin >= startMin || nowMin < endMin;
  }

  Duration durationUntilNextSwitch(DateTime now) {
    final nowMin = now.hour * 60 + now.minute;
    final startMin = darkStart.hour * 60 + darkStart.minute;
    final endMin = darkEnd.hour * 60 + darkEnd.minute;
    int? nextMin;
    for (final m in [startMin, endMin]) {
      final delta = (m - nowMin + 1440) % 1440;
      final candidate = delta == 0 ? 1440 : delta;
      if (nextMin == null || candidate < nextMin) nextMin = candidate;
    }
    final secondsLeft = (nextMin ?? 1) * 60 - now.second;
    return Duration(seconds: secondsLeft.clamp(1, 24 * 60 * 60));
  }
}

class AppThemeSchedule {
  static const prefKey = 'app_theme_schedule';
  static const _defaultStart = TimeOfDay(hour: 22, minute: 0);
  static const _defaultEnd = TimeOfDay(hour: 7, minute: 0);

  static final ValueNotifier<ThemeSchedule> current = ValueNotifier(
    const ThemeSchedule(darkStart: _defaultStart, darkEnd: _defaultEnd),
  );

  static Future<ThemeSchedule> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = _parse(prefs.getString(prefKey));
    current.value = value;
    return value;
  }

  static Future<void> save(ThemeSchedule schedule) async {
    current.value = schedule;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefKey,
      '${_fmt(schedule.darkStart)}-${_fmt(schedule.darkEnd)}',
    );
  }

  static String _fmt(TimeOfDay t) => '${pad2(t.hour)}:${pad2(t.minute)}';

  static ThemeSchedule _parse(String? val) {
    if (val == null) {
      return const ThemeSchedule(
        darkStart: _defaultStart,
        darkEnd: _defaultEnd,
      );
    }
    final parts = val.split('-');
    if (parts.length != 2) {
      return const ThemeSchedule(
        darkStart: _defaultStart,
        darkEnd: _defaultEnd,
      );
    }
    final start = _parseTime(parts[0]) ?? _defaultStart;
    final end = _parseTime(parts[1]) ?? _defaultEnd;
    return ThemeSchedule(darkStart: start, darkEnd: end);
  }

  static TimeOfDay? _parseTime(String val) {
    final parts = val.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String format(TimeOfDay t) => _fmt(t);
}
