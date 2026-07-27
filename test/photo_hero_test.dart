import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/attachment/photo_hero.dart';

const Rect _origin = Rect.fromLTWH(50, 500, 100, 100);

class _TestImageProvider extends ImageProvider<_TestImageProvider> {
  _TestImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_TestImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_TestImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _TestImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
  );
}

Widget _page() => Scaffold(
  body: Column(
    children: [
      Expanded(
        child: PhotoHeroTarget(
          child: Center(
            child: Container(key: const ValueKey('target'), color: Colors.red),
          ),
        ),
      ),
      const SizedBox(height: 100),
    ],
  ),
);

Finder get _flying => find.byType(Image);

double _flyingWidth(WidgetTester tester) => tester.getSize(_flying).width;

bool _targetHidden(WidgetTester tester) => tester.any(
  find.ancestor(
    of: find.byKey(const ValueKey('target')),
    matching: find.byType(Opacity),
  ),
);

double _pageOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('target')),
            matching: find.byType(FadeTransition),
          )
          .first,
    )
    .opacity
    .value;

void main() {
  late ui.Image image;

  setUpAll(() async {
    image = await createTestImage(width: 4, height: 3);
  });

  testWidgets('photo flies from the origin rect to the contained target', (
    tester,
  ) async {
    final hero = PhotoHeroController(
      origin: () => _origin,
      image: _TestImageProvider(image),
    );
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const Scaffold();
          },
        ),
      ),
    );

    Navigator.of(
      context,
    ).push(PhotoHeroRoute<void>(hero: hero, builder: (_) => _page()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(_flying, findsOneWidget);
    expect(_targetHidden(tester), isTrue);
    final early = _flyingWidth(tester);
    expect(early, greaterThanOrEqualTo(133));

    await tester.pump(const Duration(milliseconds: 150));
    final late_ = _flyingWidth(tester);
    expect(late_, greaterThan(early));
    expect(late_, lessThan(667));

    await tester.pumpAndSettle();
    expect(_flying, findsNothing);
    expect(_targetHidden(tester), isFalse);
    expect(tester.getSize(find.byKey(const ValueKey('target'))).height, 500);
  });

  testWidgets('photo flies back to the origin rect on pop', (tester) async {
    final hero = PhotoHeroController(
      origin: () => _origin,
      image: _TestImageProvider(image),
    );
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const Scaffold();
          },
        ),
      ),
    );

    final navigator = Navigator.of(context);
    navigator.push(PhotoHeroRoute<void>(hero: hero, builder: (_) => _page()));
    await tester.pumpAndSettle();

    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_flying, findsOneWidget);
    expect(_targetHidden(tester), isTrue);
    expect(_flyingWidth(tester), lessThan(667));

    await tester.pumpAndSettle();
    expect(_flying, findsNothing);
  });

  testWidgets('disabled hero fades the page instead of flying', (tester) async {
    final hero = PhotoHeroController(
      origin: () => _origin,
      image: _TestImageProvider(image),
    )..enabled = false;
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) {
            context = ctx;
            return const Scaffold();
          },
        ),
      ),
    );

    Navigator.of(
      context,
    ).push(PhotoHeroRoute<void>(hero: hero, builder: (_) => _page()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(_flying, findsNothing);
    expect(_targetHidden(tester), isFalse);
    expect(_pageOpacity(tester), lessThan(1));

    await tester.pumpAndSettle();
    expect(_pageOpacity(tester), 1);
  });

  testWidgets('target renders untouched without a hero scope', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _page()));
    await tester.pumpAndSettle();

    expect(find.byType(Opacity), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('target'))).height, 500);
  });
}
