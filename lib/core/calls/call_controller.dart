import 'dart:async';

import '../../backend/api.dart';
import '../../backend/modules/calls.dart';
import '../protocol/opcode_map.dart';
import '../protocol/packet.dart';
import '../utils/parse.dart';
import 'call_bridge.dart';
import 'call_session.dart';
import 'conversation_params.dart';
import 'ws2_signaling.dart';

class IncomingCall {
  final String conversationId;

  final int callerId;
  final bool isVideo;
  final ConversationParams params;

  final String? country;
  final bool? isContact;
  final String? callerName;

  final bool autoAccept;

  const IncomingCall({
    required this.conversationId,
    required this.callerId,
    required this.isVideo,
    required this.params,
    this.country,
    this.isContact,
    this.callerName,
    this.autoAccept = false,
  });
}

class CallController {
  CallController._();
  static final CallController instance = CallController._();

  Api? _api;
  CallsModule? _calls;
  StreamSubscription<Packet>? _pushSub;

  final _incoming = StreamController<IncomingCall>.broadcast();
  final _ended = StreamController<void>.broadcast();
  final _canceled = StreamController<void>.broadcast();

  bool appResumed = false;

  Stream<IncomingCall> get incomingCalls => _incoming.stream;

  Stream<void> get callEnded => _ended.stream;

  Stream<void> get incomingCanceled => _canceled.stream;

  CallSession? _active;
  CallSession? get activeSession => _active;

  IncomingCall? _pending;
  IncomingCall? get pendingIncoming => _pending;

  bool get isBusy => _active != null;

  void init(Api api) {
    if (_api != null) return;
    _api = api;
    _calls = CallsModule(api);
    _pushSub = api.pushStream.listen(_onPush);
  }

  void _onPush(Packet packet) {
    if (packet.opcode != Opcode.notifCallStart) return;
    if (!appResumed) return;
    final payload = packet.payload;
    if (payload is! Map) return;

    final vcp = payload['vcp'] as String?;
    final conversationId = payload['conversationId'] as String?;
    final callerId = payload['callerId'] as int?;
    if (vcp == null || conversationId == null || callerId == null) return;

    final params = ConversationParams.decode(vcp);
    if (params == null) return;

    _emitIncoming(
      IncomingCall(
        conversationId: conversationId,
        callerId: callerId,
        isVideo: payload['type'] == 'VIDEO' || params.isVideo,
        params: params,
        country: payload['country'] as String?,
        isContact: payload['isContact'] as bool?,
      ),
    );
  }

  void injectFromNative(Map<dynamic, dynamic> data, {bool autoAccept = false}) {
    final vcp = data['vcp']?.toString();
    if (vcp == null || vcp.isEmpty) return;

    final params = ConversationParams.decode(vcp);
    if (params == null) return;

    final conversationId = (data['conversationId'] ?? data['vcId'])?.toString();
    if (conversationId == null || conversationId.isEmpty) return;

    final callerId = parseIntOrNull(data['callerId'] ?? data['suid']);
    if (callerId == null) return;

    final type = (data['type'] ?? data['callType'])?.toString();
    final iv = data['iv'];
    final isVideo =
        params.isVideo || type == 'VIDEO' || iv == true || iv == 'true';

    _emitIncoming(
      IncomingCall(
        conversationId: conversationId,
        callerId: callerId,
        isVideo: isVideo,
        params: params,
        country: data['country']?.toString(),
        isContact: data['isContact'] is bool ? data['isContact'] as bool : null,
        callerName: data['userName']?.toString(),
        autoAccept: autoAccept,
      ),
    );
  }

  void _emitIncoming(IncomingCall incoming) {
    if (_active != null) return;
    if (_pending?.conversationId == incoming.conversationId) return;
    _pending = incoming;
    _incoming.add(incoming);
  }

  void dismissIncoming() {
    if (_pending == null) return;
    _pending = null;
    _canceled.add(null);
  }

  Future<CallSession> startOutgoing(
    int calleeId, {
    bool isVideo = false,
  }) async {
    if (_active != null) throw StateError('уже идёт звонок');
    final out = await _calls!.initiateCall(calleeId, isVideo: isVideo);
    final config = Ws2Config.fromEndpoint(
      out.endpoint,
      userId: out.callsUserId,
    );
    final session = CallSession(ws2Config: config, role: CallRole.caller);
    _bind(session);
    await session.start();
    CallBridge.instance.notifyAccepted();
    return session;
  }

  Future<CallLinkPreview?> previewCallLink(String url) =>
      _calls!.resolveCallLink(url);

  Future<CallSession> joinByLink(String token, {bool isVideo = false}) async {
    if (_active != null) throw StateError('уже идёт звонок');
    final params = await _calls!.joinByLink(token, isVideo: isVideo);
    final config = Ws2Config.fromEndpoint(
      params.endpoint,
      userId: params.callsUserId,
    );
    final session = CallSession(ws2Config: config, role: CallRole.joiner);
    _bind(session);
    await session.start();
    CallBridge.instance.notifyAccepted();
    return session;
  }

  Future<CallSession> acceptIncoming(IncomingCall call) async {
    _pending = null;
    CallBridge.instance.cancelIncoming();
    final config = Ws2Config.fromVcp(
      call.params,
      conversationId: call.conversationId,
    );
    final session = CallSession(
      ws2Config: config,
      params: call.params,
      role: CallRole.callee,
    );
    _bind(session);
    await session.start();
    await session.accept();
    CallBridge.instance.notifyAccepted(caller: call.callerName);
    return session;
  }

  Future<void> rejectIncoming(IncomingCall call) async {
    _pending = null;
    CallBridge.instance.notifyEnded();
    final config = Ws2Config.fromVcp(
      call.params,
      conversationId: call.conversationId,
    );
    final signaling = Ws2Signaling(config);
    try {
      await signaling.connect();
      await signaling.hangup(reason: 'REJECTED');
    } catch (_) {
    } finally {
      await signaling.close();
    }
  }

  Future<void> endActive() => _active?.hangup() ?? Future.value();

  Future<bool> sendMicSignal(bool enabled) async {
    final session = _active;
    if (session == null) return false;
    await session.sendAudioEnabledSignal(enabled);
    return true;
  }

  void _bind(CallSession session) {
    _active = session;
    session.stateStream.listen((state) {
      if (state == CallSessionState.ended && _active == session) {
        _active = null;
        CallBridge.instance.notifyEnded();
        _ended.add(null);
      }
    });
  }

  void dispose() {
    _pushSub?.cancel();
    _incoming.close();
    _ended.close();
    _canceled.close();
  }
}
