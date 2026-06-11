import 'dart:async';

import '../../backend/api.dart';
import '../../backend/modules/calls.dart';
import '../protocol/opcode_map.dart';
import '../protocol/packet.dart';
import 'call_session.dart';
import 'conversation_params.dart';
import 'ws2_signaling.dart';

/// Данные входящего звонка (из пуша opcode 137).
class IncomingCall {
  final String conversationId;

  /// ONE_ME id звонящего.
  final int callerId;
  final bool isVideo;
  final ConversationParams params;

  final String? country;
  final bool? isContact;

  const IncomingCall({
    required this.conversationId,
    required this.callerId,
    required this.isVideo,
    required this.params,
    this.country,
    this.isContact,
  });
}

/// Глобальный оркестратор звонков: слушает входящие (opcode 137),
/// инициирует исходящие (opcode 78) и держит активный [CallSession].
class CallController {
  CallController._();
  static final CallController instance = CallController._();

  Api? _api;
  CallsModule? _calls;
  StreamSubscription<Packet>? _pushSub;

  final _incoming = StreamController<IncomingCall>.broadcast();
  final _ended = StreamController<void>.broadcast();

  /// Новый входящий звонок — UI показывает экран/оверлей.
  Stream<IncomingCall> get incomingCalls => _incoming.stream;

  /// Активный звонок завершился (любой стороной).
  Stream<void> get callEnded => _ended.stream;

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
    final payload = packet.payload;
    if (payload is! Map) return;

    final vcp = payload['vcp'] as String?;
    final conversationId = payload['conversationId'] as String?;
    final callerId = payload['callerId'] as int?;
    if (vcp == null || conversationId == null || callerId == null) return;

    final params = ConversationParams.decode(vcp);
    if (params == null) return;

    // Уже идёт звонок — новый игнорируем (сервер сам отметит как пропущенный).
    if (_active != null) return;

    final incoming = IncomingCall(
      conversationId: conversationId,
      callerId: callerId,
      isVideo: payload['type'] == 'VIDEO',
      params: params,
      country: payload['country'] as String?,
      isContact: payload['isContact'] as bool?,
    );
    _pending = incoming;
    _incoming.add(incoming);
  }

  /// Начать исходящий 1:1 звонок.
  Future<CallSession> startOutgoing(int calleeId, {bool isVideo = false}) async {
    if (_active != null) throw StateError('уже идёт звонок');
    final out = await _calls!.initiateCall(calleeId, isVideo: isVideo);
    final config = Ws2Config.fromEndpoint(out.endpoint, userId: out.callsUserId);
    final session = CallSession(ws2Config: config, role: CallRole.caller);
    _bind(session);
    await session.start();
    return session;
  }

  /// Принять входящий звонок.
  Future<CallSession> acceptIncoming(IncomingCall call) async {
    _pending = null;
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
    return session;
  }

  /// Отклонить входящий звонок (подключаемся к ws2 только чтобы отправить
  /// `hangup reason=REJECTED`, без медиа).
  Future<void> rejectIncoming(IncomingCall call) async {
    _pending = null;
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

  /// Завершить активный звонок.
  Future<void> endActive() => _active?.hangup() ?? Future.value();

  /// DEBUG: послать в активный звонок сигнал состояния микрофона
  /// (`change-media-settings`), не трогая реальный микрофон.
  /// Возвращает `false`, если активного звонка нет.
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
        _ended.add(null);
      }
    });
  }

  void dispose() {
    _pushSub?.cancel();
    _incoming.close();
    _ended.close();
  }
}
