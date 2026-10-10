import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PluginStorage {
  PluginStorage(this.pluginId, {this.accountId}) {
    _generation = _generations.putIfAbsent(_key, () => 0);
  }

  final String pluginId;
  final int? accountId;
  static final Map<String, Future<void>> _pending = {};
  static final Map<String, int> _generations = {};
  static final Set<int> _erasingAccounts = {};
  static final Set<String> _erasingPlugins = {};
  late final int _generation;

  String get _key => accountId == null
      ? 'plugin_storage_v1_$pluginId'
      : 'plugin_storage_v2_${accountId}_$pluginId';

  Future<Map<String, dynamic>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final next = (_pending[_key] ?? Future<void>.value()).then((_) {
      if (_generation != _generations[_key] ||
          _erasingAccounts.contains(accountId) ||
          _erasingPlugins.contains(pluginId)) {
        throw StateError('Plugin storage context was invalidated');
      }
      return action();
    });
    final settled = next.then<void>((_) {}, onError: (Object error) {});
    _pending[_key] = settled;
    unawaited(
      settled.whenComplete(() {
        if (identical(_pending[_key], settled)) _pending.remove(_key);
      }),
    );
    return next;
  }

  Future<Object?> get(String key) =>
      _serialized(() async => (await _readAll())[key]);

  Future<void> set(String key, Object? value) => _serialized(() async {
    final all = await _readAll();
    all[key] = value;
    final encoded = jsonEncode(all);
    if (utf8.encode(encoded).length > 65536) {
      throw const FormatException('Хранилище плагина переполнено');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encoded);
  });

  Future<void> remove(String key) => _serialized(() async {
    final all = await _readAll();
    if (!all.containsKey(key)) return;
    all.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  });

  Future<void> clear() => _serialized(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  });
  static Future<void> _eraseKey(String key) async {
    _generations[key] = (_generations[key] ?? 0) + 1;
    final next = (_pending[key] ?? Future<void>.value()).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    });
    final settled = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending[key] = settled;
    try {
      await next;
    } finally {
      if (identical(_pending[key], settled)) _pending.remove(key);
    }
  }

  static Future<void> eraseAccount(int accountId) async {
    _erasingAccounts.add(accountId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'plugin_storage_v2_${accountId}_';
      final keys = {...prefs.getKeys(), ..._generations.keys, ..._pending.keys};
      for (final key in keys.where((key) => key.startsWith(prefix))) {
        await _eraseKey(key);
      }
    } finally {
      _erasingAccounts.remove(accountId);
    }
  }

  static Future<void> erasePlugin(String pluginId) async {
    _erasingPlugins.add(pluginId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = {...prefs.getKeys(), ..._generations.keys, ..._pending.keys};
      for (final key in keys.where(
        (key) =>
            key == 'plugin_storage_v1_$pluginId' ||
            (key.startsWith('plugin_storage_v2_') &&
                key.endsWith('_$pluginId')),
      )) {
        await _eraseKey(key);
      }
    } finally {
      _erasingPlugins.remove(pluginId);
    }
  }
}
