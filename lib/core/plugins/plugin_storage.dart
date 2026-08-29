import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PluginStorage {
  PluginStorage(this.pluginId);

  final String pluginId;

  String get _key => 'plugin_storage_v1_$pluginId';

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

  Future<Object?> get(String key) async => (await _readAll())[key];

  Future<void> set(String key, Object? value) async {
    final all = await _readAll();
    all[key] = value;
    final encoded = jsonEncode(all);
    if (encoded.length > 65536) {
      throw const FormatException('Хранилище плагина переполнено');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, encoded);
  }

  Future<void> remove(String key) async {
    final all = await _readAll();
    if (all.remove(key) == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }
}
