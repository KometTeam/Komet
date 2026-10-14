import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api.dart';
import '../../core/protocol/opcode_map.dart';
import '../../core/protocol/packet.dart';
import '../../core/storage/token_storage.dart';
import '../../core/utils/logger.dart';
import '../../models/sticker.dart';

// #***! каталог стикеров, паки избранное недавние
class StickersModule {
  final Api _api;

  // #***! сервер пушит избранное с других устройств
  StickersModule(this._api) {
    _api.pushStream
        .where((p) => p.opcode == Opcode.notifAssetsUpdate)
        .listen(_handleAssetsPush);
  }

  static const String _favoriteSetType = 'FAVORITE_STICKER_SET';
  static const String _favoriteStickerType = 'FAVORITE_STICKER';

  // #***! всё в памяти, между запусками перезапрашиваем
  final Map<int, StickerSet> _sets = {};
  final Map<int, StickerItem> _stickers = {};
  List<int> _orderedSetIds = [];
  List<int> _favoriteSetIds = [];
  final ValueNotifier<List<int>> _favoriteStickerIds = ValueNotifier(
    const <int>[],
  );
  final ValueNotifier<List<int>> _recentStickerIds = ValueNotifier(
    const <int>[],
  );
  int _accountEpoch = TokenStorage.accountEpoch;

  Future<void>? _loading;
  Future<void>? _favoritesLoading;
  final Random _random = Random();

  List<StickerSet> get sets =>
      _orderedSetIds.map((id) => _sets[id]).whereType<StickerSet>().toList();

  List<int> get favoriteSetIds => _favoriteSetIds;
  ValueListenable<List<int>> get favoriteStickerIds => _favoriteStickerIds;
  ValueListenable<List<int>> get recentStickerIds => _recentStickerIds;
  StickerItem? cachedSticker(int id) => _stickers[id];
  StickerSet? cachedSet(int id) => _sets[id];
  bool isFavorite(int setId) => _favoriteSetIds.contains(setId);
  bool isFavoriteSticker(int stickerId) =>
      _favoriteStickerIds.value.contains(stickerId);

  // #***! схлопываем параллельные вызовы
  Future<void> ensureLoaded() {
    _dropStaleAccount();
    return _loading ??= _loadSections().catchError((Object e) {
      _loading = null;
      throw e;
    });
  }

  Future<void> ensureFavoritesLoaded() {
    _dropStaleAccount();
    return _favoritesLoading ??= _loadFavorites().catchError((Object e) {
      _favoritesLoading = null;
      throw e;
    });
  }

  void _dropStaleAccount() {
    final epoch = TokenStorage.accountEpoch;
    if (epoch == _accountEpoch) return;
    _accountEpoch = epoch;
    _loading = null;
    _favoritesLoading = null;
    _orderedSetIds = [];
    _favoriteSetIds = [];
    _assign(_favoriteStickerIds, const <int>[]);
    _assign(_recentStickerIds, const <int>[]);
  }

  static void _assign(ValueNotifier<List<int>> notifier, List<int> ids) {
    if (!listEquals(notifier.value, ids)) notifier.value = ids;
  }

  // #***! избранные паки отдельным запросом и первыми
  Future<void> _loadFavorites() async {
    final setIds = <int>[];
    final stickerIds = <int>[];
    var setMarker = 0;
    var stickerMarker = 0;
    final fav = await _api.sendRequestMap(Opcode.assetsUpdate, {
      'type': _favoriteStickerType,
      'sync': 0,
    });
    final sections = fav?['sections'];
    if (sections is List) {
      for (final s in sections) {
        if (s is! Map) continue;
        switch (s['id']) {
          case 'FAVORITE_STICKER_SETS':
            _appendIntList(setIds, s['stickerSets']);
            setMarker = _markerOf(s);
          case 'FAVORITE_STICKERS':
            _appendIntList(stickerIds, s['stickers']);
            stickerMarker = _markerOf(s);
        }
      }
    }
    await _appendPages(
      'FAVORITE_STICKER_SETS',
      'stickerSets',
      setMarker,
      setIds,
    );
    await _appendPages(
      'FAVORITE_STICKERS',
      'stickers',
      stickerMarker,
      stickerIds,
    );
    _favoriteSetIds = setIds;
    _assign(_favoriteStickerIds, stickerIds);
  }

  Future<void> _loadSections() async {
    final catalog = _loadCatalog();
    final favorites = ensureFavoritesLoaded();
    await Future.wait<void>([catalog, favorites]);
    final newSetIds = await catalog;

    // #***! сперва избранные потом остальные, без дублей
    final ordered = <int>[];
    final seen = <int>{};
    for (final id in [..._favoriteSetIds, ...newSetIds]) {
      if (seen.add(id)) ordered.add(id);
    }
    _orderedSetIds = ordered;
    logger.i(
      'Стикеры: ${ordered.length} паков, '
      '${_favoriteStickerIds.value.length} закреплённых, '
      '${_recentStickerIds.value.length} недавних',
    );

    await _ensureSetMetas(ordered);
  }

  // #***! каталог, первая страница потом докрутка по marker
  Future<List<int>> _loadCatalog() async {
    final newSetIds = <int>[];
    var marker = 0;

    final stickerData = await _api.sendRequestMap(Opcode.assetsUpdate, {
      'type': 'STICKER',
      'sync': 0,
    });
    final sections = stickerData?['sections'];
    if (sections is List) {
      for (final s in sections) {
        if (s is! Map) continue;
        if (s['id'] == 'NEW_STICKER_SETS') {
          _appendIntList(newSetIds, s['stickerSets']);
          marker = _markerOf(s);
        } else if (s['type'] == 'RECENTS') {
          _assign(_recentStickerIds, _recentStickerIdsFrom(s['recentsList']));
        }
      }
    }

    await _appendPages('NEW_STICKER_SETS', 'stickerSets', marker, newSetIds);
    return newSetIds;
  }

  // #***! guard от бесконечного цикла если marker тот же
  Future<void> _appendPages(
    String sectionId,
    String listKey,
    int marker,
    List<int> target,
  ) async {
    var guard = 0;
    while (marker != 0 && guard < 50) {
      guard++;
      final page = await _api.sendRequestMap(Opcode.assetsGet, {
        'sectionId': sectionId,
        'from': marker,
        'count': 100,
      });
      if (page == null) break;
      final before = target.length;
      _appendIntList(target, page[listKey]);
      if (target.length == before) break;
      marker = _markerOf(page);
    }
  }

  static int _markerOf(Map section) {
    final marker = section['marker'];
    return marker is int ? marker : 0;
  }

  // #***! общий догруз с кэшем, пачками по 100
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

  // #***! стикеры пака
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

  // #***! для поиска по эмодзи нужны все сразу
  Future<void> ensureAllStickersLoaded() {
    final ids = <int>{..._favoriteStickerIds.value, ..._recentStickerIds.value};
    for (final set in _sets.values) {
      ids.addAll(set.stickerIds);
    }
    return ensureStickers(ids.toList());
  }

  // #***! поиск стикера по эмодзи тегу
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

  // #***! у эмодзи бывает вариационный селектор, без него теги сходятся
  static String _stripVariation(String s) => s.replaceAll('️', '');

  static const String greetingEmoji = '👋';
  static const int greetingSetScanLimit = 5;

  Future<StickerItem?> randomGreetingSticker(List<int> welcomeIds) async {
    if (welcomeIds.isNotEmpty) {
      final welcome = await ensureStickers(welcomeIds);
      final animated = welcome.where((s) => s.isAnimated).toList();
      final pool = animated.isNotEmpty ? animated : welcome;
      if (pool.isNotEmpty) return pool[_random.nextInt(pool.length)];
    }
    final cached = _animatedGreetings();
    if (cached.isNotEmpty) return cached[_random.nextInt(cached.length)];
    await ensureLoaded();
    final shuffled = List<StickerSet>.of(sets)..shuffle(_random);
    for (final set in shuffled.take(greetingSetScanLimit)) {
      await ensureStickers(set.stickerIds);
      final found = _animatedGreetings();
      if (found.isNotEmpty) return found[_random.nextInt(found.length)];
    }
    return null;
  }

  List<StickerItem> _animatedGreetings() => [
    for (final sticker in _stickers.values)
      if (sticker.isAnimated &&
          sticker.tags.any((tag) => tag.contains(greetingEmoji)))
        sticker,
  ];

  void cacheSet(StickerSet set) => _sets[set.id] = set;

  // #***! открытие пака по ссылке
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

  // #***! избранное правим локально сразу, пуш не ждём
  Future<bool> favoriteSet(int setId) =>
      _setFavorite(_favoriteSetType, setId, true);

  Future<bool> unfavoriteSet(int setId) =>
      _setFavorite(_favoriteSetType, setId, false);

  Future<bool> favoriteSticker(int stickerId) =>
      _setFavorite(_favoriteStickerType, stickerId, true);

  Future<bool> unfavoriteSticker(int stickerId) =>
      _setFavorite(_favoriteStickerType, stickerId, false);

  Future<bool> _setFavorite(String type, int id, bool favorite) async {
    final ok = favorite
        ? await _modify(Opcode.assetsAdd, {'type': type, 'id': id})
        : await _modify(Opcode.assetsRemove, {
            'type': type,
            'ids': [id],
          });
    if (ok) _applyFavorite(type, id, favorite);
    return ok;
  }

  Future<bool> clearRecentStickers() async {
    final ok = await _modify(Opcode.assetsListModify, {
      'type': 'RECENT',
      'ids': <int>[],
    });
    if (ok) _assign(_recentStickerIds, const <int>[]);
    return ok;
  }

  Future<bool> _modify(int opcode, Map<dynamic, dynamic> payload) async {
    final response = await _api.sendRequest(opcode, payload, silent: true);
    final map = response.payload;
    return response.isOk && map is Map && map['success'] == true;
  }

  // #***! пуш об избранном и недавних, в том числе с другого устройства
  void _handleAssetsPush(Packet push) {
    final payload = push.payload;
    if (payload is! Map) return;
    switch (payload['type']) {
      case 'RECENT':
        _applyRecentsUpdate(payload);
      case _favoriteSetType:
        _favoriteSetIds = _applyListUpdate(_favoriteSetIds, payload);
      case _favoriteStickerType:
        _assign(
          _favoriteStickerIds,
          _applyListUpdate(_favoriteStickerIds.value, payload),
        );
    }
  }

  void _applyRecentsUpdate(Map payload) {
    final raw = payload['recentsList'];
    if (raw is! List) return;
    final ids = _recentStickerIdsFrom(raw);
    final current = _recentStickerIds.value;
    switch (payload['updateType']) {
      case 'LIST_UPDATED':
        _assign(_recentStickerIds, ids);
      case 'ADDED' when ids.isNotEmpty:
        _assign(_recentStickerIds, _prepended(current, ids));
      case 'REMOVED' when ids.isNotEmpty:
        _assign(_recentStickerIds, _without(current, ids));
    }
  }

  static List<int> _applyListUpdate(List<int> current, Map payload) {
    final ids = <int>[];
    final id = payload['id'];
    if (id is int) ids.add(id);
    _appendIntList(ids, payload['ids']);
    if (ids.isEmpty) return current;
    switch (payload['updateType']) {
      case 'ADDED':
        return _prepended(current, ids);
      case 'REMOVED':
        return _without(current, ids);
      case 'MOVED':
        final position = payload['position'];
        return position is int ? _moved(current, ids, position) : current;
    }
    return current;
  }

  void _applyFavorite(String type, int id, bool favorite) {
    switch (type) {
      case _favoriteSetType:
        _favoriteSetIds = favorite
            ? _prepended(_favoriteSetIds, [id])
            : _without(_favoriteSetIds, [id]);
      case _favoriteStickerType:
        final current = _favoriteStickerIds.value;
        _assign(
          _favoriteStickerIds,
          favorite ? _prepended(current, [id]) : _without(current, [id]),
        );
    }
  }

  static List<int> _prepended(List<int> current, List<int> ids) {
    final fresh = ids.toSet();
    return [...ids, ...current.where((id) => !fresh.contains(id))];
  }

  static List<int> _without(List<int> current, List<int> ids) {
    final gone = ids.toSet();
    return current.where((id) => !gone.contains(id)).toList();
  }

  static List<int> _moved(List<int> current, List<int> ids, int position) {
    final result = [...current];
    for (final id in ids) {
      final from = result.indexOf(id);
      if (from == -1 || from == position) continue;
      result.removeAt(from);
      result.insert(position.clamp(0, result.length), id);
    }
    return result;
  }

  // #***! недавние приходят вперемешку, берём только стикеры
  static List<int> _recentStickerIdsFrom(dynamic list) {
    final ids = <int>[];
    if (list is! List) return ids;
    for (final e in list) {
      if (e is Map && e['type'] == 'STICKER') {
        final sid = e['stickerId'] ?? e['id'];
        if (sid is int) ids.add(sid);
      }
    }
    return ids;
  }

  static void _appendIntList(List<int> target, dynamic raw) {
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
