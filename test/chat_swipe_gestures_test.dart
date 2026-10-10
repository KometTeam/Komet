import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/utils/haptics.dart';
import 'package:komet/frontend/widgets/swipe_route.dart';
import 'package:komet/frontend/widgets/swipe_to_reply.dart';
import 'package:komet/frontend/widgets/scroll_keyboard_dismiss.dart';

const _backgroundKey = ValueKey('background');
const _pageKey = ValueKey('page');
const _messageKey = ValueKey('message');

class _Harness {
  final navigatorKey = GlobalKey<NavigatorState>();
  final focus = FocusNode();
  final scroll = ScrollController();
  int replies = 0;

  Future<void> pump(WidgetTester tester, {bool canPop = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SizedBox.expand(key: _backgroundKey)),
      ),
    );
    navigatorKey.currentState!.push(
      SwipeRoute<void>(
        builder: (_) => PopScope(
          canPop: canPop,
          child: Scaffold(
            key: _pageKey,
            body: Column(
              children: [
                Expanded(
                  child: ScrollKeyboardDismiss(
                    onDismiss: focus.unfocus,
                    child: CustomScrollView(
                      controller: scroll,
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.manual,
                      slivers: [
                        SliverList.builder(
                          itemCount: 30,
                          itemBuilder: (_, index) => SwipeToReply(
                            onReply: () => replies++,
                            child: SizedBox(
                              key: index == 2 ? _messageKey : null,
                              height: 100,
                              width: double.infinity,
                              child: Text('Synthetic message $index'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextField(focusNode: focus),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
    scroll.dispose();
  }
}

void main() {
  setUp(() => Haptics.enabled = false);
  tearDown(() => Haptics.enabled = true);

  testWidgets('a cancelled back gesture restores the page past halfway', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    final y = tester.getCenter(find.byKey(_messageKey)).dy;
    final gesture = await tester.startGesture(Offset(100, y));
    await gesture.moveBy(
      const Offset(450, 0),
      timeStamp: const Duration(milliseconds: 700),
    );
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.byKey(_pageKey), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(_pageKey)).dx, 0);
    expect(harness.navigatorKey.currentState!.userGestureInProgress, isFalse);
    await harness.dispose(tester);
  });

  testWidgets('an interrupted route releases its active back gesture', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_messageKey)),
    );
    await gesture.moveBy(
      const Offset(60, 0),
      timeStamp: const Duration(milliseconds: 200),
    );
    await tester.pump();
    harness.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_pageKey), findsNothing);
    expect(harness.navigatorKey.currentState!.userGestureInProgress, isFalse);
    expect(tester.takeException(), isNull);
    await harness.dispose(tester);
  });

  testWidgets(
    'reply uses the initial movement and leaves back navigation idle',
    (tester) async {
      final harness = _Harness();
      await harness.pump(tester);
      await tester.showKeyboard(find.byType(TextField));
      final initialLeft = tester.getTopLeft(find.byKey(_messageKey)).dx;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_messageKey)),
      );
      await gesture.moveBy(
        const Offset(-60, 0),
        timeStamp: const Duration(milliseconds: 300),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(_messageKey)).dx,
        lessThan(initialLeft - 56),
      );
      expect(harness.navigatorKey.currentState!.userGestureInProgress, isFalse);
      expect(harness.focus.hasFocus, isTrue);
      expect(harness.replies, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(harness.replies, 1);
      expect(tester.getTopLeft(find.byKey(_messageKey)).dx, initialLeft);
      await harness.dispose(tester);
    },
  );

  testWidgets('reply resistance is gradual and retracting cancels the reply', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_messageKey)),
    );
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    final firstOffset = tester.getTopLeft(find.byKey(_messageKey)).dx;
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    final nextOffset = tester.getTopLeft(find.byKey(_messageKey)).dx;
    expect(nextOffset, lessThan(firstOffset));
    expect(firstOffset - nextOffset, lessThan(20));
    await gesture.moveBy(const Offset(180, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(harness.replies, 0);
    expect(tester.getTopLeft(find.byKey(_messageKey)).dx, 0);
    await harness.dispose(tester);
  });

  testWidgets('pointer cancellation never commits a reply', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_messageKey)),
    );
    await gesture.moveBy(const Offset(-100, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(harness.replies, 0);
    expect(tester.getTopLeft(find.byKey(_messageKey)).dx, 0);
    await harness.dispose(tester);
  });

  testWidgets(
    'vertical scrolling dismisses focus without replying or popping',
    (tester) async {
      final harness = _Harness();
      await harness.pump(tester);
      await tester.showKeyboard(find.byType(TextField));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_messageKey)),
      );
      for (var step = 1; step <= 8; step++) {
        await gesture.moveBy(
          const Offset(1, 14),
          timeStamp: Duration(milliseconds: step * 28),
        );
        await tester.pump(const Duration(milliseconds: 28));
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 230));
      await tester.pumpAndSettle();
      expect(harness.scroll.offset, greaterThan(0));
      expect(harness.focus.hasFocus, isFalse);
      expect(harness.replies, 0);
      expect(find.byKey(_pageKey), findsOneWidget);
      expect(harness.navigatorKey.currentState!.userGestureInProgress, isFalse);
      await harness.dispose(tester);
    },
  );

  testWidgets('slow vertical scrolling keeps the keyboard open', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await tester.showKeyboard(find.byType(TextField));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_messageKey)),
    );
    for (var step = 1; step <= 10; step++) {
      await gesture.moveBy(
        const Offset(0, 10),
        timeStamp: Duration(milliseconds: step * 140),
      );
      await tester.pump(const Duration(milliseconds: 140));
      expect(harness.focus.hasFocus, isTrue);
    }
    await gesture.up(timeStamp: const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(harness.scroll.offset, greaterThan(0));
    expect(tester.testTextInput.isVisible, isTrue);
    expect(harness.replies, 0);
    await harness.dispose(tester);
  });

  testWidgets('accelerating a slow scroll dismisses the keyboard', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);
    await tester.showKeyboard(find.byType(TextField));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(_messageKey)),
    );
    for (var step = 1; step <= 5; step++) {
      await gesture.moveBy(
        const Offset(0, 10),
        timeStamp: Duration(milliseconds: step * 140),
      );
      await tester.pump(const Duration(milliseconds: 140));
    }
    expect(harness.focus.hasFocus, isTrue);
    for (var step = 1; step <= 8; step++) {
      await gesture.moveBy(
        const Offset(0, 12),
        timeStamp: Duration(milliseconds: 700 + step * 20),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(harness.focus.hasFocus, isFalse);
    await gesture.up(timeStamp: const Duration(milliseconds: 880));
    await tester.pumpAndSettle();
    await harness.dispose(tester);
  });

  testWidgets('programmatic scrolling keeps the keyboard open', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);
    await tester.showKeyboard(find.byType(TextField));
    harness.scroll.jumpTo(400);
    await tester.pumpAndSettle();
    expect(harness.focus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await harness.dispose(tester);
  });

  testWidgets('a blocked pop does not dismiss the composer or move the page', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester, canPop: false);
    await tester.showKeyboard(find.byType(TextField));
    await tester.drag(find.byKey(_messageKey), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(harness.focus.hasFocus, isTrue);
    expect(tester.getTopLeft(find.byKey(_pageKey)).dx, 0);
    expect(harness.navigatorKey.currentState!.userGestureInProgress, isFalse);
    await harness.dispose(tester);
  });
}
