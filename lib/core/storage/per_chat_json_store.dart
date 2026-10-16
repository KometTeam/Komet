import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// #***! база для всех настроек на чат, всё одним джейсоном в prefs
abstract class PerChatJsonStore<T> {
  static final Set<PerChatJsonStore<Object?>> _all = {};

  static Future<void> flushAll() async {
    for (final store in _all) {
      await store.flush();
    }
  }

  PerChatJsonStore({
    required String prefsKey,
    required T? Function(Object? raw) fromJson,
    required Object? Function(T value) toJson,
  }) : _prefsKey = prefsKey,
       _fromJson = fromJson,
       _toJson = toJson {
    _all.add(this as PerChatJsonStore<Object?>);
  }

  final String _prefsKey;
  final T? Function(Object? raw) _fromJson;
  final Object? Function(T value) _toJson;

  final Map<String, T> _values = {};
  // #***! revision на каждую запись, списки подписаны
  final ValueNotifier<int> revision = ValueNotifier(0);
  bool _loaded = false;
  Future<void>? _loading;
  Timer? _persistTimer;
  static const Duration _persistDelay = Duration(milliseconds: 400);

  String _buildKey(int accountId, int chatId) => '$accountId/$chatId';

  // #***! наследники ходят только через read/write
  @protected
  Iterable<MapEntry<String, T>> get allEntries => _values.entries;

  @protected
  void onBeforeWrite(String key, T? previous, T? next) {}

  // #***! читаем один раз, битый джейсон молча игнорим чтоб не блокировать старт
  bool get isLoaded => _loaded;

  Future<void> load() {
    if (_loaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    try {
      if (raw == null) return;
      final map = jsonDecode(raw);
      if (map is Map) {
        map.forEach((k, v) {
          if (k is! String) return;
          final value = _fromJson(v);
          if (value != null) _values[k] = value;
        });
      }
    } catch (_) {
    } finally {
      _loaded = true;
    }
  }

  @protected
  T? read(int accountId, int chatId) {
    if (accountId == 0) return null;
    return _values[_buildKey(accountId, chatId)];
  }
  Future<void> clearAll() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (_values.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      return;
    }
    _values.clear();
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  Future<void> flush() async {
    if (_persistTimer == null) return;
    _persistTimer!.cancel();
    _persistTimer = null;
    await _persist();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDelay, () {
      _persistTimer = null;
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final serializable = <String, dynamic>{};
    _values.forEach((k, v) => serializable[k] = _toJson(v));
    await prefs.setString(_prefsKey, jsonEncode(serializable));
  }

  // #***! accountId 0 значит не залогинены, писать некуда
  @protected
  Future<void> write(int accountId, int chatId, T? value) async {
    if (accountId == 0) return;
    await load();
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
    _schedulePersist();
  }
}
