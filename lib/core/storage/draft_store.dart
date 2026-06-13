import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftStore {
  DraftStore._();

  static final DraftStore instance = DraftStore._();

  static const String _prefsKey = 'chat_drafts';

  final Map<String, String> _drafts = {};
  final ValueNotifier<int> revision = ValueNotifier(0);
  bool _loaded = false;

  String _key(int accountId, int chatId) => '$accountId/$chatId';

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
          if (k is String && v is String) _drafts[k] = v;
        });
      }
    } catch (_) {}
  }

  String? get(int accountId, int chatId) {
    if (accountId == 0) return null;
    return _drafts[_key(accountId, chatId)];
  }

  Future<void> set(int accountId, int chatId, String text) async {
    if (accountId == 0) return;
    final key = _key(accountId, chatId);
    final current = _drafts[key];
    if (text.trim().isEmpty) {
      if (current == null) return;
      _drafts.remove(key);
    } else {
      if (current == text) return;
      _drafts[key] = text;
    }
    revision.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_drafts));
  }

  Future<void> clear(int accountId, int chatId) => set(accountId, chatId, '');
}
