import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/security/app_lock.dart';
import 'package:komet/frontend/screens/lock/app_lock_layer.dart';
import 'package:komet/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppLockLayer(child: child!),
      home: const Scaffold(body: Center(child: Text('synthetic chats'))),
    ),
  );
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

void main() {
  final lock = AppLock.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await lock.load();
  });

  tearDown(() async {
    await lock.disable();
  });

  testWidgets('locking covers the app and the passcode opens it again', (
    tester,
  ) async {
    await tester.runAsync(() => lock.setPin('1357'));
    await _pumpApp(tester);
    expect(find.text('Введите код-пароль'), findsNothing);

    lock.lock(origin: const Rect.fromLTWH(300, 20, 24, 24));
    await tester.pumpAndSettle();

    expect(find.text('Введите код-пароль'), findsOneWidget);
    expect(find.text('synthetic chats'), findsNothing);
    expect(find.text('synthetic chats', skipOffstage: false), findsOneWidget);

    await _enter(tester, '1111');
    expect(lock.locked.value, isTrue);
    expect(find.textContaining('Осталось попыток: 4'), findsOneWidget);

    await _enter(tester, '1357');
    expect(lock.locked.value, isFalse);
    expect(find.text('Введите код-пароль'), findsNothing);
    expect(find.text('synthetic chats'), findsOneWidget);
  });
}
