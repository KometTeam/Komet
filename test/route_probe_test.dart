import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/route_probe.dart';

class _BuildCounter extends StatelessWidget {
  const _BuildCounter(this.onBuild);

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const Text('page');
  }
}

void main() {
  testWidgets('route status changes do not rebuild the probed subtree', (
    tester,
  ) async {
    final routes = <ModalRoute<Object?>>[];
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RouteProbe(
          onRoute: routes.add,
          child: _BuildCounter(() => builds++),
        ),
      ),
    );
    expect(builds, 1);
    expect(routes, hasLength(1));
    expect(routes.single.isCurrent, isTrue);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const Text('next')));
    await tester.pumpAndSettle();
    expect(routes.single.isCurrent, isFalse);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(routes.single.isCurrent, isTrue);
    expect(builds, 1);
    expect(routes, hasLength(1));
  });
}
