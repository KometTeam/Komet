import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/custom_notification.dart';
import 'package:komet/frontend/widgets/hint_bubble.dart';

const _hint = 'Время должно быть в будущем';
const _anchorKey = ValueKey('anchor');

class _Host extends StatelessWidget {
  final Alignment alignment;
  final bool anchorVisible;
  final double anchorWidth;

  const _Host({
    this.alignment = Alignment.center,
    this.anchorVisible = true,
    this.anchorWidth = 80,
  });

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: alignment,
        child: anchorVisible
            ? Builder(
                builder: (anchor) => GestureDetector(
                  onTap: () => showHintBubble(anchor, _hint),
                  child: SizedBox(
                    key: _anchorKey,
                    width: anchorWidth,
                    height: 40,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ),
  );
}

Future<void> _showHint(WidgetTester tester) async {
  await tester.tap(find.byKey(_anchorKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Rect _bubbleRect(WidgetTester tester) => tester.getRect(
  find.ancestor(of: find.text(_hint), matching: find.byType(Padding)).first,
);

Finder get _bubblePaint => find
    .ancestor(of: find.text(_hint), matching: find.byType(FadeTransition))
    .first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  trackHintBubblePresses();

  testWidgets('подсказка встаёт над элементом по его центру', (tester) async {
    await tester.pumpWidget(const _Host());
    await _showHint(tester);

    final anchor = tester.getRect(find.byKey(_anchorKey));
    final bubble = _bubbleRect(tester);
    expect(bubble.bottom, anchor.top - HintBubbleStyle.anchorGap);
    expect(bubble.center.dx, moreOrLessEquals(anchor.center.dx));
    expect(find.byType(CustomNotification), findsNothing);
  });

  testWidgets('без места сверху подсказка уходит под элемент', (tester) async {
    await tester.pumpWidget(const _Host(alignment: Alignment.topCenter));
    await _showHint(tester);

    final anchor = tester.getRect(find.byKey(_anchorKey));
    expect(_bubbleRect(tester).top, anchor.bottom + HintBubbleStyle.anchorGap);
  });

  testWidgets('у края экрана подсказка не вылезает за поля', (tester) async {
    await tester.pumpWidget(const _Host(alignment: Alignment.bottomRight));
    await _showHint(tester);

    final screen = tester.getRect(find.byType(Scaffold));
    expect(
      _bubbleRect(tester).right,
      screen.right - HintBubbleStyle.screenMargin,
    );
  });

  testWidgets('хвостик указывает на место нажатия, а не на центр элемента', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(anchorWidth: 800));
    final anchor = tester.getRect(find.byKey(_anchorKey));
    final press = Offset(200, anchor.center.dy);

    await tester.tapAt(press);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final bubble = _bubbleRect(tester);
    final insideTail = bubble.bottom + HintBubbleStyle.tail.height / 2;
    expect(bubble.center.dx, moreOrLessEquals(press.dx));
    expect(
      _bubblePaint,
      paints
        ..path()
        ..path(
          includes: [Offset(press.dx, insideTail)],
          excludes: [
            Offset(press.dx - HintBubbleStyle.tail.width, insideTail),
            Offset(anchor.center.dx, insideTail),
          ],
        ),
    );
  });

  testWidgets('у подсказки под элементом хвостик смотрит вверх', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host(alignment: Alignment.topCenter));
    await _showHint(tester);

    final anchor = tester.getRect(find.byKey(_anchorKey));
    final bubble = _bubbleRect(tester);
    final insideTail = bubble.top - HintBubbleStyle.tail.height / 2;
    expect(
      _bubblePaint,
      paints
        ..path()
        ..path(includes: [Offset(anchor.center.dx, insideTail)]),
    );
  });

  testWidgets('подсказка сама исчезает по таймеру', (tester) async {
    await tester.pumpWidget(const _Host());
    await _showHint(tester);
    expect(find.text(_hint), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('касание мимо убирает подсказку раньше таймера', (tester) async {
    await tester.pumpWidget(const _Host());
    await _showHint(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('повторный показ заменяет подсказку, а не плодит вторую', (
    tester,
  ) async {
    await tester.pumpWidget(const _Host());
    await _showHint(tester);
    await _showHint(tester);

    expect(find.text(_hint), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('подсказка едет за элементом', (tester) async {
    await tester.pumpWidget(const _Host());
    await _showHint(tester);

    final before = _bubbleRect(tester);

    await tester.pumpWidget(const _Host(alignment: Alignment(0, 0.6)));
    await tester.pump();

    final anchor = tester.getRect(find.byKey(_anchorKey));
    final bubble = _bubbleRect(tester);
    expect(bubble.top, greaterThan(before.top));
    expect(bubble.bottom, anchor.top - HintBubbleStyle.anchorGap);
  });

  testWidgets('подсказка пропадает вместе с элементом', (tester) async {
    await tester.pumpWidget(const _Host());
    await _showHint(tester);

    await tester.pumpWidget(const _Host(anchorVisible: false));
    await tester.pump();
    expect(find.text(_hint), findsNothing);
  });
}
