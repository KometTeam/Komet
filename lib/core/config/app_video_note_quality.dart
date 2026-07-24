import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

class AppVideoNoteResolution {
  static const prefKey = 'dev_video_note_resolution';
  static const int defaultValue = 480;
  static const List<int> presets = [480, 720, 1080];

  static final _setting = PersistedSetting<int>(
    prefKey: prefKey,
    defaultValue: defaultValue,
    read: (prefs, key) => prefs.getInt(key),
    write: (prefs, key, value) async {
      await prefs.setInt(key, value);
    },
    sanitize: (value) => presets.contains(value) ? value : defaultValue,
  );

  static ValueNotifier<int> get current => _setting.current;

  static Future<int> load() => _setting.load();

  static Future<void> save(int value) => _setting.save(value);
}

class AppVideoNoteRearCamera {
  static const prefKey = 'dev_video_note_rear_camera';
  static const bool defaultValue = false;

  static final _setting = PersistedSetting<bool>(
    prefKey: prefKey,
    defaultValue: defaultValue,
    read: (prefs, key) => prefs.getBool(key),
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static ValueNotifier<bool> get current => _setting.current;

  static Future<bool> load() => _setting.load();

  static Future<void> save(bool value) => _setting.save(value);
}

class AppVideoNoteFps {
  static const prefKey = 'dev_video_note_fps';
  static const int defaultValue = 30;
  static const List<int> presets = [30, 60];

  static final _setting = PersistedSetting<int>(
    prefKey: prefKey,
    defaultValue: defaultValue,
    read: (prefs, key) => prefs.getInt(key),
    write: (prefs, key, value) async {
      await prefs.setInt(key, value);
    },
    sanitize: (value) => presets.contains(value) ? value : defaultValue,
  );

  static ValueNotifier<int> get current => _setting.current;

  static Future<int> load() => _setting.load();

  static Future<void> save(int value) => _setting.save(value);
}
