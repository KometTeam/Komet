import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:komet/frontend/widgets/glossy_pill.dart';
import 'package:komet/frontend/widgets/liquid_glass.dart';

final _errors = <String>[];

Widget _host(Widget child) => MaterialApp(
  home: Theme(
    data: ThemeData(brightness: Brightness.dark),
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: child),
    ),
  ),
);

Future<void> _pumpPill(
  WidgetTester tester,
  Widget pill, {
  int settles = 3,
}) async {
  await tester.pumpWidget(_host(pill));
  for (var i = 0; i < settles; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUp(() {
    LiquidGlass.supportedOverride = true;
    LiquidGlass.supportedOverride = true;
    FlutterError.onError = (details) {
      final message = details.exception.toString();
      _errors.add('$message\n${details.stack}');
    };
  });

  tearDown(() {
    LiquidGlass.supportedOverride = null;
    expect(_errors, isEmpty, reason: 'liquid pill must render without errors');
  });

  testWidgets('wide liquid pill builds glass and keeps content visible', (
    tester,
  ) async {
    final key = GlobalKey();
    await _pumpPill(
      tester,
      SizedBox(
        width: 240,
        height: 56,
        child: GlossyPill(
          key: key,
          liquid: true,
          onTap: () {},
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Text('Имя получателя', textDirection: TextDirection.ltr),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Имя получателя'), findsOneWidget);
    expect(find.byType(GlassContainer), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    _errors.clear();
  });

  testWidgets('square liquid pill survives press spring', (tester) async {
    await _pumpPill(
      tester,
      SizedBox(
        width: 56,
        height: 56,
        child: GlossyPill(
          liquid: true,
          onTap: () {},
          child: const Icon(Icons.add),
        ),
      ),
    );
    final glassBefore = tester.getSize(find.byType(GlassContainer));

    final center = tester.getCenter(find.byType(Icon));
    final gesture = await tester.startGesture(center);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.moveBy(const Offset(2, 0));
    }
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(tester.takeException(), isNull);
    final glassAfter = tester.getSize(find.byType(GlassContainer));
    expect(glassAfter.width, closeTo(glassBefore.width, 0.5));
    _errors.clear();
  });

  testWidgets('drag beyond pill sways and returns after release', (
    tester,
  ) async {
    await _pumpPill(
      tester,
      SizedBox(
        width: 160,
        height: 48,
        child: GlossyPill(
          liquid: true,
          onTap: () {},
          child: const Text('Q', textDirection: TextDirection.ltr),
        ),
      ),
    );
    final restCenter = tester.getCenter(find.text('Q'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GlassContainer)),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(6, 1));
      await tester.pump(const Duration(milliseconds: 32));
    }
    final swayCenter = tester.getCenter(find.text('Q'));
    expect(
      swayCenter.dx,
      greaterThan(restCenter.dx),
      reason: 'стекло сдвигается за пальцем',
    );

    await gesture.up();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    final backCenter = tester.getCenter(find.text('Q'));
    expect(
      (backCenter - restCenter).distance,
      lessThan(0.5),
      reason: 'после отпускания объект возвращается на место',
    );
    _errors.clear();
  });

  testWidgets('stopped finger springs back while still pressed', (
    tester,
  ) async {
    await _pumpPill(
      tester,
      SizedBox(
        width: 160,
        height: 48,
        child: GlossyPill(
          liquid: true,
          onTap: () {},
          child: const Text('Q', textDirection: TextDirection.ltr),
        ),
      ),
    );
    final restCenter = tester.getCenter(find.text('Q'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GlassContainer)),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(5, 0));
      await tester.pump(const Duration(milliseconds: 32));
    }
    // палец стоит на месте — отскок без подъёма
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 400));
    final settledCenter = tester.getCenter(find.text('Q'));
    expect(
      (settledCenter - restCenter).distance,
      lessThan(0.5),
      reason: 'остановленный палец возвращает объект без отпускания',
    );
    await gesture.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(tester.takeException(), isNull);
    _errors.clear();
  });

  testWidgets('pointer cancel (scroll takeover) returns the pill', (
    tester,
  ) async {
    await _pumpPill(
      tester,
      SizedBox(
        width: 160,
        height: 48,
        child: GlossyPill(
          liquid: true,
          onTap: () {},
          child: const Text('Q', textDirection: TextDirection.ltr),
        ),
      ),
    );
    final restCenter = tester.getCenter(find.text('Q'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GlassContainer)),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(7, 0));
      await tester.pump(const Duration(milliseconds: 32));
    }
    await gesture.cancel();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(
      (tester.getCenter(find.text('Q')) - restCenter).distance,
      lessThan(0.5),
      reason: 'cancel возвращает объект на место',
    );
    _errors.clear();
  });
}
