import 'dart:async';

class ReadMarkerGate {
  ReadMarkerGate({
    required this.onFlush,
    this.debounce = const Duration(milliseconds: 350),
  });

  final void Function() onFlush;
  final Duration debounce;

  Timer? _timer;
  int _holds = 0;

  bool get held => _holds > 0;

  void hold() {
    _holds++;
    _cancel();
  }

  void release() {
    if (_holds > 0) _holds--;
    schedule();
  }

  void schedule() {
    _cancel();
    _timer = Timer(debounce, () {
      _timer = null;
      if (held) return;
      onFlush();
    });
  }

  void flush() {
    if (held) return;
    _cancel();
    onFlush();
  }

  void dispose() => _cancel();

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
