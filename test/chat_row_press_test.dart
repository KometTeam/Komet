import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/chat_row_press.dart';
import 'package:komet/frontend/widgets/springy_tap.dart';

Widget _list({required VoidCallback onTap}) => MaterialApp(
  home: Scaffold(
    body: ListView(
      children: [
        for (var i = 0; i < 30; i++)
          ChatRowPress(
            key: ValueKey('row_$i'),
            onTap: onTap,
            child: SizedBox(height: 72, child: Text('Chat $i')),
          ),
      ],
    ),
  ),
);

bool _anyScaled(WidgetTester tester) {
  final scales = find.descendant(
    of: find.byType(ChatRowPress),
    matching: find.byType(ScaleTransition),
  );
  for (final t in tester.widgetList<ScaleTransition>(scales)) {
    if (t.scale.value != 1.0) return true;
  }
  return false;
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  testWidgets('iOS rows have no scale feedback', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_list(onTap: () {}));
    expect(find.byType(SpringyTap), findsNothing);
    final ink = tester.widget<InkWell>(find.byType(InkWell).first);
    expect(ink.splashFactory, same(NoSplash.splashFactory));
    expect(ink.highlightColor, isNotNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: a scroll starting on a row neither taps nor scales it', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var taps = 0;
    await tester.pumpWidget(_list(onTap: () => taps++));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Chat 2')),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(_anyScaled(tester), isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: a short tap still opens the row', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var taps = 0;
    await tester.pumpWidget(_list(onTap: () => taps++));
    await tester.tap(find.text('Chat 1'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android keeps the springy scale', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(_list(onTap: () {}));
    expect(find.byType(SpringyTap), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });
}
