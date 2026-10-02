import 'dart:async';

class LoginGate {
  Completer<void>? _gate;
  bool _loginSent = false;
  bool _loginAnswered = false;
  bool _loginSucceeded = false;

  bool get loginUnanswered => _loginSent && !_loginAnswered;
  bool get loginRejected => _loginSent && _loginAnswered && !_loginSucceeded;

  void close() {
    fail();
    final gate = Completer<void>();
    gate.future.ignore();
    _gate = gate;
    _loginSent = false;
    _loginAnswered = false;
    _loginSucceeded = false;
  }

  void open() {
    if (_loginSent && !_loginSucceeded) return;
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  void fail() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      gate.completeError(StateError('Нет соединения'));
    }
  }

  void noteLoginSent() {
    _loginSent = true;
    _loginAnswered = false;
    _loginSucceeded = false;
  }

  void noteLoginAnswer({required bool ok}) {
    _loginAnswered = true;
    _loginSucceeded = ok;
    if (ok) open();
  }

  Future<void> wait(Duration timeout, String request) async {
    final gate = _gate;
    if (gate == null || gate.isCompleted) return;
    await gate.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException('$request: вход не завершён'),
    );
  }
}
