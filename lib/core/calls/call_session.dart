import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'conversation_params.dart';
import 'ws2_signaling.dart';

enum CallRole { caller, callee }

enum CallSessionState { connecting, ringing, active, ended }

/// Один сеанс 1:1 аудиозвонка: связывает сигналинг [Ws2Signaling] с
/// `RTCPeerConnection`.
///
/// Поток (подтверждён захватом `docs/ws2_capture.log` для звонящего и
/// реконструирован из `ru.ok.android.externcalls.sdk` для вызываемого):
/// - сервер шлёт `connection` → берём ICE-сервера и id собеседника;
/// - звонящий: createOffer → `transmit-data`(offer); ждёт `transmitted-data`(answer);
/// - вызываемый: `transmitted-data`(offer) → createAnswer → `transmit-data`(answer);
/// - обе стороны: ICE-кандидаты через `transmit-data`, приём — через `transmitted-data`;
/// - вызываемый по тапу «принять» шлёт `accept-call`.
class CallSession {
  final Ws2Config ws2Config;

  /// Параметры из `vcp` (входящий звонок) — резервный источник ICE-серверов,
  /// если их нет в пуше `connection`. Для исходящего может быть `null`.
  final ConversationParams? params;
  final CallRole role;

  CallSession({
    required this.ws2Config,
    required this.role,
    this.params,
  });

  Ws2Signaling? _signaling;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;

  int? _peerId;
  String _peerType = 'USER';
  int _peerDeviceIdx = 0;

  bool _muted = false;
  bool _accepted = false;

  final _state = StreamController<CallSessionState>.broadcast();
  final _remoteStream = StreamController<MediaStream>.broadcast();

  Stream<CallSessionState> get stateStream => _state.stream;
  Stream<MediaStream> get remoteStreamStream => _remoteStream.stream;
  bool get isMuted => _muted;

  CallSessionState _current = CallSessionState.connecting;
  DateTime? _activeSince;

  /// Текущее состояние (для переоткрытия свёрнутого экрана —
  /// broadcast-поток не отдаёт последнее значение новым слушателям).
  CallSessionState get currentState => _current;

  /// Длительность разговора в секундах (0, пока не активен).
  int get elapsedSeconds =>
      _activeSince == null ? 0 : DateTime.now().difference(_activeSince!).inSeconds;

  void _setState(CallSessionState s) {
    if (_current == s || _current == CallSessionState.ended) return;
    if (s == CallSessionState.active) _activeSince ??= DateTime.now();
    _current = s;
    _state.add(s);
  }

  Future<void> start() async {
    _setState(CallSessionState.connecting);
    final signaling = Ws2Signaling(ws2Config);
    _signaling = signaling;
    signaling.notifications.listen(_onNotification, onError: (_) => _end());
    signaling.done.then((_) => _end());
    await signaling.connect();
  }

  Future<void> _onNotification(Map<String, dynamic> msg) async {
    switch (msg['notification']) {
      case 'connection':
        await _onConnection(msg);
        break;
      case 'transmitted-data':
        await _onTransmittedData(msg);
        break;
      case 'accepted-call':
        _setState(CallSessionState.active);
        break;
      case 'closed-conversation':
        _end();
        break;
    }
  }

  Future<void> _onConnection(Map<String, dynamic> msg) async {
    final convParams = msg['conversationParams'];
    final conversation = msg['conversation'];

    final iceServers =
        _iceServersFrom(convParams) ?? params?.iceServers ?? const [];
    _resolvePeer(conversation);

    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = _onLocalCandidate;
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) _remoteStream.add(event.streams.first);
    };
    pc.onConnectionState = (s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _end();
      }
    };

    if (role == CallRole.caller) {
      _setState(CallSessionState.ringing);
      await _createAndSendOffer();
    }
  }

  Future<void> _createAndSendOffer() async {
    final pc = _pc;
    final peerId = _peerId;
    if (pc == null || peerId == null) return;

    final offer = await pc.createOffer({});
    await pc.setLocalDescription(offer);
    await _signaling?.transmitSdp(
      participantId: peerId,
      participantType: _peerType,
      deviceIdx: _peerDeviceIdx,
      type: offer.type!,
      sdp: offer.sdp!,
    );
  }

  Future<void> _onTransmittedData(Map<String, dynamic> msg) async {
    final pc = _pc;
    if (pc == null) return;

    final data = msg['data'];
    if (data is! Map) return;

    final sdp = data['sdp'];
    if (sdp is Map) {
      final type = sdp['type'] as String?;
      final desc = sdp['sdp'] as String?;
      if (type == null || desc == null) return;

      await pc.setRemoteDescription(RTCSessionDescription(desc, type));

      if (type == 'offer') {
        // Сторона вызываемого: отвечаем answer.
        final answer = await pc.createAnswer({});
        await pc.setLocalDescription(answer);
        final peerId = _peerId;
        if (peerId != null) {
          await _signaling?.transmitSdp(
            participantId: peerId,
            participantType: _peerType,
            deviceIdx: _peerDeviceIdx,
            type: answer.type!,
            sdp: answer.sdp!,
          );
        }
        if (_current == CallSessionState.connecting) {
          _setState(CallSessionState.ringing);
        }
      }
      return;
    }

    final candidate = data['candidate'];
    if (candidate is Map) {
      await pc.addCandidate(RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      ));
    }
  }

  void _onLocalCandidate(RTCIceCandidate candidate) {
    final peerId = _peerId;
    if (peerId == null || candidate.candidate == null) return;
    _signaling?.transmitCandidate(
      participantId: peerId,
      participantType: _peerType,
      deviceIdx: _peerDeviceIdx,
      candidate: candidate.candidate!,
      sdpMid: candidate.sdpMid ?? '0',
      sdpMLineIndex: candidate.sdpMLineIndex ?? 0,
    );
  }

  /// Принять входящий звонок (сторона вызываемого).
  Future<void> accept() async {
    if (_accepted) return;
    _accepted = true;
    await _signaling?.acceptCall();
    await _signaling?.changeMediaSettings(isAudioEnabled: !_muted);
    _setState(CallSessionState.active);
  }

  /// DEBUG: отправить серверу сигнал `change-media-settings` с заданным
  /// состоянием микрофона, НЕ трогая реальный аудиотрек.
  Future<void> sendAudioEnabledSignal(bool enabled) async {
    await _signaling?.changeMediaSettings(isAudioEnabled: enabled);
  }

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    for (final track in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    await _signaling?.changeMediaSettings(isAudioEnabled: !muted);
  }

  Future<void> hangup({String reason = 'HUNGUP'}) async {
    try {
      await _signaling?.hangup(reason: reason);
    } catch (_) {}
    _end();
  }

  bool _ended = false;
  void _end() {
    if (_ended) return;
    _ended = true;
    _setState(CallSessionState.ended);
    _dispose();
  }

  Future<void> _dispose() async {
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _pc?.close();
    await _signaling?.close();
    if (!_state.isClosed) await _state.close();
    if (!_remoteStream.isClosed) await _remoteStream.close();
  }

  void _resolvePeer(Object? conversation) {
    if (conversation is! Map) return;
    final participants = conversation['participants'];
    if (participants is! List) return;
    for (final p in participants.whereType<Map>()) {
      final id = p['id'];
      if (id is int && id != ws2Config.userId) {
        _peerId = id;
        final responderTypes = p['responderTypes'];
        if (responderTypes is List && responderTypes.isNotEmpty) {
          _peerType = responderTypes.first.toString();
        }
        final deviceIdxs = p['responderDeviceIdxs'];
        if (deviceIdxs is List && deviceIdxs.isNotEmpty && deviceIdxs.first is int) {
          _peerDeviceIdx = deviceIdxs.first as int;
        }
        break;
      }
    }
  }

  List<Map<String, dynamic>>? _iceServersFrom(Object? convParams) {
    if (convParams is! Map) return null;
    final servers = <Map<String, dynamic>>[];
    final stun = convParams['stun'];
    if (stun is Map && stun['urls'] != null) {
      servers.add({'urls': stun['urls']});
    }
    final turn = convParams['turn'];
    if (turn is Map && turn['urls'] != null) {
      servers.add({
        'urls': turn['urls'],
        if (turn['username'] != null) 'username': turn['username'],
        if (turn['credential'] != null) 'credential': turn['credential'],
      });
    }
    return servers.isEmpty ? null : servers;
  }
}
