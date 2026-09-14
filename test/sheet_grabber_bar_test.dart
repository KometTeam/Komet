import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/sheet_helpers.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, Widget action) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(children: [SheetGrabberBar(action: action)]),
        ),
      ),
    );
  }

  testWidgets('bar spans the sheet even inside a centring column', (
    tester,
  ) async {
    await pumpBar(tester, const SizedBox(width: 30, height: 30));

    final bar = tester.getSize(find.byType(SheetGrabberBar));
    expect(bar.width, tester.getSize(find.byType(Scaffold)).width);
    expect(bar.height, SheetGrabberBar.height);
  });

  testWidgets('grabber stays centred while the action hugs the right edge', (
    tester,
  ) async {
    await pumpBar(
      tester,
      const SizedBox(key: ValueKey('action'), width: 30, height: 30),
    );

    final bar = tester.getRect(find.byType(SheetGrabberBar));
    final grabber = tester.getRect(find.byType(SheetGrabber));
    final action = tester.getRect(find.byKey(const ValueKey('action')));

    expect(grabber.center.dx, closeTo(bar.center.dx, 0.01));
    expect(grabber.center.dy, closeTo(bar.center.dy, 0.01));
    expect(action.right, closeTo(bar.right - SheetGrabberBar.actionInset, 0.01));
    expect(action.center.dy, closeTo(bar.center.dy, 0.01));
    expect(action.left, greaterThan(grabber.right));
  });

  testWidgets('height is stable when the action renders nothing', (
    tester,
  ) async {
    await pumpBar(tester, const SizedBox.shrink());

    expect(tester.getSize(find.byType(SheetGrabberBar)).height, 34);
    expect(find.byType(SheetGrabber), findsOneWidget);
  });
}
