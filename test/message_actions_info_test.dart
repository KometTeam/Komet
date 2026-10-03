import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:komet/core/config/app_message_actions_style.dart';
import 'package:komet/frontend/widgets/message_actions_overlay.dart';
import 'package:komet/l10n/app_localizations.dart';

const List<({String label, String value})> _rows = [
  (label: 'id', value: '117241017304569410'),
  (label: 'cid', value: '-1788955952374'),
];

Future<void> _openMenu(
  WidgetTester tester, {
  required List<({String label, String value})>? infoRows,
}) async {
  final controller = MessageActionsController();
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
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
              infoRows: infoRows,
              onDispose: () {},
            ),
            child: const Text('open menu'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open menu'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('без технических данных пункта Info в меню нет', (tester) async {
    await _openMenu(tester, infoRows: null);
    expect(find.text('Info'), findsNothing);
  });

  testWidgets('Info раскрывает панель с полями сообщения', (tester) async {
    await _openMenu(tester, infoRows: _rows);

    expect(find.text('Info'), findsOneWidget);
    expect(find.text('117241017304569410'), findsNothing);

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();

    expect(find.text('id'), findsOneWidget);
    expect(find.text('117241017304569410'), findsOneWidget);
    expect(find.text('cid'), findsOneWidget);
    expect(find.text('-1788955952374'), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('117241017304569410'), findsNothing);
    expect(find.text('Info'), findsOneWidget);
  });
}
