import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/backend/modules/stickers.dart';
import 'package:komet/core/protocol/opcode_map.dart';
import 'package:komet/core/protocol/packet.dart';
import 'package:komet/frontend/screens/stickers/sticker_collection_screen.dart';
import 'package:komet/frontend/screens/stickers/sticker_sets_screen.dart';
import 'package:komet/frontend/screens/stickers/sticker_settings_screen.dart';
import 'package:komet/l10n/app_localizations.dart';

const _pinnedA = 9101;
const _pinnedB = 9102;
const _pinnedC = 9103;
const _recent = 9201;
const _catalogSet = 9301;

class _StickerApi extends Api {
  final pushes = StreamController<Packet>.broadcast();
  final List<({int opcode, Map<dynamic, dynamic> payload})> requests = [];

  @override
  Stream<Packet> get pushStream => pushes.stream;

  @override
  Future<Packet> sendRequest(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
    void Function()? beforeSend,
  }) async {
    requests.add((opcode: opcode, payload: payload));
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
        'sections': [
          {
            'id': 'FAVORITE_STICKERS',
            'stickers': [_pinnedA, _pinnedB, _pinnedC],
          },
          {'id': 'FAVORITE_STICKER_SETS', 'stickerSets': <int>[]},
        ],
      };
    }
    if (opcode == Opcode.assetsUpdate && payload['type'] == 'STICKER') {
      return {
        'sections': [
          {
            'type': 'RECENTS',
            'recentsList': [
              {'type': 'STICKER', 'id': 1, 'stickerId': _recent},
            ],
          },
          {
            'id': 'NEW_STICKER_SETS',
            'stickerSets': [_catalogSet],
          },
        ],
      };
    }
    if (opcode == Opcode.assetsGetByIds && payload['type'] == 'STICKER_SET') {
      return {
        'stickerSets': [
          for (final id in payload['ids'] as List)
            {
              'id': id,
              'name': 'Synthetic set',
              'stickers': [_pinnedA, _pinnedB],
            },
        ],
      };
    }
    if (opcode == Opcode.assetsGetByIds && payload['type'] == 'STICKER') {
      return {
        'stickers': [
          for (final id in payload['ids'] as List) {'id': id, 'url': ''},
        ],
      };
    }
    if (opcode == Opcode.assetsAdd ||
        opcode == Opcode.assetsRemove ||
        opcode == Opcode.assetsListModify) {
      return {'success': true};
    }
    return null;
  }

  List<Map<dynamic, dynamic>> sent(int opcode) => [
    for (final r in requests)
      if (r.opcode == opcode) r.payload,
  ];
}

void main() {
  late _StickerApi api;
  late StickersModule module;

  setUp(() {
    api = _StickerApi();
    module = StickersModule(api);
  });

  tearDown(() => api.pushes.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the settings screen counts recent and favorite stickers', (
    tester,
  ) async {
    await pump(tester, StickerSettingsScreen(module: module));

    expect(find.text('Недавние'), findsOneWidget);
    expect(find.text('1 стикер'), findsOneWidget);
    expect(find.text('Избранные'), findsOneWidget);
    expect(find.text('3 стикера'), findsOneWidget);
  });

  testWidgets('selected favorites are deleted by sending what stays', (
    tester,
  ) async {
    await pump(
      tester,
      StickerCollectionScreen(
        collection: StickerCollection.favorites,
        module: module,
      ),
    );
    expect(find.text('Избранные стикеры'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sticker-list-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Изменить'));
    await tester.pumpAndSettle();
    expect(find.text('Выбрано: 0'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey(_pinnedB)));
    await tester.pump();
    expect(find.text('Выбрано: 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sticker-list-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Удалить 1 стикер?'), findsOneWidget);
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();

    expect(api.sent(Opcode.assetsListModify).single, {
      'type': 'FAVORITE_STICKER',
      'ids': [_pinnedA, _pinnedC],
    });
    expect(module.favoriteStickerIds.value, [_pinnedA, _pinnedC]);
    expect(find.text('Избранные стикеры'), findsOneWidget);
    expect(find.byKey(const ValueKey(_pinnedB)), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('back leaves the selection before it leaves the screen', (
    tester,
  ) async {
    await pump(
      tester,
      StickerCollectionScreen(
        collection: StickerCollection.favorites,
        module: module,
      ),
    );

    await tester.longPress(find.byKey(const ValueKey(_pinnedA)));
    await tester.pump();
    expect(find.text('Выбрано: 1'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Избранные стикеры'), findsOneWidget);
    expect(api.sent(Opcode.assetsListModify), isEmpty);
  });

  testWidgets('a catalog set can be added from the sets screen', (
    tester,
  ) async {
    await pump(tester, StickerSetsScreen(module: module));

    expect(find.text('Synthetic set'), findsOneWidget);
    expect(find.text('2 стикера'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('sticker-set-add-$_catalogSet')),
    );
    await tester.pumpAndSettle();

    expect(api.sent(Opcode.assetsAdd).single, {
      'type': 'FAVORITE_STICKER_SET',
      'id': _catalogSet,
    });
    expect(
      find.byKey(const ValueKey('sticker-set-remove-$_catalogSet')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });
}
