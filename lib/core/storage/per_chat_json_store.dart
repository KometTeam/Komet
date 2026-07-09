import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class PerChatJsonStore<T> {
  PerChatJsonStore({
    required String prefsKey,
    required T? Function(Object? raw) fromJson,
    required Object? Function(T value) toJson,
  }) : _prefsKey = prefsKey,
       _fromJson = fromJson,
       _toJson = toJson;

  final String _prefsKey;
  final T? Function(Object? raw) _fromJson;
  final Object? Function(T value) _toJson;

  final Map<String, T> _values = {};
  final ValueNotifier<int> revision = ValueNotifier(0);
  bool _loaded = false;

  String _buildKey(int accountId, int chatId) => '$accountId/$chatId';

  @protected
  Iterable<MapEntry<String, T>> get allEntries => _values.entries;

  @protected
  void onBeforeWrite(String key, T? previous, T? next) {}

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        map.forEach((k, v) {
          if (k is! String) return;
          final value = _fromJson(v);
          if (value != null) _values[k] = value;
        });
      }
    } catch (_) {}
  }

  @protected
  T? read(int accountId, int chatId) {
    if (accountId == 0) return null;
    return _values[_buildKey(accountId, chatId)];
  }

  @protected
  Future<void> write(int accountId, int chatId, T? value) async {
    if (accountId == 0) return;
    final key = _buildKey(accountId, chatId);
    final previous = _values[key];
    onBeforeWrite(key, previous, value);
    if (value == null) {
      if (previous == null) return;
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    final serializable = <String, dynamic>{};
    _values.forEach((k, v) => serializable[k] = _toJson(v));
    await prefs.setString(_prefsKey, jsonEncode(serializable));
  }
}
