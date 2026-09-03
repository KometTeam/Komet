import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HiddenStoryAuthors {
  HiddenStoryAuthors._();

  static const _key = 'hidden_story_authors';
  static final ValueNotifier<Set<int>> ids = ValueNotifier(<int>{});
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    ids.value = {
      for (final item in raw)
        if (int.tryParse(item) != null) int.parse(item),
    };
    _loaded = true;
  }

  static bool isHidden(int ownerId) => ids.value.contains(ownerId);

  static Future<void> hide(int ownerId) async {
    await load();
    if (ownerId == 0 || ids.value.contains(ownerId)) return;
    ids.value = {...ids.value, ownerId};
    await _persist();
  }

  static Future<void> show(int ownerId) async {
    await load();
    if (!ids.value.contains(ownerId)) return;
    final next = {...ids.value}..remove(ownerId);
    ids.value = next;
    await _persist();
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      ids.value.map((id) => id.toString()).toList(),
    );
  }
}
