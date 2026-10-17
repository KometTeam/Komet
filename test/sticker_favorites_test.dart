import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/stickers.dart';
import 'package:komet/core/protocol/opcode_map.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/core/storage/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _pinnedA = 7001;
const int _pinnedB = 7002;
const int _pinnedC = 7003;
const int _recent = 7101;
const int _recentB = 7102;
const int _pinnedSet = 8001;

class _AssetsApi extends Api {
  final pushes = StreamController<Packet>.broadcast();
  final List<({int opcode, Map<dynamic, dynamic> payload, bool silent})>
  requests = [];
  List<int> favoriteStickers = const [_pinnedA];
  int favoriteMarker = 0;
  List<int> favoriteNextPage = const [];
  bool accept = true;
  Completer<void>? catalogGate;
  List<int> catalogSets = const [];

  @override
  Stream<Packet> get pushStream => pushes.stream;

  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
    void Function()? beforeSend,
  }) async {
    requests.add((opcode: opcode, payload: payload, silent: silent));
    if (opcode == Opcode.assetsUpdate && payload['type'] == 'STICKER') {
      await catalogGate?.future;
    }
    return Packet(
      cmd: CmdType.ok,
      opcode: opcode,
      payload: _respond(opcode, payload),
    );
  }

  Map<dynamic, dynamic>? _respond(int opcode, Map<dynamic, dynamic> payload) {
    if (opcode == Opcode.assetsUpdate &&
        payload['type'] == 'FAVORITE_STICKER') {
      return {
        'sync': 1,
        'sections': [
          {
            'type': 'STICKERS',
            'id': 'FAVORITE_STICKERS',
            'stickers': favoriteStickers,
            'totalCount': favoriteStickers.length + favoriteNextPage.length,
            if (favoriteMarker != 0) 'marker': favoriteMarker,
          },
          {
            'type': 'STICKER_SETS',
            'id': 'FAVORITE_STICKER_SETS',
            'stickerSets': [_pinnedSet],
          },
        ],
        'stickersOrder': ['FAVORITE_STICKERS', 'FAVORITE_STICKER_SETS'],
      };
    }
    if (opcode == Opcode.assetsUpdate && payload['type'] == 'STICKER') {
      return {
        'sections': [
          {
            'type': 'RECENTS',
            'recentsList': [
              {'type': 'STICKER', 'id': 1, 'stickerId': _recent},
              {'type': 'GIF', 'id': 2},
            ],
          },
          if (catalogSets.isNotEmpty)
            {
              'type': 'STICKER_SETS',
              'id': 'NEW_STICKER_SETS',
              'stickerSets': catalogSets,
            },
        ],
      };
    }
    if (opcode == Opcode.assetsAdd ||
        opcode == Opcode.assetsRemove ||
        opcode == Opcode.assetsListModify) {
      return {'success': accept, 'updateTime': 1};
    }
    if (opcode == Opcode.assetsGet &&
        payload['sectionId'] == 'FAVORITE_STICKERS' &&
        payload['from'] == favoriteMarker) {
      return {'stickers': favoriteNextPage};
    }
    if (opcode == Opcode.assetsGetByIds &&
        payload['type'] == 'STICKER_SET' &&
        catalogSets.isNotEmpty) {
      return {
        'stickerSets': [
          for (final id in payload['ids'] as List)
            {
              'id': id,
              'name': 'Set $id',
              'stickers': [(id as int) * 10],
            },
        ],
      };
    }
    if (opcode == Opcode.assetsGetByIds) return {'stickerSets': const []};
    return null;
  }

  List<Map<dynamic, dynamic>> sent(int opcode) => [
    for (final r in requests)
      if (r.opcode == opcode) r.payload,
  ];

  bool sentSilently(int opcode) =>
      requests.where((r) => r.opcode == opcode).every((r) => r.silent);
}

Packet _assetsPush(String type, int id, String updateType) =>
    _push({'type': type, 'id': id, 'updateType': updateType});

Packet _push(Map<String, dynamic> payload) => Packet(
  cmd: CmdType.push,
  opcode: Opcode.notifAssetsUpdate,
  payload: payload,
);

Map<String, dynamic> _recentItem(int stickerId) => {
  'type': 'STICKER',
  'id': stickerId + 1000,
  'stickerId': stickerId,
};

void main() {
  late _AssetsApi api;
  late StickersModule stickers;

  setUp(() {
    api = _AssetsApi();
    stickers = StickersModule(api);
  });

  tearDown(() => api.pushes.close());

  test('pinned stickers come from the FAVORITE_STICKER sync', () async {
    await stickers.ensureFavoritesLoaded();

    expect(stickers.favoriteStickerIds.value, [_pinnedA]);
    expect(stickers.isFavoriteSticker(_pinnedA), isTrue);
    expect(stickers.isFavorite(_pinnedSet), isTrue);
  });

  test('pin and unpin send the asset requests the server expects', () async {
    await stickers.ensureFavoritesLoaded();
    var notified = 0;
    stickers.favoriteStickerIds.addListener(() => notified++);

    expect(await stickers.favoriteSticker(_pinnedB), isTrue);
    expect(api.sent(Opcode.assetsAdd).single, {
      'type': 'FAVORITE_STICKER',
      'id': _pinnedB,
    });
    expect(stickers.favoriteStickerIds.value, [_pinnedB, _pinnedA]);

    expect(await stickers.unfavoriteSticker(_pinnedA), isTrue);
    expect(api.sent(Opcode.assetsRemove).single, {
      'type': 'FAVORITE_STICKER',
      'ids': [_pinnedA],
    });
    expect(stickers.favoriteStickerIds.value, [_pinnedB]);
    expect(notified, 2);
  });

  test('a rejected pin leaves the list untouched', () async {
    await stickers.ensureFavoritesLoaded();
    api.accept = false;

    expect(await stickers.favoriteSticker(_pinnedB), isFalse);
    expect(stickers.favoriteStickerIds.value, [_pinnedA]);
  });

  test('pushes from another device update pinned stickers', () async {
    await stickers.ensureFavoritesLoaded();

    api.pushes.add(_assetsPush('FAVORITE_STICKER', _pinnedB, 'ADDED'));
    await pumpEventQueue();
    expect(stickers.favoriteStickerIds.value, [_pinnedB, _pinnedA]);

    api.pushes.add(_assetsPush('FAVORITE_STICKER', _pinnedA, 'REMOVED'));
    await pumpEventQueue();
    expect(stickers.favoriteStickerIds.value, [_pinnedB]);
    expect(stickers.isFavorite(_pinnedSet), isTrue);
  });

  test('clearing recents empties the list on success', () async {
    await stickers.ensureLoaded();
    expect(stickers.recentStickerIds.value, [_recent]);

    expect(await stickers.clearRecentStickers(), isTrue);
    expect(api.sent(Opcode.assetsListModify).single, {
      'type': 'RECENT',
      'ids': <int>[],
    });
    expect(stickers.recentStickerIds.value, isEmpty);
  });

  test('switching accounts drops the previous pinned stickers', () async {
    SharedPreferences.setMockInitialValues({});
    await stickers.ensureLoaded();
    expect(stickers.recentStickerIds.value, [_recent]);

    await TokenStorage.setActiveAccount(424242);
    api.favoriteStickers = const [_pinnedB];
    await stickers.ensureFavoritesLoaded();

    expect(stickers.favoriteStickerIds.value, [_pinnedB]);
    expect(stickers.recentStickerIds.value, isEmpty);
  });

  test('favorites beyond the first page are fetched by marker', () async {
    api.favoriteMarker = 55;
    api.favoriteNextPage = const [_pinnedB];

    await stickers.ensureFavoritesLoaded();

    expect(stickers.favoriteStickerIds.value, [_pinnedA, _pinnedB]);
    expect(
      api
          .sent(Opcode.assetsGet)
          .where((p) => p['sectionId'] == 'FAVORITE_STICKERS')
          .single,
      {'sectionId': 'FAVORITE_STICKERS', 'from': 55, 'count': 100},
    );
  });

  test('pinned pushes accept ids and keep the moved order', () async {
    await stickers.ensureFavoritesLoaded();

    api.pushes.add(
      _push({
        'type': 'FAVORITE_STICKER',
        'ids': [_pinnedB, _pinnedC],
        'updateType': 'ADDED',
      }),
    );
    await pumpEventQueue();
    expect(stickers.favoriteStickerIds.value, [_pinnedB, _pinnedC, _pinnedA]);

    api.pushes.add(
      _push({
        'type': 'FAVORITE_STICKER',
        'id': _pinnedA,
        'position': 0,
        'updateType': 'MOVED',
      }),
    );
    await pumpEventQueue();
    expect(stickers.favoriteStickerIds.value, [_pinnedA, _pinnedB, _pinnedC]);
  });

  test('a sent sticker shows up in recents from the server push', () async {
    await stickers.ensureLoaded();
    expect(stickers.recentStickerIds.value, [_recent]);

    api.pushes.add(
      _push({
        'type': 'RECENT',
        'updateType': 'ADDED',
        'recentsList': [_recentItem(_recentB)],
      }),
    );
    await pumpEventQueue();
    expect(stickers.recentStickerIds.value, [_recentB, _recent]);

    api.pushes.add(
      _push({
        'type': 'RECENT',
        'updateType': 'ADDED',
        'recentsList': [_recentItem(_recent)],
      }),
    );
    await pumpEventQueue();
    expect(stickers.recentStickerIds.value, [_recent, _recentB]);
  });

  test('recents follow list updates and removals', () async {
    await stickers.ensureLoaded();

    api.pushes.add(
      _push({
        'type': 'RECENT',
        'updateType': 'LIST_UPDATED',
        'recentsList': [_recentItem(_recentB), _recentItem(_recent)],
      }),
    );
    await pumpEventQueue();
    expect(stickers.recentStickerIds.value, [_recentB, _recent]);

    api.pushes.add(
      _push({
        'type': 'RECENT',
        'updateType': 'REMOVED',
        'recentsList': [_recentItem(_recentB)],
      }),
    );
    await pumpEventQueue();
    expect(stickers.recentStickerIds.value, [_recent]);
  });

  test('recents come back after clearing once a sticker is sent', () async {
    await stickers.ensureLoaded();
    await stickers.clearRecentStickers();
    expect(stickers.recentStickerIds.value, isEmpty);

    api.pushes.add(
      _push({
        'type': 'RECENT',
        'updateType': 'ADDED',
        'recentsList': [_recentItem(_recentB)],
      }),
    );
    await pumpEventQueue();
    expect(stickers.recentStickerIds.value, [_recentB]);
  });

  test(
    'asset writes are silent so the caller reports a single error',
    () async {
      await stickers.ensureFavoritesLoaded();

      await stickers.favoriteSticker(_pinnedB);
      await stickers.unfavoriteSticker(_pinnedB);
      await stickers.clearRecentStickers();

      expect(api.sentSilently(Opcode.assetsAdd), isTrue);
      expect(api.sentSilently(Opcode.assetsRemove), isTrue);
      expect(api.sentSilently(Opcode.assetsListModify), isTrue);
    },
  );

  test('pushes that change nothing do not notify listeners', () async {
    await stickers.ensureLoaded();
    var pinnedNotified = 0;
    var recentNotified = 0;
    stickers.favoriteStickerIds.addListener(() => pinnedNotified++);
    stickers.recentStickerIds.addListener(() => recentNotified++);

    api.pushes.add(_assetsPush('FAVORITE_STICKER', _pinnedA, 'ADDED'));
    api.pushes.add(_assetsPush('FAVORITE_STICKER', _pinnedB, 'REMOVED'));
    api.pushes.add(
      _push({
        'type': 'RECENT',
        'updateType': 'ADDED',
        'recentsList': [_recentItem(_recent)],
      }),
    );
    await pumpEventQueue();

    expect(pinnedNotified, 0);
    expect(recentNotified, 0);
  });

  test('pinned stickers load alongside the catalog, not after it', () async {
    final gate = Completer<void>();
    api.catalogGate = gate;

    final loading = stickers.ensureLoaded();
    await pumpEventQueue();

    expect(
      api.sent(Opcode.assetsUpdate).map((p) => p['type']),
      containsAll(['STICKER', 'FAVORITE_STICKER']),
    );
    expect(stickers.favoriteStickerIds.value, [_pinnedA]);

    gate.complete();
    await loading;
    expect(stickers.recentStickerIds.value, [_recent]);
  });

  test('favorites are replaced with the list that stays', () async {
    api.favoriteStickers = const [_pinnedA, _pinnedB, _pinnedC];
    await stickers.ensureFavoritesLoaded();

    expect(await stickers.setFavoriteStickers([_pinnedA, _pinnedC]), isTrue);

    expect(api.sent(Opcode.assetsListModify).single, {
      'type': 'FAVORITE_STICKER',
      'ids': [_pinnedA, _pinnedC],
    });
    expect(api.sentSilently(Opcode.assetsListModify), isTrue);
    expect(stickers.favoriteStickerIds.value, [_pinnedA, _pinnedC]);
  });

  test('a rejected replacement keeps the stickers', () async {
    api.favoriteStickers = const [_pinnedA, _pinnedB];
    await stickers.ensureFavoritesLoaded();
    api.accept = false;

    expect(await stickers.setFavoriteStickers(const [_pinnedB]), isFalse);
    expect(stickers.favoriteStickerIds.value, [_pinnedA, _pinnedB]);
  });

  test('selected recents are removed by id, the rest stay', () async {
    await stickers.ensureLoaded();
    api.pushes.add(
      _push({
        'type': 'RECENT',
        'updateType': 'LIST_UPDATED',
        'recentsList': [_recentItem(_recent), _recentItem(_recentB)],
      }),
    );
    await pumpEventQueue();

    expect(await stickers.removeRecentStickers(const [_recent]), isTrue);

    expect(api.sent(Opcode.assetsRemove).single, {
      'type': 'RECENT',
      'ids': [_recent],
    });
    expect(api.sent(Opcode.assetsListModify), isEmpty);
    expect(stickers.recentStickerIds.value, [_recentB]);
  });

  test('a rejected recent removal keeps the stickers', () async {
    await stickers.ensureLoaded();
    api.accept = false;

    expect(await stickers.removeRecentStickers(const [_recent]), isFalse);
    expect(stickers.recentStickerIds.value, [_recent]);
  });

  test('adding a set moves it to the top and announces it', () async {
    api.catalogSets = const [8101, 8102, 8103];
    await stickers.ensureLoaded();
    expect(stickers.sets.map((s) => s.id), [_pinnedSet, 8101, 8102, 8103]);
    var announced = 0;
    stickers.setsChanged.addListener(() => announced++);

    expect(await stickers.favoriteSet(8103), isTrue);
    expect(stickers.sets.map((s) => s.id), [8103, _pinnedSet, 8101, 8102]);
    expect(stickers.isFavorite(8103), isTrue);

    expect(await stickers.unfavoriteSet(_pinnedSet), isTrue);
    expect(stickers.sets.map((s) => s.id), [8103, 8101, 8102, _pinnedSet]);
    expect(announced, 2);
  });
}
