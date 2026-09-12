import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/stickers.dart';
import 'package:komet/core/protocol/opcode_map.dart';

class _SyntheticCatalogApi extends Api {
  final List<Map<String, dynamic>> stickers;

  _SyntheticCatalogApi(this.stickers);

  @override
  Future<Map<dynamic, dynamic>?> sendRequestMap(
    int opcode,
    Map<dynamic, dynamic> payload,
  ) async {
    if (opcode == Opcode.assetsUpdate && payload['type'] == 'STICKER') {
      return {
        'sections': [
          {
            'id': 'NEW_STICKER_SETS',
            'stickerSets': [10, 11],
            'marker': 0,
          },
        ],
      };
    }
    if (opcode == Opcode.assetsUpdate) return {'sections': const []};
    if (opcode == Opcode.assetsGetByIds && payload['type'] == 'STICKER_SET') {
      return {
        'stickerSets': [
          {
            'id': 10,
            'name': 'Synthetic A',
            'stickers': [1, 2],
          },
          {
            'id': 11,
            'name': 'Synthetic B',
            'stickers': [3],
          },
        ],
      };
    }
    if (opcode == Opcode.assetsGetByIds && payload['type'] == 'STICKER') {
      final ids = (payload['ids'] as List).toSet();
      return {
        'stickers': [
          for (final sticker in stickers)
            if (ids.contains(sticker['id'])) sticker,
        ],
      };
    }
    return null;
  }
}

class _WideCatalogApi extends Api {
  final int setCount;
  int stickerRequests = 0;

  _WideCatalogApi(this.setCount);

  @override
  Future<Map<dynamic, dynamic>?> sendRequestMap(
    int opcode,
    Map<dynamic, dynamic> payload,
  ) async {
    if (opcode == Opcode.assetsUpdate && payload['type'] == 'STICKER') {
      return {
        'sections': [
          {
            'id': 'NEW_STICKER_SETS',
            'stickerSets': [for (var i = 0; i < setCount; i++) 100 + i],
            'marker': 0,
          },
        ],
      };
    }
    if (opcode == Opcode.assetsUpdate) return {'sections': const []};
    final ids = [for (final id in payload['ids'] as List) id as int];
    if (opcode == Opcode.assetsGetByIds && payload['type'] == 'STICKER_SET') {
      return {
        'stickerSets': [
          for (final id in ids)
            {
              'id': id,
              'name': 'Synthetic $id',
              'stickers': [id + 1000],
            },
        ],
      };
    }
    if (opcode == Opcode.assetsGetByIds && payload['type'] == 'STICKER') {
      stickerRequests++;
      return {
        'stickers': [
          for (final id in ids) _sticker(id, ['😀']),
        ],
      };
    }
    return null;
  }
}

Map<String, dynamic> _sticker(
  int id,
  List<String> tags, {
  bool animated = true,
}) {
  return {
    'id': id,
    'url': 'https://example.test/sticker/$id.webp',
    if (animated) 'lottieUrl': 'https://example.test/sticker/$id.json',
    'tags': tags,
  };
}

void main() {
  test('prefers an animated sticker from the server welcome list', () async {
    final api = _SyntheticCatalogApi([
      _sticker(3, ['🐣', '👋🏻']),
      _sticker(50, ['🙂']),
      _sticker(51, ['🙂'], animated: false),
    ]);
    addTearDown(api.dispose);
    final module = StickersModule(api);

    for (var attempt = 0; attempt < 5; attempt++) {
      final sticker = await module.randomGreetingSticker(const [50, 51]);
      expect(sticker?.id, 50);
    }
  });

  test('falls back to a static welcome sticker', () async {
    final api = _SyntheticCatalogApi([
      _sticker(51, ['🙂'], animated: false),
    ]);
    addTearDown(api.dispose);
    final module = StickersModule(api);

    expect((await module.randomGreetingSticker(const [51]))?.id, 51);
  });

  test('picks only an animated sticker tagged with a wave', () async {
    final api = _SyntheticCatalogApi([
      _sticker(1, ['😀']),
      _sticker(2, ['👋'], animated: false),
      _sticker(3, ['🐣', '👋🏻']),
    ]);
    addTearDown(api.dispose);
    final module = StickersModule(api);

    for (var attempt = 0; attempt < 5; attempt++) {
      final sticker = await module.randomGreetingSticker(const []);
      expect(sticker?.id, 3);
    }
  });

  test('returns nothing when no sticker greets', () async {
    final api = _SyntheticCatalogApi([
      _sticker(1, ['😀']),
      _sticker(3, ['🐣']),
    ]);
    addTearDown(api.dispose);
    final module = StickersModule(api);

    expect(await module.randomGreetingSticker(const []), isNull);
  });

  test('gives up after a few packs without a greeting', () async {
    final api = _WideCatalogApi(20);
    addTearDown(api.dispose);
    final module = StickersModule(api);

    expect(await module.randomGreetingSticker(const []), isNull);
    expect(api.stickerRequests, StickersModule.greetingSetScanLimit);
  });
}
