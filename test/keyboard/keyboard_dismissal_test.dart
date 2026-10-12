import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/keyboard_dismissal.dart';

Widget _app(Widget body, {List<NavigatorObserver> observers = const []}) {
  return MaterialApp(
    navigatorObservers: observers,
    builder: (context, child) => KeyboardDismissal(child: child!),
    home: Scaffold(body: body),
  );
}

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  late FocusNode focus;

  setUp(() => focus = FocusNode());
  tearDown(() => focus.dispose());

  Future<void> focusField(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  }

  testWidgets('iOS: a short tap outside the field hides the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            TextField(key: const ValueKey('field'), focusNode: focus),
            const SizedBox(key: ValueKey('outside'), height: 300),
          ],
        ),
      ),
    );
    await focusField(tester);

    await tester.tap(find.byKey(const ValueKey('outside')));
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  }, variant: _ios);

  testWidgets('iOS: a long press or a drag keeps the keyboard', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            TextField(key: const ValueKey('field'), focusNode: focus),
            const SizedBox(key: ValueKey('outside'), height: 300),
          ],
        ),
      ),
    );
    await focusField(tester);

    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('outside'))),
    );
    await tester.pump(const Duration(seconds: 1));
    await hold.up(timeStamp: const Duration(seconds: 1));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('outside'))),
      const Offset(120, 0),
    );
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  }, variant: _ios);

  testWidgets('iOS: buttons inside TextFieldTapRegion keep the keyboard', (
    tester,
  ) async {
    var sent = 0;
    await tester.pumpWidget(
      _app(
        TextFieldTapRegion(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('field'),
                  focusNode: focus,
                ),
              ),
              IconButton(
                key: const ValueKey('send'),
                onPressed: () => sent++,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
    await focusField(tester);

    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();
    expect(sent, 1);
    expect(focus.hasFocus, isTrue);
  }, variant: _ios);

  testWidgets(
    'iOS: vertical scrolling hides the keyboard, horizontal does not',
    (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              TextField(key: const ValueKey('field'), focusNode: focus),
              SizedBox(
                height: 80,
                child: ListView(
                  key: const ValueKey('row'),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < 20; i++)
                      SizedBox(width: 80, child: Text('h$i')),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('list'),
                  children: [
                    for (var i = 0; i < 40; i++)
                      SizedBox(height: 60, child: Text('v$i')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      await focusField(tester);

      await tester.drag(
        find.byKey(const ValueKey('row')),
        const Offset(-200, 0),
      );
      await tester.pump();
      expect(focus.hasFocus, isTrue);

      await tester.drag(
        find.byKey(const ValueKey('list')),
        const Offset(0, -200),
      );
      await tester.pump();
      expect(focus.hasFocus, isFalse);
    },
    variant: _ios,
  );

  testWidgets('iOS: scrolling inside a multiline field keeps the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        ListView(
          children: [
            TextField(
              key: const ValueKey('field'),
              focusNode: focus,
              maxLines: 3,
              controller: TextEditingController(
                text: List.generate(30, (i) => 'строка $i').join('\n'),
              ),
            ),
          ],
        ),
      ),
    );
    await focusField(tester);

    await tester.drag(find.byType(EditableText), const Offset(0, -60));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  }, variant: _ios);

  testWidgets('iOS: opening a screen hides the keyboard', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [KeyboardNavigatorObserver()],
        home: Scaffold(
          body: TextField(key: const ValueKey('field'), focusNode: focus),
        ),
      ),
    );
    await focusField(tester);

    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold()),
    );
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
  }, variant: _ios);

  testWidgets('iOS: starting the back swipe hides the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(TextField(key: const ValueKey('field'), focusNode: focus)),
    );
    await focusField(tester);

    KeyboardNavigatorObserver().didStartUserGesture(
      MaterialPageRoute<void>(builder: (_) => const SizedBox()),
      null,
    );
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  }, variant: _ios);

  testWidgets('Android keeps the default: a tap outside keeps the keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            TextField(key: const ValueKey('field'), focusNode: focus),
            const SizedBox(key: ValueKey('outside'), height: 300),
          ],
        ),
      ),
    );
    await focusField(tester);

    await tester.tap(find.byKey(const ValueKey('outside')));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
