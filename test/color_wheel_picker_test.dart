import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:komet/frontend/widgets/color_wheel_picker.dart';

const double _pickerWidth = 320;
const double _wheelSize = 260;
const double _rowInset = (_pickerWidth - _wheelSize - 44) / 2;

class _Harness {
  final ScrollController scroll = ScrollController();
  final List<Color> emitted = [];

  Widget build({double minBrightness = 0}) {
    return MaterialApp(
      home: Scaffold(
        body: ListView(
          controller: scroll,
          children: [
            const SizedBox(height: 40),
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: _pickerWidth,
                child: ColorWheelPicker(
                  color: const Color(0xFF4F8EFF),
                  minBrightness: minBrightness,
                  onChanged: emitted.add,
                ),
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
  }
}

Offset _barPoint(WidgetTester tester, double fraction) {
  final origin = tester.getTopLeft(find.byType(ColorWheelPicker));
  return origin +
      Offset(_rowInset + _wheelSize + 16 + 14, fraction * _wheelSize);
}

Offset _wheelPoint(WidgetTester tester, Offset local) {
  final origin = tester.getTopLeft(find.byType(ColorWheelPicker));
  return origin + Offset(_rowInset, 0) + local;
}

void main() {
  testWidgets('шкала яркости ведётся пальцем и не прокручивает экран', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.scroll.dispose);
    await tester.pumpWidget(harness.build());

    final gesture = await tester.startGesture(_barPoint(tester, 0.1));
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 15));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(harness.scroll.offset, 0);
    expect(harness.emitted.length, greaterThanOrEqualTo(13));
    final values = [
      for (final color in harness.emitted) HSVColor.fromColor(color).value,
    ];
    for (var i = 1; i < values.length; i++) {
      expect(values[i], lessThan(values[i - 1]), reason: '$values');
    }
  });

  testWidgets('нижний край шкалы упирается в minBrightness', (tester) async {
    final harness = _Harness();
    addTearDown(harness.scroll.dispose);
    await tester.pumpWidget(harness.build(minBrightness: 0.2));

    final gesture = await tester.startGesture(_barPoint(tester, 0.5));
    await gesture.moveBy(const Offset(0, _wheelSize));
    await gesture.up();
    await tester.pumpAndSettle();

    final value = HSVColor.fromColor(harness.emitted.last).value;
    expect(value, closeTo(0.2, 0.01));
    expect(HSVColor.fromColor(harness.emitted.last).saturation, greaterThan(0));
  });

  testWidgets('вертикальный жест по кругу меняет цвет, а не скроллит', (
    tester,
  ) async {
    final harness = _Harness();
    addTearDown(harness.scroll.dispose);
    await tester.pumpWidget(harness.build());

    final gesture = await tester.startGesture(
      _wheelPoint(tester, const Offset(_wheelSize / 2 + 40, 30)),
    );
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(harness.scroll.offset, 0);
    expect(harness.emitted.length, greaterThanOrEqualTo(9));
    expect(
      harness.emitted.map((c) => HSVColor.fromColor(c).hue).toSet().length,
      greaterThan(5),
    );
  });
}
