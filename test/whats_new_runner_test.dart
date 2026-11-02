import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/whats_new/spotlight_ids.dart';
import 'package:komet/core/whats_new/whats_new_document.dart';
import 'package:komet/frontend/widgets/spotlight.dart';
import 'package:komet/frontend/widgets/whats_new_runner.dart';
import 'package:komet/main.dart' show KometApp;

class _Section extends StatefulWidget {
  const _Section();

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SpotlightTarget(
          id: SpotlightIds.settingsCustomization,
          onActivate: () => setState(() => _expanded = true),
          child: const SizedBox(height: 56, child: Text('section')),
        ),
        if (_expanded)
          SpotlightTarget(
            id: SpotlightIds.settingsAppearance,
            onActivate: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const _Screen())),
            child: const SizedBox(height: 56, child: Text('appearance')),
          ),
      ],
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView.builder(
      itemCount: 80,
      itemBuilder: (context, index) => index == 60
          ? const SpotlightTarget(
              id: SpotlightIds.appearanceAnimations,
              child: SizedBox(height: 64, child: Text('animations switch')),
            )
          : SizedBox(height: 64, child: Text('option $index')),
    ),
  );
}

Future<void> _play(WidgetTester tester, Future<void> run) async {
  var done = false;
  run.whenComplete(() => done = true);
  for (var i = 0; i < 600 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done, isTrue, reason: 'scenario finished');
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('a scenario presses through a section to a deep switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: KometApp.navigatorKey,
        home: const Scaffold(body: _Section()),
      ),
    );
    final document = WhatsNewDocument.parse('''
#tour
    tap ${SpotlightIds.settingsCustomization}
    tap ${SpotlightIds.settingsAppearance}
    highlight ${SpotlightIds.appearanceAnimations}
    hint ${SpotlightIds.appearanceAnimations} "Turn animations off here"
''');
    expect(document.problems, isEmpty);

    await _play(
      tester,
      WhatsNewRunner(document).run(const WhatsNewTarget.scenario('tour')),
    );

    expect(find.byType(_Screen), findsOneWidget);
    final rect = tester.getRect(find.text('animations switch'));
    final screen =
        Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(screen.contains(rect.center), isTrue);
    expect(find.text('Turn animations off here'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('steps after open still run once the screen is pushed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: KometApp.navigatorKey,
        home: const Scaffold(body: _Section()),
      ),
    );
    final document = WhatsNewDocument.parse('''
#tour
    open https://example.test/release
    tap ${SpotlightIds.settingsCustomization}
''');

    await _play(
      tester,
      WhatsNewRunner(document).run(const WhatsNewTarget.scenario('tour')),
    );

    expect(find.text('appearance'), findsOneWidget);
  });

  testWidgets('tap refuses a target without an action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SpotlightTarget(
          id: SpotlightIds.storageLimit,
          child: SizedBox(height: 40),
        ),
      ),
    );
    var result = true;
    Spotlight.tap(SpotlightIds.storageLimit).then((value) => result = value);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(result, isFalse);
  });
}
