import 'dart:convert';

import 'package:flutter/services.dart';

class _Entry {
  final String emoji;
  final List<String> tokens;

  const _Entry(this.emoji, this.tokens);
}

class EmojiKeywordIndex {
  EmojiKeywordIndex._();

  static final EmojiKeywordIndex instance = EmojiKeywordIndex._();

  static const _variationSelector = '️';
  static final _wordPattern = RegExp(r'[0-9a-zа-яё\-]{2,}', unicode: true);

  final List<_Entry> _entries = [];
  final Set<String> _emojiKeys = {};
  Future<void>? _loading;

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/emoji_keywords.json');
    final map = json.decode(raw) as Map<String, dynamic>;
    map.forEach((emoji, words) {
      _entries.add(_Entry(emoji, (words as String).split(' ')));
      _emojiKeys.add(emoji);
    });
  }

  List<String> get all =>
      List.unmodifiable(_entries.map((e) => e.emoji));

  List<String> search(String query) {
    final targets = resolve(query);
    if (targets.isEmpty) return const [];
    return [
      for (final entry in _entries)
        if (targets.contains(entry.emoji)) entry.emoji,
    ];
  }

  static String normalize(String emoji) =>
      emoji.replaceAll(_variationSelector, '');

  Set<String> resolve(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const {};

    final targets = <String>{};
    final normalized = normalize(q);
    for (final key in _emojiKeys) {
      if (normalized.contains(key)) targets.add(key);
    }

    final words = _wordPattern
        .allMatches(q)
        .map((m) => m.group(0)!)
        .toList(growable: false);
    if (words.isEmpty) return targets;

    for (final entry in _entries) {
      for (final word in words) {
        if (_hasPrefix(entry.tokens, word)) {
          targets.add(entry.emoji);
          break;
        }
      }
    }
    return targets;
  }

  static bool _hasPrefix(List<String> tokens, String prefix) {
    for (final token in tokens) {
      if (token.startsWith(prefix)) return true;
    }
    return false;
  }
}
