import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:komet/core/config/app_message_actions_style.dart';
import 'package:komet/frontend/screens/profile/customization_section.dart';

Future<void> _openCustomization(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      locale: Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(child: CustomizationSection()),
      ),
    ),
  );
  await tester.tap(find.text('Кастомизация'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    AppMessageActionsStyle.current.value = MessageActionsStyle.list;
  });

  test('iOS ignores a stored radial style', () {
    AppMessageActionsStyle.current.value = MessageActionsStyle.radial;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppMessageActionsStyle.effective, MessageActionsStyle.list);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppMessageActionsStyle.effective, MessageActionsStyle.radial);
  });

  testWidgets('iOS customization has no message menu style entry', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _openCustomization(tester);
    expect(find.text('Шрифты'), findsOneWidget);
    expect(find.text('Меню действий'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android customization keeps the message menu style entry', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await _openCustomization(tester);
    expect(find.text('Меню действий'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
