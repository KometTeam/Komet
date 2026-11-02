import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/sticker_peek.dart';

const String _actionLabel = 'Синтетическое действие';

Widget _scope({
  List<StickerPeekAction> Function(Object peekId)? actionsFor,
  List<String> tags = const [],
}) {
  return MaterialApp(
    home: Scaffold(
      body: StickerPeekScope(
        actionsFor: actionsFor,
        child: Center(
          child: StickerPeekable(
            peekId: 1,
            tags: tags,
            child: const ColoredBox(
              color: Colors.teal,
              child: SizedBox(width: 80, height: 80),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _peekAndRelease(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(StickerPeekable)),
  );
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('releasing a peek keeps the preview open with its actions', (
    tester,
  ) async {
    var ran = 0;
    await tester.pumpWidget(
      _scope(
        actionsFor: (_) => [
          StickerPeekAction(
            icon: Icons.push_pin,
            label: _actionLabel,
            onTap: () => ran++,
          ),
        ],
      ),
    );

    await _peekAndRelease(tester);
    expect(find.text(_actionLabel), findsOneWidget);

    await tester.tap(find.text(_actionLabel));
    await tester.pumpAndSettle();

    expect(ran, 1);
    expect(find.text(_actionLabel), findsNothing);
  });

  testWidgets('tapping outside the menu closes the preview', (tester) async {
    var ran = 0;
    await tester.pumpWidget(
      _scope(
        actionsFor: (_) => [
          StickerPeekAction(
            icon: Icons.push_pin,
            label: _actionLabel,
            onTap: () => ran++,
          ),
        ],
      ),
    );

    await _peekAndRelease(tester);
    expect(find.text(_actionLabel), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(ran, 0);
    expect(find.text(_actionLabel), findsNothing);
  });

  testWidgets('back closes the menu without leaving the screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scope(
        actionsFor: (_) => [
          StickerPeekAction(
            icon: Icons.push_pin,
            label: _actionLabel,
            onTap: () {},
          ),
        ],
      ),
    );

    await _peekAndRelease(tester);
    expect(find.text(_actionLabel), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(_actionLabel), findsNothing);
    expect(find.byType(StickerPeekable), findsOneWidget);
  });

  testWidgets('a scope without actions closes the preview on release', (
    tester,
  ) async {
    await tester.pumpWidget(_scope());

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StickerPeekable)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('emoji tags get the overlay text style, not the debug one', (
    tester,
  ) async {
    await tester.pumpWidget(_scope(tags: const ['🐊']));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StickerPeekable)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 200));

    final tag = tester.element(find.text('🐊'));
    expect(
      DefaultTextStyle.of(tag).style.decoration,
      isNot(TextDecoration.underline),
    );

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('the tag shimmer stops after a few sweeps', (tester) async {
    await tester.pumpWidget(_scope(tags: const ['🐊']));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StickerPeekable)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('🐊'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
  });
}
