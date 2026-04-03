import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/l10n/app_localizations.dart';

void main() {
  testWidgets('AppLocalizations Russian login title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ru'),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Text(AppLocalizations.of(context)!.loginTitle),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Komet'), findsOneWidget);
  });
}
