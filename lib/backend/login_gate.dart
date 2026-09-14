import 'dart:async';

class LoginGate {
  Completer<void>? _gate;
  bool _loginSent = false;
  bool _loginAnswered = false;

  bool get loginUnanswered => _loginSent && !_loginAnswered;

  void close() {
    fail();
    final gate = Completer<void>();
    gate.future.ignore();
    _gate = gate;
    _loginSent = false;
    _loginAnswered = false;
  }

  void open() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  void fail() {
    final gate = _gate;
    if (gate != null && !gate.isCompleted) {
      gate.completeError(StateError('Нет соединения'));
    }
  }

  void noteLoginSent() => _loginSent = true;

  void noteLoginAnswer({required bool ok}) {
    _loginAnswered = true;
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
