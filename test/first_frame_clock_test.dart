import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/first_frame_clock.dart';
import 'package:komet/frontend/widgets/swipe_route.dart';

void main() {
  const frame = Duration(microseconds: 16667);

  final routes = <String, PageRoute<void> Function()>{
    'swipe route': () =>
        SwipeRoute<void>(builder: (_) => const Scaffold(body: Text('chat'))),
    'material route': () => FirstFramePageRoute<void>(
      builder: (_) => const Scaffold(body: Text('chat')),
    ),
  };

  for (final MapEntry(key: name, value: create) in routes.entries) {
    Future<PageRoute<void>> pushRoute(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('list'))),
      );
      final route = create();
      tester.state<NavigatorState>(find.byType(Navigator)).push(route);
      return route;
    }

    double progress(PageRoute<void> route, Duration shown) =>
        shown.inMicroseconds / route.transitionDuration.inMicroseconds;

    group(name, () {
      testWidgets('a slow first frame does not skip the start of the push', (
        tester,
      ) async {
        final route = await pushRoute(tester);
        await tester.pump();
        expect(route.animation!.value, 0);

        await tester.pump(const Duration(milliseconds: 60));
        expect(route.animation!.value, closeTo(progress(route, frame), 0.002));

        await tester.pumpAndSettle();
        expect(route.animation!.status, AnimationStatus.completed);
      });

      testWidgets('a slow first paint right after it is absorbed as well', (
        tester,
      ) async {
        final route = await pushRoute(tester);
        await tester.pump();
        await tester.pump(frame);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          route.animation!.value,
          closeTo(progress(route, frame * 2), 0.002),
        );
      });

      testWidgets('after the first frames the clock keeps the stock pace', (
        tester,
      ) async {
        final route = await pushRoute(tester);
        await tester.pump();
        for (var i = 0; i < 3; i++) {
          await tester.pump(frame);
        }
        expect(
          route.animation!.value,
          closeTo(progress(route, frame * 3), 0.002),
        );

        await tester.pump(const Duration(milliseconds: 100));
        expect(
          route.animation!.value,
          closeTo(
            progress(route, frame * 3 + const Duration(milliseconds: 100)),
            0.002,
          ),
        );
      });

      testWidgets('the pop after an absorbed push runs on its own clock', (
        tester,
      ) async {
        final route = await pushRoute(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pumpAndSettle();

        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final reverse = route.reverseTransitionDuration.inMicroseconds;
        expect(route.animation!.value, closeTo(1 - 100000 / reverse, 0.002));

        await tester.pumpAndSettle();
        expect(find.text('chat'), findsNothing);
      });
    });
  }
}
