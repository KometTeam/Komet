import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/chats/chat/view/drag_intercept_scroll.dart';

void _dragBy(ScrollController controller, double delta) {
  final drag = controller.position.drag(DragStartDetails(), () {});
  drag.update(
    DragUpdateDetails(
      globalPosition: Offset.zero,
      delta: Offset(0, delta),
      primaryDelta: delta,
    ),
  );
  drag.end(DragEndDetails(primaryVelocity: 0));
}

Widget _list(ScrollController controller) => MaterialApp(
  home: ListView.builder(
    controller: controller,
    physics: const ClampingScrollPhysics(),
    itemCount: 100,
    itemBuilder: (context, i) => SizedBox(height: 50, child: Text('row $i')),
  ),
);

void main() {
  testWidgets('перехват забирает свою долю сдвига, остальное скроллит', (
    tester,
  ) async {
    var taken = 0.0;
    final controller = DragInterceptScrollController(
      intercept: (position, delta) {
        final share = delta / 2;
        taken += share;
        return share;
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_list(controller));
    controller.jumpTo(500);

    _dragBy(controller, -100);
    expect(controller.offset, 550);
    expect(taken, -50);
  });

  testWidgets('полностью перехваченный сдвиг не двигает список', (
    tester,
  ) async {
    final controller = DragInterceptScrollController(
      intercept: (position, delta) => delta,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_list(controller));
    controller.jumpTo(500);

    final drag = controller.position.drag(DragStartDetails(), () {});
    drag.update(
      DragUpdateDetails(
        globalPosition: Offset.zero,
        delta: const Offset(0, -100),
        primaryDelta: -100,
      ),
    );
    expect(controller.offset, 500);
    expect(
      controller.position.userScrollDirection,
      ScrollDirection.reverse,
    );
    drag.end(DragEndDetails(primaryVelocity: 0));
  });

  testWidgets('настоящий жест идёт через перехват', (tester) async {
    var calls = 0;
    final controller = DragInterceptScrollController(
      intercept: (position, delta) {
        calls++;
        return 0;
      },
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_list(controller));

    await tester.drag(find.text('row 3'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(0));
    expect(controller.offset, greaterThan(0));
  });
}
