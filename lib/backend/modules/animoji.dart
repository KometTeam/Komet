import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/utils/logger.dart';
import '../../models/animoji.dart';

class AnimojiModule {
  final Api _api;

  AnimojiModule(this._api);

  static const List<String> fallbackReactions = [
    '👍',
    '❤️',
    '🔥',
    '🤣',
    '😭',
    '😍',
  ];

  static const String _recentsKey = 'komet_recent_animoji';
  static const int _maxRecents = 24;

  final Map<int, Animoji> _byId = {};
  List<int> _orderedIds = [];
  List<int> _recentIds = [];
  bool _recentsLoaded = false;
  Future<void>? _loading;

  bool get isLoaded => _orderedIds.isNotEmpty;

  List<Animoji> get animojis =>
      _orderedIds.map((id) => _byId[id]).whereType<Animoji>().toList();

  List<Animoji> get recentAnimojis =>
      _recentIds.map((id) => _byId[id]).whereType<Animoji>().toList();

  List<String> get emojis => animojis.map((a) => a.emoji).toList();

  Future<void> ensureRecentsLoaded() async {
    if (_recentsLoaded) return;
    _recentsLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentsKey) ?? const [];
      _recentIds = raw.map(int.tryParse).whereType<int>().toList();
    } catch (_) {}
  }

  Future<void> noteUsed(Animoji animoji) async {
    await ensureRecentsLoaded();
    _byId[animoji.id] = animoji;
    _recentIds.remove(animoji.id);
    _recentIds.insert(0, animoji.id);
    if (_recentIds.length > _maxRecents) {
      _recentIds = _recentIds.sublist(0, _maxRecents);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _recentsKey,
        _recentIds.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  List<Animoji> get quickAnimojis {
    final list = animojis;
    return list.length <= 6 ? list : list.sublist(0, 6);
  }

  Future<void> ensureLoaded() {
    return _loading ??= _load().catchError((Object e) {
      _loading = null;
      throw e;
    });
  }

  Future<void> _load() async {
    final setIds = <int>[];
    final fallbackIds = <int>[];

    final sync = await _api.sendRequestMap(Opcode.assetsUpdate, {
      'type': 'ANIMOJI_SET',
      'sync': 0,
    });
    if (sync != null) {
      final sections = sync['sections'];
      if (sections is List) {
        for (final s in sections) {
          if (s is Map) _appendIntList(setIds, s['animojiSetIds']);
        }
      }
      final updates = sync['animojiUpdates'];
      if (updates is Map) {
        for (final key in updates.keys) {
          final id = key is int ? key : int.tryParse(key.toString());
          if (id != null) fallbackIds.add(id);
        }
      }
    }

    final orderedIds = <int>[];
    if (setIds.isNotEmpty) {
      final setMap = await _api.sendRequestMap(Opcode.assetsGetByIds, {
        'type': 'ANIMOJI_SET',
        'ids': setIds,
      });
      if (setMap != null) {
        final sets = setMap['animojiSets'];
        if (sets is List) {
          for (final set in sets) {
            if (set is! Map) continue;
            _appendIntList(orderedIds, set['animojis']);
            _appendIntList(orderedIds, set['animojiIds']);
          }
        }
      }
    }

    final ids = _dedup(orderedIds.isNotEmpty ? orderedIds : fallbackIds);
    if (ids.isEmpty) return;

    for (final batch in _chunk(ids, 100)) {
      final map = await _api.sendRequestMap(Opcode.assetsGetByIds, {
        'type': 'ANIMOJI',
        'ids': batch,
      });
      if (map == null) continue;
      final list = map['animojis'];
      if (list is! List) continue;
      for (final e in list) {
        if (e is! Map) continue;
        final animoji = Animoji.fromMap(e);
        if (animoji != null) _byId[animoji.id] = animoji;
      }
    }

    _orderedIds = ids.where(_byId.containsKey).toList();
    logger.i('Анимодзи: ${_orderedIds.length} доступно для реакций');
  }

  List<int> _dedup(List<int> ids) {
    final seen = <int>{};
    final result = <int>[];
    for (final id in ids) {
      if (seen.add(id)) result.add(id);
    }
    return result;
  }

  void _appendIntList(List<int> target, dynamic raw) {
    if (raw is! List) return;
    for (final e in raw) {
      if (e is int) target.add(e);
    }
  }

  Iterable<List<T>> _chunk<T>(List<T> list, int size) sync* {
    for (var i = 0; i < list.length; i += size) {
      yield list.sublist(i, i + size > list.length ? list.length : i + size);
    }
  }
}
