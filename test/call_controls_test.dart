import 'dart:async';
import 'dart:math' show pow;

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

double _amplitude(double db) => pow(10, db / 20).toDouble();

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

  Widget micButton(Stream<double> levels, {required bool slashed}) =>
      MaterialApp(
        home: Center(
          child: CallButton(
            icon: Icons.mic,
            slashedIcon: Icons.mic_off,
            slashed: slashed,
            label: 'Микрофон',
            background: Colors.grey,
            foreground: Colors.white,
            onTap: () {},
            micLevels: levels,
          ),
        ),
      );

  testWidgets('кнопка микрофона наливается водой по громкости', (tester) async {
    final levels = StreamController<double>.broadcast();
    addTearDown(levels.close);
    await tester.pumpWidget(micButton(levels.stream, slashed: false));
    final water = find.byType(MicWaterFill);
    expect(tester.renderObject(water), paintsNothing);

    levels.add(_amplitude(-55));
    await tester.pump();
    levels.add(_amplitude(-14));
    await tester.pump();
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      tester.renderObject(water),
      paints
        ..path()
        ..path(),
    );

    levels.add(0);
    await tester.pumpAndSettle();
    expect(tester.renderObject(water), paintsNothing);
  });

  testWidgets('при выключенном микрофоне вода стекает и опрос уровня стоит', (
    tester,
  ) async {
    final levels = StreamController<double>.broadcast();
    addTearDown(levels.close);
    await tester.pumpWidget(micButton(levels.stream, slashed: false));
    expect(levels.hasListener, isTrue);
    levels.add(_amplitude(-55));
    await tester.pump();
    levels.add(_amplitude(-14));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(micButton(levels.stream, slashed: true));
    expect(levels.hasListener, isFalse);
    await tester.pumpAndSettle();
    expect(tester.renderObject(find.byType(MicWaterFill)), paintsNothing);
    expect(find.byIcon(Icons.mic_off), findsOneWidget);
  });

  testWidgets('в фоне и под другим экраном уровень микрофона не опрашивается', (
    tester,
  ) async {
    final levels = StreamController<double>.broadcast();
    addTearDown(levels.close);
    await tester.pumpWidget(micButton(levels.stream, slashed: false));
    expect(levels.hasListener, isTrue);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(levels.hasListener, isFalse);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    expect(levels.hasListener, isTrue);

    await tester.pumpWidget(
      TickerMode(
        enabled: false,
        child: micButton(levels.stream, slashed: false),
      ),
    );
    expect(levels.hasListener, isFalse);
  });

  group('MicVoiceMeter', () {
    test('ровный фон не наливает воду', () {
      final meter = MicVoiceMeter();
      for (var i = 0; i < 40; i++) {
        final db = -45 + (i.isEven ? 4.0 : -4.0);
        expect(meter.fill(_amplitude(db), 0.1), 0, reason: 'сэмпл $i');
      }
    });

    test('голос поверх фона наливает, тихий звук меньше громкого', () {
      final meter = MicVoiceMeter();
      for (var i = 0; i < 20; i++) {
        meter.fill(_amplitude(-50), 0.1);
      }
      final quiet = meter.fill(_amplitude(-28), 0.1);
      final loud = meter.fill(_amplitude(-14), 0.1);
      expect(quiet, greaterThan(0));
      expect(loud, greaterThan(0.5));
      expect(loud, greaterThan(quiet));
    });

    test('новый постоянный шум перестаёт наливать через несколько секунд', () {
      final meter = MicVoiceMeter();
      for (var i = 0; i < 20; i++) {
        meter.fill(_amplitude(-55), 0.1);
      }
      var fill = 1.0;
      for (var i = 0; i < 80; i++) {
        fill = meter.fill(_amplitude(-32), 0.1);
      }
      expect(fill, 0);
    });

    test('тишина без данных не сбивает подстроенный фон', () {
      final meter = MicVoiceMeter();
      for (var i = 0; i < 20; i++) {
        meter.fill(_amplitude(-40), 0.1);
      }
      expect(meter.fill(0, 0.1), 0);
      expect(meter.fill(_amplitude(-38), 0.1), 0);
    });
  });
}
