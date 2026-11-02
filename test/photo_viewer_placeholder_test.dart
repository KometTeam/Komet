import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/attachment/photo_hero.dart';
import 'package:komet/frontend/widgets/photo_viewer.dart';
import 'package:komet/frontend/widgets/small_spinner.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/models/attachment.dart';

Finder _insideViewer(bool Function(Widget widget) test) => find
    .byElementPredicate(
      (element) =>
          test(element.widget) &&
          element.findAncestorWidgetOfExactType<PhotoViewerScreen>() != null,
    );

Finder get _preview =>
    _insideViewer((w) => w is Image && w.image is RawImageProvider);

Finder get _full => _insideViewer((w) => w is Image && w.image is FileImage);

double _spinnerOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byType(SmallSpinner),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

Future<File> _photoFile(WidgetTester tester) async {
  final file = (await tester.runAsync(() async {
    final directory = await Directory.systemTemp.createTemp('viewer_photo');
    final image = await createTestImage(width: 40, height: 20);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${directory.path}/photo.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    return file;
  }))!;
  addTearDown(() => file.parent.deleteSync(recursive: true));
  return file;
}

Future<void> _open(WidgetTester tester, PhotoAttachment photo) async {
  final image = (await tester.runAsync(
    () => createTestImage(width: 40, height: 20),
  ))!;
  addTearDown(image.dispose);
  final hero = PhotoHeroController(
    origin: () => const Rect.fromLTWH(20, 60, 80, 40),
    image: RawImageProvider(image),
  );
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            PhotoHeroRoute<void>(
              hero: hero,
              builder: (_) => PhotoViewerScreen(photos: [photo], hero: hero),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('keeps the opened photo on screen while the full one loads', (
    tester,
  ) async {
    await _open(
      tester,
      const PhotoAttachment(baseUrl: 'https://example.test/full.jpg'),
    );

    expect(_preview, findsOneWidget);
    expect(tester.getRect(_preview).width, greaterThan(0));
    expect(_spinnerOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_preview, findsOneWidget);
    expect(_spinnerOpacity(tester), 1);
  });

  testWidgets('swaps the preview for the full photo once it is decoded', (
    tester,
  ) async {
    final file = await _photoFile(tester);
    await _open(tester, PhotoAttachment(localPath: file.path));

    for (var i = 0; i < 20 && _full.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    for (var i = 0; i < 20 && _preview.evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(_full, findsOneWidget);
    expect(_preview, findsNothing);
    expect(find.byType(SmallSpinner), findsNothing);
  });
}
