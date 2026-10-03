import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/calls/call_controls.dart';

const _labels = ['Динамик', 'Видео', 'Экран', 'Выкл. звук', 'Завершить'];

Widget _controls({required double textScale}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(320, 640),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: CallControlBar(
          children: [
            for (final label in _labels)
              CallButton(
                key: ValueKey(label),
                icon: Icons.call_end,
                label: label,
                background: Colors.red,
                foreground: Colors.white,
                onTap: () {},
              ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _pumpNarrow(WidgetTester tester, double textScale) async {
  tester.view.physicalSize = const Size(960, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_controls(textScale: textScale));
}

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets('все кнопки звонка влезают в 320dp при шрифте ×$scale', (
      tester,
    ) async {
      await _pumpNarrow(tester, scale);

      expect(tester.takeException(), isNull);
      for (final label in _labels) {
        final rect = tester.getRect(find.byKey(ValueKey(label)));
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(320), reason: label);
      }
    });
  }

  testWidgets('кнопка вне панели сохраняет полный размер', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in ['Отклонить', 'Принять'])
                CallButton(
                  key: ValueKey(label),
                  icon: Icons.call,
                  label: label,
                  background: Colors.green,
                  foreground: Colors.white,
                  onTap: () {},
                ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final circle = find.descendant(
      of: find.byKey(const ValueKey('Принять')),
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == CallButton.maxDiameter,
      ),
    );
    expect(circle, findsOneWidget);
  });

  testWidgets('кнопка «Завершить» нажимается на узком экране', (tester) async {
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var hungUp = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: CallControlBar(
              children: [
                for (final label in _labels.take(4))
                  CallButton(
                    icon: Icons.mic,
                    label: label,
                    background: Colors.grey,
                    foreground: Colors.white,
                    onTap: () {},
                  ),
                CallButton(
                  icon: Icons.call_end,
                  label: 'Завершить',
                  background: Colors.red,
                  foreground: Colors.white,
                  onTap: () => hungUp = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.call_end));
    expect(hungUp, isTrue);
  });
}
