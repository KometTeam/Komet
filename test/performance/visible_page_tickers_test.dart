import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/visible_page_tickers.dart';

void main() {
  testWidgets('only pages intersecting the viewport have active tickers', (
    tester,
  ) async {
    final position = ValueNotifier<double>(0);
    addTearDown(position.dispose);
    final keys = List.generate(3, (_) => GlobalKey());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (var index = 0; index < keys.length; index++)
              VisiblePageTickers(
                index: index,
                enabled: true,
                positionChanges: position,
                pagePosition: () => position.value,
                child: SizedBox(key: keys[index]),
              ),
          ],
        ),
      ),
    );
    List<bool> active() => [
      for (final key in keys) TickerMode.valuesOf(key.currentContext!).enabled,
    ];
    final original = keys[0].currentContext;
    expect(active(), [true, false, false]);
    position.value = 0.5;
    await tester.pump();
    expect(active(), [true, true, false]);
    position.value = 1;
    await tester.pump();
    expect(active(), [false, true, false]);
    position.value = 0;
    await tester.pump();
    expect(active(), [true, false, false]);
    expect(identical(keys[0].currentContext, original), isTrue);
  });

  testWidgets('disabled optimization preserves page ticker behavior', (
    tester,
  ) async {
    final position = ValueNotifier<double>(0);
    addTearDown(position.dispose);
    final key = GlobalKey();
    await tester.pumpWidget(
      VisiblePageTickers(
        index: 3,
        enabled: false,
        positionChanges: position,
        pagePosition: () => position.value,
        child: SizedBox(key: key),
      ),
    );
    expect(TickerMode.valuesOf(key.currentContext!).enabled, isTrue);
  });
}
