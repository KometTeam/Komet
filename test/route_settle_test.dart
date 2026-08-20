import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/route_settle.dart';

class _GatedPage extends StatefulWidget {
  const _GatedPage({required this.onSettled});

  final VoidCallback onSettled;

  @override
  State<_GatedPage> createState() => _GatedPageState();
}

class _GatedPageState extends State<_GatedPage> {
  late final RouteSettle _settle = RouteSettle(isMounted: () => mounted);
  bool _queued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settle.bind(context);
    if (!_queued) {
      _queued = true;
      _settle.run(widget.onSettled);
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  testWidgets('queued work waits for the push transition to finish', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    var ran = 0;

    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox.shrink()),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => _GatedPage(onSettled: () => ran++),
      ),
    );

    await tester.pump();
    expect(ran, 0);

    await tester.pump(const Duration(milliseconds: 100));
    expect(ran, 0);

    await tester.pumpAndSettle();
    expect(ran, 1);
  });

  testWidgets('a route that is already in place does not hold work back', (
    tester,
  ) async {
    var ran = 0;
    await tester.pumpWidget(
      MaterialApp(home: _GatedPage(onSettled: () => ran++)),
    );
    expect(ran, 1);
  });

  testWidgets('work runs immediately once the gate is open', (tester) async {
    final settle = RouteSettle(isMounted: () => true);
    settle.settleNow();

    var ran = 0;
    settle.run(() => ran++);
    expect(ran, 1);

    settle.dispose();
  });

  testWidgets('queued work is dropped when the owner is gone', (tester) async {
    var alive = true;
    final settle = RouteSettle(isMounted: () => alive);

    var ran = 0;
    settle.run(() => ran++);
    expect(ran, 0);

    alive = false;
    settle.settleNow();
    expect(ran, 0);

    settle.dispose();
  });
}
