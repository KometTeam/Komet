import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../backend/api.dart';
import '../../main.dart' show api;

mixin ReloadOnReconnect<T extends StatefulWidget> on State<T> {
  StreamSubscription<SessionState>? _reconnectSub;
  int _reloadedEpoch = api.sessionEpoch;

  void reloadAfterReconnect();

  @override
  void initState() {
    super.initState();
    _reconnectSub = api.stateStream.listen(_onSessionState);
  }

  @override
  void dispose() {
    _reconnectSub?.cancel();
    super.dispose();
  }

  void _onSessionState(SessionState state) {
    if (state != SessionState.online) return;
    if (api.sessionEpoch == _reloadedEpoch) return;
    _reloadedEpoch = api.sessionEpoch;
    if (mounted) reloadAfterReconnect();
  }
}
