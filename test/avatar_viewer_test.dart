import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/api.dart';
import 'package:komet/frontend/widgets/avatar_gallery.dart';
import 'package:komet/frontend/widgets/photo_viewer.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';

String _url(int i) => 'https://example.test/avatar/$i';

class _HistoryApi extends Api {
  int count = 0;
  final List<int> requested = [];

  @override
  Future<Map<dynamic, dynamic>?> sendRequestMap(
    int opcode,
    Map<dynamic, dynamic> payload, {
    bool silent = false,
  }) async {
    final from = payload['from'] as int;
    final end = math.min(from + (payload['count'] as int), count);
    requested.add(from);
    return {
      'total': count,
      'urls': [for (var i = from; i < end; i++) _url(i)],
      'ids': [for (var i = from; i < end; i++) 1000 + i],
    };
  }
}

final _ru = lookupAppLocalizations(const Locale('ru'));

void main() {
  late _HistoryApi history;
  setUpAll(() => history = _HistoryApi());
  setUp(() => history.requested.clear());

  _HistoryApi withHistory(int count) => history..count = count;

  group('avatar feed', () {
    test('the main photo already in history is not repeated', () async {
      final feed = AvatarFeed(
        const AvatarGallery(
          contactId: 601,
          name: 'Synthetic',
          currentUrl: 'https://example.test/main-link',
          mainPhotoId: 1000,
          initialPhotoId: 1002,
        ),
        client: withHistory(3),
      );
      await feed.load();

      expect(feed.photos.map((p) => p.id), [1000, 1001, 1002]);
      expect(feed.total, 3);
      expect(feed.initialIndex, 2);
      expect(feed.reachedEnd, isTrue);
    });

    test('a main photo missing from history leads the list', () async {
      final feed = AvatarFeed(
        const AvatarGallery(
          contactId: 602,
          name: 'Synthetic',
          currentUrl: 'https://example.test/fresh',
          mainPhotoId: 77,
        ),
        client: withHistory(2),
      );
      await feed.load();

      expect(feed.photos.first.url, 'https://example.test/fresh');
      expect(feed.photos.length, 3);
      expect(feed.total, 3);
      expect(feed.initialIndex, 0);
    });

    test('history is paged until the server runs out', () async {
      final api = withHistory(AvatarFeed.pageSize + 10);
      final feed = AvatarFeed(
        AvatarGallery(
          contactId: 603,
          name: 'Synthetic',
          currentUrl: _url(0),
          mainPhotoId: 1000,
        ),
        client: api,
      );
      await feed.load();
      expect(feed.photos.length, AvatarFeed.pageSize);
      expect(feed.reachedEnd, isFalse);

      await feed.loadMore();
      expect(feed.photos.length, AvatarFeed.pageSize + 10);
      expect(feed.reachedEnd, isTrue);
      expect(api.requested, [0, AvatarFeed.pageSize]);
    });

    test('a chat without a contact has only its current photo', () async {
      final api = withHistory(5);
      final feed = AvatarFeed(
        const AvatarGallery(
          contactId: 0,
          name: 'Synthetic group',
          currentUrl: 'https://example.test/group',
        ),
        client: api,
      );
      await feed.load();

      expect(feed.photos.length, 1);
      expect(feed.reachedEnd, isTrue);
      expect(api.requested, isEmpty);
    });
  });

  Future<void> openViewer(WidgetTester tester, AvatarFeed feed) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PhotoViewerScreen.avatars(avatars: feed),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('avatars open in the media viewer, older ones to the right', (
    tester,
  ) async {
    await openViewer(
      tester,
      AvatarFeed(
        AvatarGallery(
          contactId: 701,
          name: 'Synthetic Name',
          currentUrl: _url(0),
          mainPhotoId: 1000,
        ),
        client: withHistory(3),
      ),
    );

    expect(find.text(_ru.mediaViewerCounter(1, 3)), findsOneWidget);
    expect(find.text('Synthetic Name'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.byIcon(Symbols.chevron_left), findsNothing);
    expect(find.byIcon(Symbols.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(_ru.mediaViewerCounter(2, 3)), findsOneWidget);
    expect(find.byIcon(Symbols.chevron_left), findsOneWidget);
  });

  testWidgets(
    'deleting an avatar confirms, closes the viewer, reports the id',
    (tester) async {
      final deleted = <int>[];
      await openViewer(
        tester,
        AvatarFeed(
          AvatarGallery(
            contactId: 702,
            name: 'Synthetic Name',
            currentUrl: _url(0),
            mainPhotoId: 1000,
            initialPhotoId: 1001,
            onDelete: deleted.add,
          ),
          client: withHistory(3),
        ),
      );
      expect(find.text(_ru.mediaViewerCounter(2, 3)), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.more_vert));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(_ru.msgActionsDelete).last);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      await tester.tap(find.widgetWithText(FilledButton, _ru.msgActionsDelete));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(deleted, [1001]);
      expect(find.byType(PhotoViewerScreen), findsNothing);
    },
  );

  testWidgets('someone else\'s avatars offer no delete', (tester) async {
    await openViewer(
      tester,
      AvatarFeed(
        AvatarGallery(
          contactId: 703,
          name: 'Synthetic Name',
          currentUrl: _url(0),
          mainPhotoId: 1000,
        ),
        client: withHistory(2),
      ),
    );

    await tester.tap(find.byIcon(Symbols.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(_ru.photoViewerSaveAs), findsOneWidget);
    expect(find.text(_ru.msgActionsDelete), findsNothing);
  });
}
