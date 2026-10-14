import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/quote_glyph_box.dart';
import 'package:material_symbols_icons/symbols.dart';

const _glyph = 13.6;
const _color = Color(0x8C2266AA);

Widget _reference(Widget child) => Stack(
  children: [
    child,
    const Positioned(
      top: 0,
      right: 0,
      child: Icon(Symbols.format_quote, size: _glyph, fill: 1, color: _color),
    ),
  ],
);

Widget _candidate(Widget child) => QuoteGlyphBox(
  icon: Symbols.format_quote,
  size: _glyph,
  color: _color,
  child: child,
);

class _Scenario {
  const _Scenario(
    this.name, {
    this.iconTheme,
    this.textScale = 1,
    this.direction = TextDirection.ltr,
    this.constraints = const BoxConstraints(maxWidth: 240),
    this.textAlign = TextAlign.start,
    this.text = 'Цитата в две строки, чтобы перенос был виден',
  });

  final String name;
  final IconThemeData? iconTheme;
  final double textScale;
  final TextDirection direction;
  final BoxConstraints constraints;
  final TextAlign textAlign;
  final String text;
}

const _scenarios = [
  _Scenario('default theme'),
  _Scenario(
    'custom icon theme',
    iconTheme: IconThemeData(
      weight: 300,
      grade: -25,
      opticalSize: 20,
      opacity: 0.6,
      shadows: [Shadow(color: Color(0x80000000), blurRadius: 2)],
    ),
  ),
  _Scenario(
    'scaled glyph',
    iconTheme: IconThemeData(applyTextScaling: true),
    textScale: 1.5,
  ),
  _Scenario('right to left', direction: TextDirection.rtl, text: 'שלום עולם'),
  _Scenario(
    'tight width with centred text',
    constraints: BoxConstraints.tightFor(width: 220),
    textAlign: TextAlign.center,
    text: 'Коротко',
  ),
  _Scenario(
    'glyph larger than the box',
    constraints: BoxConstraints(maxWidth: 9),
    text: 'a',
  ),
];

typedef _Snapshot = ({Uint8List pixels, List<Object?> metrics});

Future<_Snapshot> _snapshot(
  WidgetTester tester,
  _Scenario scenario,
  Widget Function(Widget child) wrap,
) async {
  final quote = KeyedSubtree(
    key: const ValueKey('quote'),
    child: wrap(
      Text(
        scenario.text,
        textAlign: scenario.textAlign,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          height: 1.3,
          color: Color(0xFF111111),
        ),
      ),
    ),
  );
  Widget content = Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        '>',
        style: TextStyle(fontFamily: 'Inter', fontSize: 24, color: Colors.red),
      ),
      ConstrainedBox(constraints: scenario.constraints, child: quote),
    ],
  );
  if (scenario.iconTheme != null) {
    content = IconTheme.merge(data: scenario.iconTheme!, child: content);
  }
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scenario.textScale)),
      child: Directionality(
        textDirection: scenario.direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: const ValueKey('shot'),
            child: ColoredBox(color: const Color(0xFFDDE6FF), child: content),
          ),
        ),
      ),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('shot')),
  );
  final box = tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('quote')),
  );
  final pixels = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return bytes!.buffer.asUint8List();
  });
  final loose = BoxConstraints(maxWidth: scenario.constraints.maxWidth);
  return (
    pixels: pixels!,
    metrics: [
      box.size,
      box.getMinIntrinsicWidth(double.infinity),
      box.getMaxIntrinsicWidth(double.infinity),
      box.getMinIntrinsicHeight(scenario.constraints.maxWidth),
      box.getMaxIntrinsicHeight(scenario.constraints.maxWidth),
      box.getDryLayout(loose),
      box.getDryBaseline(loose, TextBaseline.alphabetic),
    ],
  );
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/fonts/Inter.ttf'))).load();
    await (FontLoader(
          'packages/material_symbols_icons/MaterialSymbolsOutlined',
        )..addFont(
          rootBundle.load(
            'packages/material_symbols_icons/lib/fonts/MaterialSymbolsOutlined.ttf',
          ),
        ))
        .load();
  });

  for (final scenario in _scenarios) {
    testWidgets('draws and lays out like Icon in a Stack: ${scenario.name}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(900, 900);
      addTearDown(tester.view.reset);

      final reference = await _snapshot(tester, scenario, _reference);
      final candidate = await _snapshot(tester, scenario, _candidate);

      expect(candidate.metrics, reference.metrics);
      expect(candidate.pixels, reference.pixels);
    });
  }
}
