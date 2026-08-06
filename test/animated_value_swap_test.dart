import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/animated_text_swap.dart';

Widget _host(int value) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: AnimatedValueSwap<int>(
        value: value,
        builder: (context, v) => Text('$v'),
      ),
    ),
  ),
);

final Finder _slidingParts = find.descendant(
  of: find.byType(AnimatedValueSwap<int>),
  matching: find.byType(FractionalTranslation),
);

void main() {
  testWidgets('первое значение показывается без анимации', (tester) async {
    await tester.pumpWidget(_host(3));

    expect(find.text('3'), findsOneWidget);
    expect(_slidingParts, findsNothing);
  });

  testWidgets('смена значения перелистывает старое и новое', (tester) async {
    await tester.pumpWidget(_host(1));
    await tester.pumpWidget(_host(2));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(_slidingParts, findsNWidgets(2));

    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('старое значение уезжает вверх, новое приходит снизу', (
    tester,
  ) async {
    await tester.pumpWidget(_host(1));
    await tester.pumpWidget(_host(2));
    await tester.pump(const Duration(milliseconds: 120));

    final outgoing = tester.widget<FractionalTranslation>(
      find
          .ancestor(
            of: find.text('1'),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );
    final incoming = tester.widget<FractionalTranslation>(
      find
          .ancestor(
            of: find.text('2'),
            matching: find.byType(FractionalTranslation),
          )
          .first,
    );

    expect(outgoing.translation.dy, lessThan(0));
    expect(incoming.translation.dy, greaterThan(0));
  });

  testWidgets('тот же самый номер не запускает анимацию', (tester) async {
    await tester.pumpWidget(_host(7));
    await tester.pumpWidget(_host(7));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('7'), findsOneWidget);
    expect(_slidingParts, findsNothing);
  });
}
