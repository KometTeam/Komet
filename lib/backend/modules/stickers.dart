import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/utils/logger.dart';
import '../../models/sticker.dart';

class StickersModule {
  final Api _api;

  StickersModule(this._api) {
    _api.pushStream
        .where((p) => p.opcode == Opcode.notifAssetsUpdate)
        .listen(_handleAssetsPush);
  }

  final Map<int, StickerSet> _sets = {};
  final Map<int, StickerItem> _stickers = {};
  List<int> _orderedSetIds = [];
  List<int> _favoriteSetIds = [];
  List<int> _recentStickerIds = [];

  Future<void>? _loading;
  Future<void>? _favoritesLoading;

  List<StickerSet> get sets =>
      _orderedSetIds.map((id) => _sets[id]).whereType<StickerSet>().toList();

  List<int> get favoriteSetIds => _favoriteSetIds;
  List<int> get recentStickerIds => _recentStickerIds;
  StickerItem? cachedSticker(int id) => _stickers[id];
  StickerSet? cachedSet(int id) => _sets[id];
  bool isFavorite(int setId) => _favoriteSetIds.contains(setId);

  Future<void> ensureLoaded() {
    return _loading ??= _loadSections().catchError((Object e) {
      _loading = null;
      throw e;
    });
  }

  Future<void> ensureFavoritesLoaded() {
    return _favoritesLoading ??= _loadFavorites().catchError((Object e) {
      _favoritesLoading = null;
      throw e;
    });
  }

  Future<void> _loadFavorites() async {
    final favIds = <int>[];
    final fav = await _api.sendRequestMap(Opcode.assetsUpdate, {
      'type': 'FAVORITE_STICKER',
      'sync': 0,
    });
    if (fav != null) {
      final sections = fav['sections'];
      if (sections is List) {
        for (final s in sections) {
          if (s is Map && s['id'] == 'FAVORITE_STICKER_SETS') {
            _appendIntList(favIds, s['stickerSets']);
          }
        }
      }
    }
    _favoriteSetIds = favIds;
  }

  Future<void> _loadSections() async {
    final newSetIds = <int>[];
    int marker = 0;

    final stickerData = await _api.sendRequestMap(Opcode.assetsUpdate, {
      'type': 'STICKER',
      'sync': 0,
    });
    if (stickerData != null) {
      final sections = stickerData['sections'];
      if (sections is List) {
        for (final s in sections) {
          if (s is! Map) continue;
          if (s['id'] == 'NEW_STICKER_SETS') {
            _appendIntList(newSetIds, s['stickerSets']);
            final m = s['marker'];
            if (m is int) marker = m;
          } else if (s['type'] == 'RECENTS') {
            _parseRecents(s['recentsList']);
          }
        }
      }
    }

    var guard = 0;
    while (marker != 0 && guard < 50) {
      guard++;
      final page = await _api.sendRequestMap(Opcode.assetsGet, {
        'sectionId': 'NEW_STICKER_SETS',
        'from': marker,
        'count': 100,
      });
      if (page == null) break;
      final before = newSetIds.length;
      _appendIntList(newSetIds, page['stickerSets']);
      if (newSetIds.length == before) break;
      final m = page['marker'];
      marker = m is int ? m : 0;
    }

    await ensureFavoritesLoaded();

    final ordered = <int>[];
    final seen = <int>{};
    for (final id in [..._favoriteSetIds, ...newSetIds]) {
      if (seen.add(id)) ordered.add(id);
    }
    _orderedSetIds = ordered;
    logger.i(
      'Стикеры: ${ordered.length} паков, ${_recentStickerIds.length} недавних',
    );

    await _ensureSetMetas(ordered);
  }

  Future<void> _fetchAndCache<T>({
    required String type,
    required List<int> ids,
    required String listKey,
    required T Function(Map) fromMap,
    required Map<int, T> cache,
  }) async {
    final missing = ids.where((id) => !cache.containsKey(id)).toList();
    for (final batch in _chunk(missing, 100)) {
      final map = await _api.sendRequestMap(Opcode.assetsGetByIds, {
        'type': type,
        'ids': batch,
      });
      if (map == null) continue;
      final list = map[listKey];
      if (list is! List) continue;
      for (final e in list) {
        if (e is Map && e['id'] is int) {
          cache[e['id'] as int] = fromMap(e);
        }
      }
    }
  }

  Future<void> _ensureSetMetas(List<int> ids) => _fetchAndCache<StickerSet>(
    type: 'STICKER_SET',
    ids: ids,
    listKey: 'stickerSets',
    fromMap: StickerSet.fromMap,
    cache: _sets,
  );

  Future<List<StickerItem>> ensureStickers(List<int> stickerIds) async {
    await _fetchAndCache<StickerItem>(
      type: 'STICKER',
      ids: stickerIds,
      listKey: 'stickers',
      fromMap: StickerItem.fromMap,
      cache: _stickers,
    );
    return stickerIds
        .map((id) => _stickers[id])
        .whereType<StickerItem>()
        .toList();
  }

  Future<StickerSet?> ensureSet(int setId) async {
    await _ensureSetMetas([setId]);
    return _sets[setId];
  }

  Future<void> ensureAllStickersLoaded() {
    final ids = <int>{..._recentStickerIds};
    for (final set in _sets.values) {
      ids.addAll(set.stickerIds);
    }
    return ensureStickers(ids.toList());
  }

  List<StickerItem> searchByTags(Set<String> emojiTargets) {
    if (emojiTargets.isEmpty) return const [];
    final result = <StickerItem>[];
    for (final sticker in _stickers.values) {
      for (final tag in sticker.tags) {
        if (emojiTargets.contains(_stripVariation(tag))) {
          result.add(sticker);
          break;
        }
      }
    }
    return result;
  }

  static String _stripVariation(String s) => s.replaceAll('️', '');

  void cacheSet(StickerSet set) => _sets[set.id] = set;

  Future<StickerSet?> resolveSetByLink(String link) async {
    final map = await _api.sendRequestMap(Opcode.linkInfo, {'link': link});
    if (map == null) return null;
    final raw = map['stickerSet'];
    if (raw is! Map || raw['id'] is! int) return null;
    final set = StickerSet.fromMap(raw);
    _sets[set.id] = set;
    return set;
  }

  Future<int?> resolveSetId(int stickerId) async {
    await ensureStickers([stickerId]);
    return _stickers[stickerId]?.setId;
  }

  Future<bool> favoriteSet(int setId) async {
    final map = await _api.sendRequestMap(Opcode.assetsAdd, {
      'type': 'FAVORITE_STICKER_SET',
      'id': setId,
    });
    final ok = map != null && map['success'] == true;
    if (ok) _markFavorite(setId, true);
    return ok;
  }

  Future<bool> unfavoriteSet(int setId) async {
    final map = await _api.sendRequestMap(Opcode.assetsRemove, {
      'type': 'FAVORITE_STICKER_SET',
      'ids': [setId],
    });
    final ok = map != null && map['success'] == true;
    if (ok) _markFavorite(setId, false);
    return ok;
  }

  void _handleAssetsPush(Packet push) {
    final payload = push.payload;
    if (payload is! Map) return;
    if (payload['type'] != 'FAVORITE_STICKER_SET') return;
    final id = payload['id'];
    if (id is! int) return;
    switch (payload['updateType']) {
      case 'ADDED':
        _markFavorite(id, true);
      case 'REMOVED':
        _markFavorite(id, false);
    }
  }

  void _markFavorite(int setId, bool favorite) {
    if (favorite) {
      if (!_favoriteSetIds.contains(setId)) {
        _favoriteSetIds = [setId, ..._favoriteSetIds];
      }
    } else {
      if (_favoriteSetIds.contains(setId)) {
        _favoriteSetIds = _favoriteSetIds.where((id) => id != setId).toList();
      }
    }
  }

  void _parseRecents(dynamic list) {
    if (list is! List) return;
    final ids = <int>[];
    for (final e in list) {
      if (e is Map && e['type'] == 'STICKER') {
        final sid = e['stickerId'] ?? e['id'];
        if (sid is int) ids.add(sid);
      }
    }
    _recentStickerIds = ids;
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
