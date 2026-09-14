import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:komet/backend/login_gate.dart';

const _timeout = Duration(seconds: 1);

void main() {
  test('requests pass straight through before any session', () async {
    final gate = LoginGate();
    await gate.wait(_timeout, 'chatHistory');
  });

  test('a new session holds requests until the login succeeds', () async {
    final gate = LoginGate()..close();
    var released = false;
    final waiting = gate.wait(_timeout, 'chatHistory').then((_) {
      released = true;
    });

    await Future<void>.delayed(Duration.zero);
    expect(released, isFalse);

    gate
      ..noteLoginSent()
      ..noteLoginAnswer(ok: true);
    await waiting;
    expect(released, isTrue);
    expect(gate.loginUnanswered, isFalse);
  });

  test('a rejected login keeps requests waiting', () async {
    final gate = LoginGate()
      ..close()
      ..noteLoginSent()
      ..noteLoginAnswer(ok: false);

    expect(gate.loginUnanswered, isFalse);
    await expectLater(
      gate.wait(const Duration(milliseconds: 50), 'chatHistory'),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('a login without an answer is reported as unanswered', () {
    final gate = LoginGate()
      ..close()
      ..noteLoginSent();

    expect(gate.loginUnanswered, isTrue);
  });

  test('dropping the session fails the waiting requests', () async {
    final gate = LoginGate()..close();
    final waiting = gate.wait(_timeout, 'chatHistory');

    gate.fail();

    await expectLater(waiting, throwsA(isA<StateError>()));
  });

  test('a reconnect fails requests left from the old session', () async {
    final gate = LoginGate()..close();
    final stale = gate.wait(_timeout, 'chatHistory');

    gate.close();

    await expectLater(stale, throwsA(isA<StateError>()));
    expect(gate.loginUnanswered, isFalse);
  });
}
