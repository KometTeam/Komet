import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/chat_menu_overlay.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  testWidgets('a header closes the menu before running its action', (
    tester,
  ) async {
    var actionRuns = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showChatMenu(
                  context: context,
                  anchorRect: const Rect.fromLTWH(100, 100, 40, 40),
                  compact: true,
                  header: Builder(
                    builder: (headerContext) => InkWell(
                      onTap: () => closeChatMenu(
                        headerContext,
                      ).then((_) => actionRuns++),
                      child: const Text('Synthetic header'),
                    ),
                  ),
                  items: const [
                    ChatMenuItem(
                      icon: Symbols.content_copy,
                      label: 'Synthetic item',
                    ),
                  ],
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic header'), findsOneWidget);

    await tester.tap(find.text('Synthetic header'));
    await tester.pump();
    expect(actionRuns, 0);

    await tester.pumpAndSettle();
    expect(actionRuns, 1);
    expect(find.text('Synthetic header'), findsNothing);
    expect(find.text('Synthetic item'), findsNothing);
  });

  testWidgets('closing outside a menu is a no-op', (tester) async {
    late BuildContext outside;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            outside = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await expectLater(closeChatMenu(outside), completes);
  });
}
