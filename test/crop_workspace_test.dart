import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:komet/frontend/widgets/attachment/editor_common.dart';
import 'package:komet/l10n/app_localizations.dart';

Future<ui.Image> _solidImage(int width, int height) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366AA),
  );
  return recorder.endRecording().toImage(width, height);
}

void main() {
  group('CropView', () {
    const vp = Size(400, 800);

    test('рамка во весь вьюпорт даёт единичный масштаб', () {
      final crop = Rect.fromCenter(
        center: const Offset(200, 400),
        width: 360,
        height: 720,
      );
      final view = CropView.fit(crop, vp);
      expect(view.scale, closeTo(1, 0.001));
      expect(view.focus, crop.center);
    });

    test('маленькая рамка приближает и центрирует', () {
      final crop = Rect.fromLTWH(40, 80, 90, 180);
      final view = CropView.fit(crop, vp);
      expect(view.scale, closeTo(4, 0.001));
      final display = view.rect(crop, vp);
      expect(display.center.dx, closeTo(200, 0.001));
      expect(display.center.dy, closeTo(400, 0.001));
      expect(display.width, closeTo(360, 0.001));
    });

    test('перевод координат обратим', () {
      final view = CropView.fit(Rect.fromLTWH(40, 80, 90, 180), vp);
      const point = Offset(123, 456);
      final round = view.toLogical(view.toDisplay(point, vp), vp);
      expect(round.dx, closeTo(point.dx, 0.001));
      expect(round.dy, closeTo(point.dy, 0.001));
    });
  });

  testWidgets('после зума жест по рамке двигает её в масштабе', (tester) async {
    final image = await _solidImage(400, 400);
    addTearDown(image.dispose);

    CropState? applied;
    Size? viewport;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CropWorkspace(
          imageSize: const Size(400, 400),
          imageBuilder: (context, matrix) =>
              CustomPaint(painter: MatrixImagePainter(image, matrix)),
          onApply: (state, vp, changed, identity) async {
            applied = state;
            viewport = vp;
            return 'ok';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final area = tester.getRect(find.byType(LayoutBuilder).first);
    final geometry = const CropGeometry(source: Size(400, 400));
    final fitted = geometry.fittedRect(area.size);
    final corner = area.topLeft + fitted.topLeft;

    Future<void> dragCorner(Offset from, Offset delta) async {
      final gesture = await tester.startGesture(from);
      await tester.pump();
      await gesture.moveBy(delta);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await dragCorner(corner, const Offset(40, 40));

    final zoomed = Rect.fromLTRB(
      fitted.left + 40,
      fitted.top + 40,
      fitted.right,
      fitted.bottom,
    );
    final view = CropView.fit(zoomed, area.size);
    expect(view.scale, greaterThan(1));

    await dragCorner(
      area.topLeft + view.rect(zoomed, area.size).topLeft,
      const Offset(40, 40),
    );

    await tester.tap(find.text('ГОТОВО'));
    await tester.pumpAndSettle();
    expect(applied, isNotNull);
    final left = applied!.cropNorm.left * viewport!.width;
    expect(left, closeTo(fitted.left + 40 + 40 / view.scale, 1.5));
    expect(left, lessThan(fitted.left + 80));
  });
}
