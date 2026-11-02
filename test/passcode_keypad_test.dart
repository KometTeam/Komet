import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/main.dart' show api;
import 'package:komet/frontend/screens/lock/passcode_pad.dart';
import 'package:komet/frontend/screens/lock/passcode_setup_screen.dart';
import 'package:komet/l10n/app_localizations.dart';

Future<List<int>> _pumpKeypad(
  WidgetTester tester, {
  bool enabled = true,
  double? viewportHeight,
}) async {
  final typed = <int>[];
  final keypad = PasscodeKeypad(
    onDigit: typed.add,
    onBackspace: () {},
    enabled: enabled,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: viewportHeight == null
              ? keypad
              : SizedBox(
                  height: viewportHeight,
                  child: SingleChildScrollView(child: Center(child: keypad)),
                ),
        ),
      ),
    ),
  );
  return typed;
}

void main() {
  testWidgets('a key fires the moment it is touched', (tester) async {
    final typed = await _pumpKeypad(tester);

    final gesture = await tester.startGesture(tester.getCenter(find.text('5')));
    await tester.pump();
    expect(typed, [5]);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(typed, [5]);
  });

  testWidgets('a tap in the gap between keys presses the nearest key', (
    tester,
  ) async {
    final typed = await _pumpKeypad(tester);
    final one = tester.getCenter(find.text('1'));
    final two = tester.getCenter(find.text('2'));
    final four = tester.getCenter(find.text('4'));
    const half = PasscodeKeypad.maxKeySize / 2;

    await tester.tapAt(Offset(one.dx + half + 4, one.dy));
    await tester.tapAt(Offset(two.dx - half - 4, two.dy));
    await tester.tapAt(Offset(one.dx, one.dy + half + 3));
    await tester.tapAt(Offset(four.dx, four.dy - half - 3));
    await tester.pumpAndSettle();

    expect(typed, [1, 2, 1, 4]);
  });

  testWidgets('quick taps on the same key all register', (tester) async {
    final typed = await _pumpKeypad(tester);
    final seven = tester.getCenter(find.text('7'));

    for (var i = 0; i < 4; i++) {
      await tester.tapAt(seven);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();

    expect(typed, [7, 7, 7, 7]);
  });

  testWidgets('a disabled keypad ignores touches', (tester) async {
    final typed = await _pumpKeypad(tester, enabled: false);

    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(typed, isEmpty);
  });

  testWidgets(
    'in a scrolled layout a key waits for release and scrolling types nothing',
    (tester) async {
      final typed = await _pumpKeypad(tester, viewportHeight: 200);

      final drag = await tester.startGesture(tester.getCenter(find.text('2')));
      await tester.pump();
      expect(typed, isEmpty);
      await drag.moveBy(const Offset(0, -80));
      await drag.up();
      await tester.pumpAndSettle();
      expect(typed, isEmpty);

      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(typed, [5]);
    },
  );

  testWidgets('digits typed right after the first code are kept', (
    tester,
  ) async {
    String? saved;
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<bool>(
        builder: (_) => PasscodeSetupScreen(
          title: 'synthetic',
          onSave: (pin) async => saved = pin,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final digit in '24682'.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 200));
    for (final digit in '468'.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(saved, '2468');
    await tester.pumpWidget(const SizedBox.shrink());
    await api.dispose();
  });
}
