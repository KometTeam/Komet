import 'package:flutter/foundation.dart';

import 'persisted_setting.dart';

class AppCamera {
  static const prefKey = 'media_camera_id';

  static final _setting = PersistedSetting<String>(
    prefKey: prefKey,
    defaultValue: '',
    read: (prefs, key) => prefs.getString(key),
    write: (prefs, key, value) async {
      await prefs.setString(key, value);
    },
  );

  static ValueNotifier<String> get current => _setting.current;

  static String? get deviceId =>
      _setting.current.value.isEmpty ? null : _setting.current.value;

  static Future<String> load() => _setting.load();

  static Future<void> save(String value) => _setting.save(value);
}

class AppVideoNoteCamera {
  static final _custom = PersistedSetting<bool>(
    prefKey: 'video_note_custom_camera',
    defaultValue: false,
    read: (prefs, key) => prefs.getBool(key),
    write: (prefs, key, value) async {
      await prefs.setBool(key, value);
    },
  );

  static ValueNotifier<bool> get useCustom => _custom.current;

  static String? get customCameraId =>
      _custom.current.value ? AppCamera.deviceId : null;

  static Future<bool> load() => _custom.load();

  static Future<void> setUseCustom(bool value) => _custom.save(value);
}
