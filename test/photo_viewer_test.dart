import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/modules/messages.dart';
import 'package:komet/frontend/widgets/attachment/photo_hero.dart';
import 'package:komet/frontend/widgets/photo_viewer.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';
import 'package:material_symbols_icons/symbols.dart';

CachedMessage _message({String? text}) => CachedMessage(
  id: '77',
  accountId: 1,
  chatId: 2,
  senderId: 5,
  text: text,
  time: DateTime.now().millisecondsSinceEpoch,
  status: 'sent',
  attachments: const [],
);

Future<void> _pumpViewer(
  WidgetTester tester, {
  CachedMessage? message,
  PhotoViewerActions? actions,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PhotoViewerScreen(
        photos: const [
          PhotoAttachment(baseUrl: 'https://example.com/a.jpg'),
          PhotoAttachment(baseUrl: 'https://example.com/b.jpg'),
        ],
        message: message,
        actions: actions,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pushViewer(
  WidgetTester tester, {
  PhotoHeroController? hero,
}) async {
  Widget viewer(BuildContext context) => PhotoViewerScreen(
    photos: const [
      PhotoAttachment(baseUrl: 'https://example.test/first.jpg'),
      PhotoAttachment(baseUrl: 'https://example.test/second.jpg'),
    ],
    hero: hero,
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.green,
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              hero == null
                  ? PhotoViewerRoute<void>(builder: viewer)
                  : PhotoHeroRoute<void>(hero: hero, builder: viewer),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Offset _dismissOffset(WidgetTester tester) {
  final transform = tester.widget<Transform>(
    find.byKey(const ValueKey('media-dismiss-transform')),
  );
  return Offset(transform.transform[12], transform.transform[13]);
}

void main() {
  testWidgets('drag dismissal flies back from the dragged photo position', (
    tester,
  ) async {
    final image = (await tester.runAsync(
      () => createTestImage(width: 20, height: 10),
    ))!;
    addTearDown(image.dispose);
    final hero = PhotoHeroController(
      origin: () => const Rect.fromLTWH(20, 60, 80, 80),
      image: RawImageProvider(image),
    );
    await _pushViewer(tester, hero: hero);
    final gesture = await tester.startGesture(const Offset(400, 260));
    await gesture.moveBy(
      const Offset(0, 140),
      timeStamp: const Duration(milliseconds: 400),
    );
    await tester.pump();
    final draggedPhoto = inscribeRect(const Size(20, 10), hero.areaRect!);
    await gesture.up(timeStamp: const Duration(milliseconds: 500));
    await tester.pump();

    final flight = find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is RawImageProvider,
    );
    expect(flight, findsOneWidget);
    expect(tester.getRect(flight).top, closeTo(draggedPhoto.top, 1));
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.byType(PhotoViewerScreen), findsNothing);
  });

  testWidgets(
    'vertical drag follows the finger, fades the background and closes',
    (tester) async {
      await _pushViewer(tester);
      final gesture = await tester.startGesture(const Offset(400, 260));
      await gesture.moveBy(
        const Offset(12, 140),
        timeStamp: const Duration(milliseconds: 400),
      );
      await tester.pump();

      expect(_dismissOffset(tester).dy, 140);
      final backdrop = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('media-dismiss-backdrop')),
      );
      expect(backdrop.color.a, lessThan(1));

      await gesture.up(timeStamp: const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PhotoViewerScreen), findsNothing);
    },
  );

  testWidgets('short slow drag and cancelled drag restore the photo', (
    tester,
  ) async {
    await _pushViewer(tester);
    var gesture = await tester.startGesture(const Offset(400, 260));
    await gesture.moveBy(
      const Offset(0, 50),
      timeStamp: const Duration(milliseconds: 400),
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_dismissOffset(tester), Offset.zero);
    expect(find.byType(PhotoViewerScreen), findsOneWidget);

    gesture = await tester.startGesture(const Offset(400, 260));
    await gesture.moveBy(
      const Offset(0, -150),
      timeStamp: const Duration(milliseconds: 400),
    );
    await tester.pump();
    expect(_dismissOffset(tester).dy, -150);
    await gesture.cancel();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_dismissOffset(tester), Offset.zero);
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
  });

  testWidgets('a short fast vertical fling dismisses the photo', (
    tester,
  ) async {
    await _pushViewer(tester);
    await tester.flingFrom(const Offset(400, 260), const Offset(0, -70), 1500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PhotoViewerScreen), findsNothing);
  });

  testWidgets('horizontal swipe changes photos without dismissing', (
    tester,
  ) async {
    await _pushViewer(tester);
    await tester.timedDragFrom(
      const Offset(650, 260),
      const Offset(-500, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(_dismissOffset(tester), Offset.zero);
    expect(find.byIcon(Symbols.chevron_left), findsOneWidget);
    expect(find.byIcon(Symbols.chevron_right), findsNothing);
  });

  testWidgets('zoomed photos pan vertically without dismissing', (
    tester,
  ) async {
    await _pushViewer(tester);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer).first,
    );
    viewer.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    await tester.dragFrom(const Offset(400, 260), const Offset(0, 160));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(_dismissOffset(tester), Offset.zero);
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
  });

  testWidgets('a second finger cancels dismissal and preserves pinch zoom', (
    tester,
  ) async {
    await _pushViewer(tester);
    final first = await tester.startGesture(const Offset(340, 260), pointer: 1);
    await first.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(_dismissOffset(tester).dy, 40);
    final second = await tester.startGesture(
      const Offset(460, 300),
      pointer: 2,
    );
    await first.moveTo(const Offset(280, 300));
    await second.moveTo(const Offset(520, 300));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(_dismissOffset(tester), Offset.zero);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer).first,
    );
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
  });

  testWidgets('shows who sent the photo and when', (tester) async {
    await _pumpViewer(tester, message: _message());

    expect(find.textContaining('сегодня в'), findsOneWidget);
  });

  testWidgets('rotate button turns the photo counter-clockwise, as its icon', (
    tester,
  ) async {
    await _pumpViewer(tester, message: _message());

    expect(
      tester.widget<RotatedBox>(find.byType(RotatedBox).first).quarterTurns,
      0,
    );

    await tester.tap(find.byIcon(Symbols.rotate_90_degrees_ccw));
    await tester.pump();

    expect(
      tester.widget<RotatedBox>(find.byType(RotatedBox).first).quarterTurns,
      3,
    );
  });

  testWidgets('shows the photo caption when there is one', (tester) async {
    await _pumpViewer(tester, message: _message(text: 'Делу время'));

    expect(find.text('Делу время'), findsOneWidget);
  });

  testWidgets('arrows step between photos', (tester) async {
    await _pumpViewer(tester, message: _message());

    expect(find.byIcon(Symbols.chevron_left), findsNothing);
    expect(find.byIcon(Symbols.chevron_right), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.chevron_right));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Symbols.chevron_left), findsOneWidget);
    expect(find.byIcon(Symbols.chevron_right), findsNothing);

    await tester.tap(find.byIcon(Symbols.chevron_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Symbols.chevron_right), findsOneWidget);
  });

  testWidgets('arrow keys step between photos', (tester) async {
    await _pumpViewer(tester, message: _message());

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Symbols.chevron_left), findsOneWidget);
    expect(find.byIcon(Symbols.chevron_right), findsNothing);
  });

  testWidgets('single tap hides the chrome, another tap brings it back', (
    tester,
  ) async {
    await _pumpViewer(tester, message: _message());

    double chromeOpacity() =>
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

    expect(chromeOpacity(), 1);

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();
    expect(chromeOpacity(), 0);

    await tester.tapAt(tester.getCenter(find.byType(PageView)));
    await tester.pump();
    expect(chromeOpacity(), 1);
  });

  testWidgets('three-dot menu appears only with actions', (tester) async {
    await _pumpViewer(tester, message: _message());
    expect(find.byIcon(Symbols.more_vert), findsNothing);

    await _pumpViewer(
      tester,
      message: _message(),
      actions: PhotoViewerActions(goToMessage: (_, _) {}, delete: (_, _) {}),
    );
    expect(find.byIcon(Symbols.more_vert), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Перейти к сообщению'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);
    expect(find.text('Сохранить как…'), findsOneWidget);
    expect(find.text('Переслать'), findsNothing);
  });

  testWidgets('menu action closes the viewer before running', (tester) async {
    var ran = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PhotoViewerScreen(
                      photos: const [
                        PhotoAttachment(baseUrl: 'https://example.com/a.jpg'),
                      ],
                      message: _message(),
                      actions: PhotoViewerActions(
                        goToMessage: (_, _) => ran = true,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PhotoViewerScreen), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Перейти к сообщению'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(ran, isTrue);
    expect(find.byType(PhotoViewerScreen), findsNothing);
  });
}
