import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/security/archive_lock.dart';
import 'package:komet/core/security/pin_credential.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DateTime now;
  late ArchiveLock lock;

  void wait(Duration duration) {
    now = now.add(duration);
    lock.onLifecycle(AppLifecycleState.resumed, external: false);
  }

  Future<void> openThroughGate() async {
    lock.retain();
    expect(await lock.unlock('2468'), isTrue);
    lock.retain();
    lock.release();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    now = DateTime(2026, 1, 1, 12);
    lock = ArchiveLock.withClock(() => now);
    await lock.load();
  });

  test('without a passcode the archive is never locked', () {
    expect(lock.enabled.value, isFalse);
    lock.retain();
    lock.release();
    wait(const Duration(hours: 1));
    expect(lock.locked.value, isFalse);
  });

  test(
    'a new passcode locks the archive and only the right code opens it',
    () async {
      await lock.setPin('2468');
      expect(lock.enabled.value, isTrue);
      expect(lock.locked.value, isTrue);

      expect(await lock.unlock('1111'), isFalse);
      expect(lock.locked.value, isTrue);
      expect(lock.credential.attemptsLeft, PinCredential.maxAttempts - 1);

      expect(await lock.unlock('2468'), isTrue);
      expect(lock.locked.value, isFalse);
      expect(lock.credential.attemptsLeft, PinCredential.maxAttempts);
    },
  );

  test('immediate relock closes the archive the moment it is left', () async {
    await lock.setRelockMinutes(0);
    await lock.setPin('2468');

    await openThroughGate();
    expect(lock.locked.value, isFalse);

    lock.release();
    expect(lock.locked.value, isTrue);
  });

  test('coming back before the timeout restarts the countdown', () async {
    await lock.setRelockMinutes(5);
    await lock.setPin('2468');
    await openThroughGate();
    lock.release();

    wait(const Duration(minutes: 2));
    expect(lock.locked.value, isFalse);

    lock.retain();
    wait(const Duration(minutes: 10));
    lock.release();
    expect(lock.locked.value, isFalse);

    wait(const Duration(minutes: 4));
    expect(lock.locked.value, isFalse);

    wait(const Duration(minutes: 1));
    expect(lock.locked.value, isTrue);
  });

  test('a shorter timeout applies to a countdown already running', () async {
    await lock.setRelockMinutes(30);
    await lock.setPin('2468');
    await openThroughGate();
    lock.release();

    wait(const Duration(minutes: 10));
    expect(lock.locked.value, isFalse);

    await lock.setRelockMinutes(5);
    expect(lock.locked.value, isTrue);
  });

  test(
    'backgrounding with the archive open counts, an app picker does not',
    () async {
      await lock.setRelockMinutes(1);
      await lock.setPin('2468');
      await openThroughGate();

      lock.onLifecycle(AppLifecycleState.paused, external: true);
      wait(const Duration(minutes: 5));
      expect(lock.locked.value, isFalse);

      lock.onLifecycle(AppLifecycleState.hidden, external: false);
      lock.onLifecycle(AppLifecycleState.paused, external: false);
      wait(const Duration(seconds: 30));
      expect(lock.locked.value, isFalse);

      wait(const Duration(minutes: 5));
      expect(lock.locked.value, isFalse);

      lock.onLifecycle(AppLifecycleState.paused, external: false);
      wait(const Duration(minutes: 2));
      expect(lock.locked.value, isTrue);

      lock.release();
      expect(lock.locked.value, isTrue);
    },
  );

  test('a restart forgets the open session', () async {
    await lock.setPin('2468');
    await openThroughGate();
    lock.release();

    await lock.load();

    expect(lock.enabled.value, isTrue);
    expect(lock.locked.value, isTrue);
  });

  test(
    'removing the passcode opens the archive and forgets the code',
    () async {
      await lock.setPin('2468');
      await lock.disable();

      expect(lock.enabled.value, isFalse);
      expect(lock.locked.value, isFalse);
      expect(await lock.credential.matches('2468'), isFalse);
      await lock.load();
      expect(lock.locked.value, isFalse);
    },
  );
}
