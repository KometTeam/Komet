import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

// #***! источник PulseAudio для звонков на десктопе
class AppPulseSource {
  static const prefKey = 'call_pulse_source';
  static const String defaultValue = '';

  static final _setting = PersistedSetting<String>(
    prefKey: prefKey,
    defaultValue: defaultValue,
    read: (prefs, key) => prefs.getString(key),
    write: (prefs, key, value) async {
      await prefs.setString(key, value);
    },
  );

  static ValueNotifier<String> get current => _setting.current;

  static String? get name =>
      _setting.current.value.isEmpty ? null : _setting.current.value;

  static Future<String> load() => _setting.load();

  static Future<void> save(String value) => _setting.save(value);
}
