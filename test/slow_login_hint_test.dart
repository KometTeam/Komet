import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/frontend/screens/auth/slow_login_hint.dart';
import 'package:komet/l10n/app_localizations.dart';

Widget _host(bool active) => MaterialApp(
  locale: const Locale('ru'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SlowLoginHint(active: active, idle: const Text('synthetic idle')),
  ),
);

void main() {
  testWidgets('подсказка появляется только через 2 секунды ожидания', (
    tester,
  ) async {
    await tester.pumpWidget(_host(false));
    expect(find.text('synthetic idle'), findsOneWidget);

    await tester.pumpWidget(_host(true));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.textContaining('дольше обычного'), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.textContaining('дольше обычного'), findsOneWidget);
    expect(find.text('synthetic idle'), findsNothing);

    await tester.pumpWidget(_host(false));
    await tester.pumpAndSettle();
    expect(find.text('synthetic idle'), findsOneWidget);
    expect(find.textContaining('дольше обычного'), findsNothing);
  });
}
