import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/utils/logger.dart';
import '../../models/sticker.dart';

class StickersModule {
  final Api _api;

  StickersModule(this._api);

  final Map<int, StickerSet> _sets = {};
  final Map<int, StickerItem> _stickers = {};
  List<int> _orderedSetIds = [];
  List<int> _favoriteSetIds = [];
  List<int> _recentStickerIds = [];

  Future<void>? _loading;

  List<StickerSet> get sets =>
      _orderedSetIds.map((id) => _sets[id]).whereType<StickerSet>().toList();

  List<int> get favoriteSetIds => _favoriteSetIds;
  List<int> get recentStickerIds => _recentStickerIds;
  StickerItem? cachedSticker(int id) => _stickers[id];

  Future<void> ensureLoaded() {
    return _loading ??= _loadSections().catchError((Object e) {
      _loading = null;
      throw e;
    });
  }

  Future<void> _loadSections() async {
    final newSetIds = <int>[];
    int marker = 0;

    final stickerResp = await _api.sendRequest(Opcode.assetsUpdate, {
      'type': 'STICKER',
      'sync': 0,
    });
    if (stickerResp.isOk && stickerResp.payload is Map) {
      final sections = stickerResp.payload['sections'];
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
      final page = await _api.sendRequest(Opcode.assetsGet, {
        'sectionId': 'NEW_STICKER_SETS',
        'from': marker,
        'count': 100,
      });
      if (!page.isOk || page.payload is! Map) break;
      final before = newSetIds.length;
      _appendIntList(newSetIds, page.payload['stickerSets']);
      if (newSetIds.length == before) break;
      final m = page.payload['marker'];
      marker = m is int ? m : 0;
    }

    final favIds = <int>[];
    final favResp = await _api.sendRequest(Opcode.assetsUpdate, {
      'type': 'FAVORITE_STICKER',
      'sync': 0,
    });
    if (favResp.isOk && favResp.payload is Map) {
      final sections = favResp.payload['sections'];
      if (sections is List) {
        for (final s in sections) {
          if (s is Map && s['id'] == 'FAVORITE_STICKER_SETS') {
            _appendIntList(favIds, s['stickerSets']);
          }
        }
      }
    }
    _favoriteSetIds = favIds;

    final ordered = <int>[];
    final seen = <int>{};
    for (final id in [...favIds, ...newSetIds]) {
      if (seen.add(id)) ordered.add(id);
    }
    _orderedSetIds = ordered;
    logger.i('Стикеры: ${ordered.length} паков, ${_recentStickerIds.length} недавних');

    await _ensureSetMetas(ordered);
  }

  Future<void> _ensureSetMetas(List<int> ids) async {
    final missing = ids.where((id) => !_sets.containsKey(id)).toList();
    for (final batch in _chunk(missing, 100)) {
      final resp = await _api.sendRequest(Opcode.assetsGetByIds, {
        'type': 'STICKER_SET',
        'ids': batch,
      });
      if (!resp.isOk || resp.payload is! Map) continue;
      final list = resp.payload['stickerSets'];
      if (list is! List) continue;
      for (final e in list) {
        if (e is Map && e['id'] is int) {
          final set = StickerSet.fromMap(e);
          _sets[set.id] = set;
        }
      }
    }
  }

  Future<List<StickerItem>> ensureStickers(List<int> stickerIds) async {
    final missing = stickerIds.where((id) => !_stickers.containsKey(id)).toList();
    for (final batch in _chunk(missing, 100)) {
      final resp = await _api.sendRequest(Opcode.assetsGetByIds, {
        'type': 'STICKER',
        'ids': batch,
      });
      if (!resp.isOk || resp.payload is! Map) continue;
      final list = resp.payload['stickers'];
      if (list is! List) continue;
      for (final e in list) {
        if (e is Map && e['id'] is int) {
          final item = StickerItem.fromMap(e);
          _stickers[item.id] = item;
        }
      }
    }
    return stickerIds
        .map((id) => _stickers[id])
        .whereType<StickerItem>()
        .toList();
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
