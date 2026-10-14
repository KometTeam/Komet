import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/security/archive_lock.dart';
import 'package:komet/frontend/screens/lock/archive_gate.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prompt = 'Введите пароль архива';

Future<void> _pumpApp(WidgetTester tester, {bool boundary = false}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: boundary
          ? (context, child) => RepaintBoundary(child: child)
          : null,
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => pushPastArchiveLock(
                context,
                tapPosition: const Offset(120, 300),
                destination: () => MaterialPageRoute<void>(
                  builder: (_) => const ArchiveSessionScope(
                    child: Scaffold(body: Text('synthetic archive')),
                  ),
                ),
              ),
              child: const Text('synthetic chats'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openArchive(WidgetTester tester) async {
  await tester.tap(find.text('synthetic chats'));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await tester.pumpAndSettle();
}

final _lock = ArchiveLock.instance;

Future<void> _closeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(_lock.disable);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await _lock.load();
  });

  tearDown(() async {
    await _lock.disable();
  });

  testWidgets('without a passcode the archive opens straight away', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _openArchive(tester);

    expect(find.text(_prompt), findsNothing);
    expect(find.text('synthetic archive'), findsOneWidget);
  });

  testWidgets('the gate asks for the passcode and then opens the archive', (
    tester,
  ) async {
    await tester.runAsync(() => _lock.setPin('1357'));
    await _pumpApp(tester);
    await _openArchive(tester);

    expect(find.text(_prompt), findsOneWidget);
    expect(find.text('synthetic archive'), findsNothing);

    await _enter(tester, '1111');
    expect(_lock.locked.value, isTrue);
    expect(find.textContaining('Осталось попыток: 4'), findsOneWidget);

    await _enter(tester, '1357');
    expect(_lock.locked.value, isFalse);
    expect(find.text(_prompt), findsNothing);
    expect(find.text('synthetic archive'), findsOneWidget);
    await _closeApp(tester);
  });

  testWidgets('the gate opens over a captured screen like in the app shell', (
    tester,
  ) async {
    await tester.runAsync(() => _lock.setPin('1357'));
    await _pumpApp(tester, boundary: true);
    await _openArchive(tester);

    expect(find.text(_prompt), findsOneWidget);
    expect(find.text('synthetic chats'), findsNothing);

    await _enter(tester, '1357');
    expect(find.text('synthetic archive'), findsOneWidget);
    await _closeApp(tester);
  });

  testWidgets('backing out of the gate keeps the archive locked', (
    tester,
  ) async {
    await tester.runAsync(() => _lock.setPin('1357'));
    await _pumpApp(tester);
    await _openArchive(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text(_prompt), findsNothing);
    expect(find.text('synthetic chats'), findsOneWidget);
    expect(_lock.locked.value, isTrue);
  });

  testWidgets('an expired session closes the open archive', (tester) async {
    await tester.runAsync(() => _lock.setPin('1357'));
    await _lock.setRelockMinutes(0);
    await _pumpApp(tester);
    await _openArchive(tester);
    await _enter(tester, '1357');
    expect(find.text('synthetic archive'), findsOneWidget);

    _lock.onLifecycle(AppLifecycleState.paused, external: false);
    await tester.pumpAndSettle();

    expect(_lock.locked.value, isTrue);
    expect(find.text('synthetic archive'), findsNothing);
    expect(find.text('synthetic chats'), findsOneWidget);
  });
}
