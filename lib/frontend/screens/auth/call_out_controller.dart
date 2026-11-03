import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../backend/modules/account.dart';
import '../../../core/protocol/packet.dart';
import '../../../core/utils/logger.dart';

enum CallOutPhase { waitingForNumber, awaitingCall, verified, expired, failed }

class CallOutController extends ChangeNotifier {
  CallOutController({required CallOutParams params, required this.check})
    : _params = params;

  final Future<CallOutCheck> Function(String trackId) check;

  final ValueNotifier<Duration> remaining = ValueNotifier(Duration.zero);
  final Stopwatch _clock = Stopwatch();
  CallOutParams _params;
  Timer? _pollTimer;
  Timer? _countdown;
  int _generation = 0;
  bool _disposed = false;

  CallOutPhase _phase = CallOutPhase.waitingForNumber;
  String? _callNumber;
  Object? _error;

  CallOutPhase get phase => _phase;

  String? get callNumber => _callNumber;

  Object? get error => _error;

  String get trackId => _params.trackId;

  bool get active =>
      _phase == CallOutPhase.waitingForNumber ||
      _phase == CallOutPhase.awaitingCall;

  void start() => restart(_params);

  void restart(CallOutParams params) {
    if (_disposed) return;
    _params = params;
    final generation = ++_generation;
    _pollTimer?.cancel();
    _countdown?.cancel();
    _phase = CallOutPhase.waitingForNumber;
    _callNumber = null;
    _error = null;
    _clock
      ..reset()
      ..start();
    remaining.value = params.ttl;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
    unawaited(_poll(generation));
  }

  void pollNow() {
    if (_disposed || !active) return;
    _pollTimer?.cancel();
    unawaited(_poll(_generation));
  }

  Duration get _left {
    final left = _params.ttl - _clock.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    remaining.value = _left;
    if (remaining.value == Duration.zero) _finish(CallOutPhase.expired);
  }

  Future<void> _poll(int generation) async {
    if (!_isCurrent(generation)) return;
    if (_left == Duration.zero) {
      _finish(CallOutPhase.expired);
      return;
    }

    final CallOutCheck result;
    try {
      result = await check(trackId);
    } catch (e) {
      if (!_isCurrent(generation)) return;
      if (e is PacketError) {
        _error = e;
        _finish(CallOutPhase.failed);
        return;
      }
      logger.d('проверка звонка не дошла, повторим: $e');
      _schedule(generation);
      return;
    }
    if (!_isCurrent(generation)) return;

    switch (result.status) {
      case CallOutStatus.verificationPassed:
        _finish(CallOutPhase.verified);
        return;
      case CallOutStatus.verificationTimeout:
        _finish(CallOutPhase.expired);
        return;
      case CallOutStatus.numberAssigned:
        final number = result.callNumber;
        if (number != null && number != _callNumber) {
          _callNumber = number;
          _phase = CallOutPhase.awaitingCall;
          notifyListeners();
        }
      case CallOutStatus.numberNotAssigned:
      case null:
        break;
    }
    _schedule(generation);
  }

  bool _isCurrent(int generation) =>
      !_disposed && generation == _generation && active;

  void _schedule(int generation) {
    _pollTimer?.cancel();
    _pollTimer = Timer(_params.pollingInterval, () {
      unawaited(_poll(generation));
    });
  }

  void _finish(CallOutPhase phase) {
    if (_disposed) return;
    _pollTimer?.cancel();
    _countdown?.cancel();
    _clock.stop();
    if (phase == CallOutPhase.expired) remaining.value = Duration.zero;
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pollTimer?.cancel();
    _countdown?.cancel();
    remaining.dispose();
    super.dispose();
  }
}
