import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:komet/core/config/app_spectrum_background.dart';
import 'package:komet/frontend/widgets/komet_avatar.dart';
import 'package:komet/frontend/widgets/spectrum_background.dart';

class _CountingCanvas implements Canvas {
  final List<Rect> rects = <Rect>[];
  final List<Color> colors = <Color>[];

  @override
  void drawRect(Rect rect, Paint paint) {
    rects.add(rect);
    colors.add(paint.color);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const Size _viewport = Size(800, 600);

Widget _host({Widget? overlay, required Brightness brightness, Color? seed}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed ?? const Color(0xFF6750A4),
        brightness: brightness,
      ),
    ),
    home: Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: SpectrumBackground()),
          ?overlay,
        ],
      ),
    ),
  );
}

_CountingCanvas _paintOnce(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(SpectrumBackground),
      matching: find.byType(CustomPaint),
    ),
  );
  final canvas = _CountingCanvas();
  paint.painter!.paint(canvas, _viewport);
  return canvas;
}

Future<ByteData> _renderedPixels(WidgetTester tester) async {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(SpectrumBackground),
      matching: find.byType(CustomPaint),
    ),
  );
  final recorder = ui.PictureRecorder();
  paint.painter!.paint(Canvas(recorder), _viewport);
  final picture = recorder.endRecording();

  ByteData? data;
  await tester.runAsync(() async {
    final image = await picture.toImage(
      _viewport.width.round(),
      _viewport.height.round(),
    );
    data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
  });
  return data!;
}

double _averageRed(ByteData pixels, int row, int fromX, int toX) {
  var total = 0.0;
  var counted = 0;
  for (var x = fromX; x < toX; x++) {
    final offset = (row * _viewport.width.round() + x) * 4;
    if (pixels.getUint8(offset + 3) == 0) continue;
    total += pixels.getUint8(offset);
    counted++;
  }
  return counted == 0 ? 0 : total / counted;
}

Future<void> _settleBars(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppSpectrumBackground.prefKey: true,
    });
    await AppSpectrumBackground.load();
  });

  testWidgets('bars grow from the bottom and stay inside the lower zone', (
    tester,
  ) async {
    await tester.pumpWidget(_host(brightness: Brightness.dark));
    await _settleBars(tester);

    final canvas = _paintOnce(tester);
    expect(canvas.rects, isNotEmpty);

    final zoneTop = _viewport.height * (1 - SpectrumTuning.heightFraction);
    for (final rect in canvas.rects) {
      expect(rect.bottom, _viewport.height);
      expect(rect.top, greaterThanOrEqualTo(zoneTop - 0.01));
      expect(rect.width, SpectrumTuning.barWidth);
    }

    final heights = canvas.rects.map((r) => r.height).toSet();
    expect(heights.length, greaterThan(1));
  });

  testWidgets('bar color is a neutral lift of the surface, not the accent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(brightness: Brightness.dark, seed: const Color(0xFFFF4FA3)),
    );
    await _settleBars(tester);

    final context = tester.element(find.byType(SpectrumBackground));
    final cs = Theme.of(context).colorScheme;
    final bar = _paintOnce(tester).colors.first;

    expect(bar.computeLuminance(), greaterThan(cs.surface.computeLuminance()));
    expect(
      bar.computeLuminance(),
      lessThan(cs.surfaceContainerHighest.computeLuminance()),
    );

    final barHsl = HSLColor.fromColor(bar);
    final surfaceHsl = HSLColor.fromColor(cs.surface);
    expect(barHsl.saturation, lessThanOrEqualTo(surfaceHsl.saturation + 0.01));
    expect((barHsl.hue - surfaceHsl.hue).abs(), lessThan(1));
    expect(barHsl.lightness, greaterThan(surfaceHsl.lightness));
  });

  testWidgets('bar count scales to thin lines across the width', (
    tester,
  ) async {
    await tester.pumpWidget(_host(brightness: Brightness.dark));
    await _settleBars(tester);

    final expected =
        (_viewport.width + SpectrumTuning.barGap) /
        (SpectrumTuning.barWidth + SpectrumTuning.barGap);
    expect(expected, greaterThan(400));
    expect(_paintOnce(tester).rects.length, greaterThan(200));
  });

  testWidgets('a nearby avatar tints the bars closest to it', (tester) async {
    await tester.pumpWidget(
      _host(
        brightness: Brightness.dark,
        overlay: const Align(
          alignment: Alignment.bottomLeft,
          child: KometAvatar(
            name: 'Nova',
            size: 48,
            backgroundColor: Color(0xFFFF0000),
            fadeIn: false,
          ),
        ),
      ),
    );
    await _settleBars(tester);

    final pixels = await _renderedPixels(tester);
    final row = _viewport.height.round() - 2;
    final nearAvatar = _averageRed(pixels, row, 0, 200);
    final farSide = _averageRed(pixels, row, 600, 800);

    expect(nearAvatar, greaterThan(farSide));
  });

  testWidgets('no tint sources leave every bar on the base color', (
    tester,
  ) async {
    await tester.pumpWidget(_host(brightness: Brightness.dark));
    await _settleBars(tester);

    expect(_paintOnce(tester).colors.toSet().length, 1);
  });
}
