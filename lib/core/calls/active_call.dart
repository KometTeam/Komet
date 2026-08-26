import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'call_session.dart';

class ActiveCallPresentation {
  const ActiveCallPresentation({
    required this.session,
    required this.name,
    required this.avatarUrl,
    required this.isGroup,
  });

  final CallSession session;
  final String name;
  final String? avatarUrl;
  final bool isGroup;

  bool sameAs(ActiveCallPresentation other) =>
      identical(session, other.session) &&
      name == other.name &&
      avatarUrl == other.avatarUrl &&
      isGroup == other.isGroup;
}

class ActiveCall {
  ActiveCall._();

  static final ActiveCall instance = ActiveCall._();

  final ValueNotifier<ActiveCallPresentation?> current = ValueNotifier(null);

  final ValueNotifier<bool> screenVisible = ValueNotifier(false);

  int _openScreens = 0;
  StreamSubscription<CallSessionState>? _stateSub;

  void attach({
    required CallSession session,
    required String name,
    String? avatarUrl,
    bool isGroup = false,
  }) {
    if (session.currentState == CallSessionState.ended) return;
    final next = ActiveCallPresentation(
      session: session,
      name: name,
      avatarUrl: avatarUrl,
      isGroup: isGroup,
    );
    final previous = current.value;
    if (previous != null && previous.sameAs(next)) return;
    if (previous == null || !identical(previous.session, session)) {
      _stateSub?.cancel();
      _stateSub = session.stateStream.listen((state) {
        if (state == CallSessionState.ended) detach(session);
      });
    }
    _publish(current, next);
  }

  void detach([CallSession? session]) {
    final active = current.value;
    if (active == null) return;
    if (session != null && !identical(active.session, session)) return;
    _stateSub?.cancel();
    _stateSub = null;
    _publish(current, null);
  }

  void enterScreen() {
    _openScreens++;
    _publish(screenVisible, true);
  }

  void leaveScreen() {
    if (_openScreens > 0) _openScreens--;
    _publish(screenVisible, _openScreens > 0);
  }

  void _publish<T>(ValueNotifier<T> notifier, T value) {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifier.value = value;
      });
      return;
    }
    notifier.value = value;
  }
}
