import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/widgets/chat_menu_overlay.dart';
import 'package:material_symbols_icons/symbols.dart';

void main() {
  testWidgets('a disabled menu item is shown but does not fire', (
    tester,
  ) async {
    var disabledTaps = 0;
    var enabledTaps = 0;
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
                  items: [
                    ChatMenuItem(
                      icon: Symbols.motion_photos_on,
                      label: 'Synthetic disabled',
                      enabled: false,
                      onTap: () => disabledTaps++,
                    ),
                    ChatMenuItem(
                      icon: Symbols.arrow_split,
                      label: 'Synthetic enabled',
                      onTap: () => enabledTaps++,
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
    expect(find.text('Synthetic disabled'), findsOneWidget);

    await tester.tap(find.text('Synthetic disabled'));
    await tester.pumpAndSettle();
    expect(disabledTaps, 0);
    expect(find.text('Synthetic disabled'), findsOneWidget);

    await tester.tap(find.text('Synthetic enabled'));
    await tester.pumpAndSettle();
    expect(enabledTaps, 1);
  });
}
