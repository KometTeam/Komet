import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/attachment/attachment_sheet.dart';
import 'package:komet/frontend/widgets/attachment/avatar_editor.dart';
import 'package:komet/frontend/widgets/attachment/editor_common.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:material_symbols_icons/symbols.dart';

const _bounds = Rect.fromLTWH(0, 0, 300, 400);
const _square = Rect.fromLTWH(50, 100, 200, 200);

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<File> _syntheticImage() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 64, 48),
    ui.Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(64, 48);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(
    '${Directory.systemTemp.createTempSync('synthetic_avatar').path}/a.png',
  );
  await file.writeAsBytes(png!.buffer.asUint8List());
  return file;
}

void main() {
  group('square crop handles', () {
    test('dragging a corner keeps the crop square', () {
      final grown = moveSquareCropHandle(
        _square,
        2,
        const Offset(30, 10),
        _bounds,
      );
      expect(grown.width, grown.height);
      expect(grown.topLeft, _square.topLeft);
      expect(grown.width, 220);

      final shrunk = moveSquareCropHandle(
        _square,
        0,
        const Offset(20, 40),
        _bounds,
      );
      expect(shrunk.width, shrunk.height);
      expect(shrunk.bottomRight, _square.bottomRight);
      expect(shrunk.width, 170);
    });

    test('a corner never pushes the square out of the image', () {
      final grown = moveSquareCropHandle(
        _square,
        1,
        const Offset(400, -400),
        _bounds,
      );
      expect(grown.width, grown.height);
      expect(_bounds.contains(grown.topLeft), isTrue);
      expect(grown.right, lessThanOrEqualTo(_bounds.right));
      expect(grown.top, greaterThanOrEqualTo(_bounds.top));
    });

    test('the square never collapses below the minimum', () {
      final tiny = moveSquareCropHandle(
        _square,
        3,
        const Offset(500, -500),
        _bounds,
      );
      expect(tiny.width, tiny.height);
      expect(tiny.width, 64);
    });

    test('dragging inside moves the square without resizing', () {
      final moved = moveSquareCropHandle(
        _square,
        8,
        const Offset(10, 20),
        _bounds,
      );
      expect(moved.size, _square.size);
      expect(moved.topLeft, const Offset(60, 120));
    });
  });

  testWidgets('the avatar picker only offers photos and files', (tester) async {
    var filesTapped = false;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAttachmentSheet(
                context,
                onPickPhoto: (_, _) async {},
                onPickFile: () => filesTapped = true,
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

    expect(find.text('Галерея'), findsOneWidget);
    expect(find.text('Файл'), findsOneWidget);
    expect(find.text('Геопозиция'), findsNothing);
    expect(find.text('Опрос'), findsNothing);
    expect(find.text('Контакт'), findsNothing);

    await tester.tap(find.text('Файл'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Выбрать фото из файлов'), findsOneWidget);

    await tester.tap(find.text('Выбрать файл'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(filesTapped, isTrue);
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('the avatar editor offers the round crop actions', (
    tester,
  ) async {
    final source = (await tester.runAsync(_syntheticImage))!;
    addTearDown(() => source.parent.deleteSync(recursive: true));
    await tester.pumpWidget(_app(AvatarEditor(source: source)));
    for (
      var i = 0;
      i < 10 && find.byType(CropWorkspace).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(find.byType(CropWorkspace), findsOneWidget);
    expect(find.text('Отмена'), findsOneWidget);
    expect(find.text('Установить фото'), findsOneWidget);
    expect(find.byIcon(Symbols.flip), findsOneWidget);
    expect(find.byIcon(Symbols.rotate_90_degrees_ccw), findsOneWidget);
    expect(find.byIcon(Symbols.brush), findsOneWidget);
    expect(find.text('СБРОС'), findsNothing);
  });
}
