import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/config/app_message_actions_style.dart';
import 'package:komet/frontend/widgets/message_actions_overlay.dart';
import 'package:komet/l10n/app_localizations.dart';

void main() {
  testWidgets('system back closes the message menu, not the chat', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var disposed = false;
    final controller = MessageActionsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('chats')),
      ),
    );

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMessageActions(
                context: context,
                originRect: const Rect.fromLTWH(20, 200, 200, 40),
                tapPoint: const Offset(60, 220),
                isMe: false,
                messageText: 'текст',
                copyText: 'текст',
                controller: controller,
                style: MessageActionsStyle.list,
                interaction: MessageActionsInteraction.click,
                onDispose: () => disposed = true,
              ),
              child: const Text('open menu'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();
    expect(disposed, isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(disposed, isTrue);
    expect(find.text('open menu'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('open menu'), findsNothing);
    expect(find.text('chats'), findsOneWidget);
  });
}
