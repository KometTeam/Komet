import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/spoiler.dart';

const _secret = '+7 000 000 00 00';

class _Host extends StatefulWidget {
  const _Host({this.tickers = true});

  final bool tickers;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  bool revealed = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: TickerMode(
            enabled: widget.tickers,
            child: GestureDetector(
              onTap: () => setState(() => revealed = !revealed),
              child: Spoiler(
                revealed: revealed,
                color: Colors.grey,
                child: const Text(_secret),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

RenderObject _spoilerBox(WidgetTester tester) => tester.renderObject(
  find.descendant(
    of: find.byType(Spoiler),
    matching: find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_SpoilerBox',
    ),
  ),
);

void main() {
  testWidgets('hides the text behind animated particles until tapped', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const _Host());

    expect(SpoilerParticles.instance.isAnimating, isTrue);
    expect(_spoilerBox(tester), isNot(paints..paragraph()));
    expect(find.bySemanticsLabel(_secret), findsNothing);

    await tester.tap(find.byType(Spoiler));
    await tester.pumpAndSettle();

    expect(SpoilerParticles.instance.isAnimating, isFalse);
    expect(_spoilerBox(tester), paints..paragraph());
    expect(find.bySemanticsLabel(_secret), findsOneWidget);

    await tester.tap(find.byType(Spoiler));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(SpoilerParticles.instance.isAnimating, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(_spoilerBox(tester), isNot(paints..paragraph()));
    semantics.dispose();
  });

  testWidgets('the shared ticker stops with the last spoiler', (tester) async {
    await tester.pumpWidget(const _Host());
    expect(SpoilerParticles.instance.isAnimating, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(SpoilerParticles.instance.isAnimating, isFalse);
  });

  testWidgets('a muted subtree keeps the particles still', (tester) async {
    await tester.pumpWidget(const _Host(tickers: false));
    expect(SpoilerParticles.instance.isAnimating, isFalse);
    expect(_spoilerBox(tester), isNot(paints..paragraph()));
  });
}
