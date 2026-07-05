import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../../backend/api.dart';
import '../../../main.dart';
import '../../widgets/custom_notification.dart';

mixin SessionStaleRecovery<T extends StatefulWidget> on State<T> {
  int sessionEpoch = 0;
  bool recovering = false;
  bool dropNotified = false;
  StreamSubscription<SessionState>? _stateSub;

  bool get sessionStale =>
      api.sessionEpoch != sessionEpoch || api.state != SessionState.online;

  String get connectionDroppedMessage;

  void recoverStaleSession();

  void startSessionRecovery() {
    sessionEpoch = api.sessionEpoch;
    _stateSub = api.stateStream.listen(_onSessionState);
  }

  void stopSessionRecovery() {
    _stateSub?.cancel();
  }

  void _onSessionState(SessionState state) {
    if (!mounted) return;
    if (state != SessionState.online) {
      if (!dropNotified) {
        dropNotified = true;
        showCustomNotification(context, connectionDroppedMessage);
      }
      return;
    }
    if (api.sessionEpoch != sessionEpoch) recoverStaleSession();
  }
}
