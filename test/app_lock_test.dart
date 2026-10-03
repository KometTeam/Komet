import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/security/app_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final lock = AppLock.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await lock.load();
  });

  tearDown(() async {
    await lock.disable();
  });

  test('a fresh install is not locked', () {
    expect(lock.enabled.value, isFalse);
    expect(lock.locked.value, isFalse);
    lock.lock();
    expect(lock.locked.value, isFalse);
  });

  test('the right passcode unlocks and a wrong one does not', () async {
    await lock.setPin('2468');
    lock.lock();
    expect(lock.locked.value, isTrue);

    expect(await lock.unlockWithPin('1111'), isFalse);
    expect(lock.locked.value, isTrue);
    expect(lock.attemptsLeft, AppLock.maxAttempts - 1);

    expect(await lock.unlockWithPin('2468'), isTrue);
    expect(lock.locked.value, isFalse);
    expect(lock.attemptsLeft, AppLock.maxAttempts);
  });

  test('five wrong attempts block input even for the right code', () async {
    await lock.setPin('2468');
    lock.lock();
    for (var i = 0; i < AppLock.maxAttempts; i++) {
      expect(await lock.unlockWithPin('0000'), isFalse);
    }

    expect(lock.blockedUntil.value, isNotNull);
    expect(
      lock.blockedUntil.value!.difference(DateTime.now()),
      greaterThan(AppLock.lockout - const Duration(seconds: 5)),
    );
    expect(await lock.unlockWithPin('2468'), isFalse);
    expect(lock.locked.value, isTrue);
  });

  test('the lockout survives a restart', () async {
    await lock.setPin('2468');
    for (var i = 0; i < AppLock.maxAttempts; i++) {
      await lock.unlockWithPin('0000');
    }

    await lock.load();

    expect(lock.locked.value, isTrue);
    expect(lock.blockedUntil.value, isNotNull);
  });

  test('a restart with a passcode starts locked', () async {
    await lock.setPin('2468');
    lock.unlock();

    await lock.load();

    expect(lock.enabled.value, isTrue);
    expect(lock.locked.value, isTrue);
  });

  test(
    'going to the background locks, an app-launched picker does not',
    () async {
      await lock.setPin('2468');
      lock.unlock();

      await lock.external(() async {
        lock.onLifecycle(AppLifecycleState.paused);
      });
      expect(lock.locked.value, isFalse);

      lock.onLifecycle(AppLifecycleState.inactive);
      expect(lock.locked.value, isFalse);

      lock.onLifecycle(AppLifecycleState.paused);
      expect(lock.locked.value, isTrue);
    },
  );

  test('turning the passcode off forgets it', () async {
    await lock.setPin('2468');
    await lock.disable();

    expect(lock.enabled.value, isFalse);
    expect(await lock.checkPin('2468'), isFalse);
    await lock.load();
    expect(lock.locked.value, isFalse);
  });
}
