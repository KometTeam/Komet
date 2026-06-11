import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/logger.dart';
import 'call_info.dart';
import 'conversation_params.dart';
import 'ws2_signaling.dart';

enum CallRole { caller, callee }

enum CallSessionState { connecting, ringing, active, ended }

class CallSession {
  final Ws2Config ws2Config;

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
  MediaStream? _remoteStreamRef;

  int? _peerId;
  String _peerType = 'USER';
  int _peerDeviceIdx = 0;

  bool _muted = false;
  bool _accepted = false;
  bool _peerMuted = false;
  bool _peerVideo = false;
  bool _mediaConnected = false;

  final CallInfo info = CallInfo();

  final _state = StreamController<CallSessionState>.broadcast();
  final _remoteStream = StreamController<MediaStream>.broadcast();
  final _info = StreamController<void>.broadcast();

  Stream<CallSessionState> get stateStream => _state.stream;
  Stream<MediaStream> get remoteStreamStream => _remoteStream.stream;
  MediaStream? get remoteStream => _remoteStreamRef;

  Stream<void> get infoUpdates => _info.stream;

  bool get isMuted => _muted;
  bool get peerMuted => _peerMuted;
  bool get peerVideo => _peerVideo;
  bool get mediaConnected => _mediaConnected;

  CallSessionState _current = CallSessionState.connecting;
  DateTime? _activeSince;

  CallSessionState get currentState => _current;

  int get elapsedSeconds =>
      _activeSince == null ? 0 : DateTime.now().difference(_activeSince!).inSeconds;

  void _setState(CallSessionState s) {
    if (_current == s || _current == CallSessionState.ended) return;
    if (s == CallSessionState.active) _activeSince ??= DateTime.now();
    _current = s;
    _state.add(s);
  }

  void _notifyInfo() {
    if (!_info.isClosed) _info.add(null);
  }

  Future<void> start() async {
    _setState(CallSessionState.connecting);
    info.region = ws2Config.uri.host;
    final signaling = Ws2Signaling(ws2Config);
    _signaling = signaling;
    signaling.notifications.listen(_onNotification, onError: (_) => _end());
    signaling.done.then((_) => _end());
    await signaling.connect();
  }

  Future<void> _onNotification(Map<String, dynamic> msg) async {
    _applyPeerMedia(msg);
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
      case 'registered-peer':
        _applyRegisteredPeer(msg);
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
    _applyConnectionInfo(msg, iceServers);

    logger.t('[call] connection — role=$role peer=$_peerId');

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

    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    pc.onIceCandidate = _onLocalCandidate;
    pc.onTrack = (event) => unawaited(_onRemoteTrack(event));
    pc.onConnectionState = (s) {
      final connected =
          s == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (connected != _mediaConnected) {
        _mediaConnected = connected;
        _notifyInfo();
        if (connected) {
          unawaited(_resolvePath());
          unawaited(_collectReceivers());
        }
      }
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

  String _videoDir(String sdp) {
    var inVideo = false;
    String? mline;
    var dir = '?';
    for (var line in sdp.split('\n')) {
      line = line.trim();
      if (line.startsWith('m=')) {
        inVideo = line.startsWith('m=video');
        if (inVideo) mline = line;
      } else if (inVideo &&
          (line == 'a=sendrecv' ||
              line == 'a=recvonly' ||
              line == 'a=sendonly' ||
              line == 'a=inactive')) {
        dir = line.substring(2);
      }
    }
    return mline == null ? 'НЕТ m=video' : '$mline -> $dir';
  }

  Future<void> _onRemoteTrack(RTCTrackEvent event) async {
    logger.t(
        '[call] remote track: ${event.track.kind} streams=${event.streams.length}');
    if (event.streams.isNotEmpty) {
      _remoteStreamRef = event.streams.first;
      _remoteStream.add(event.streams.first);
    } else {
      await _collectReceivers();
    }
  }

  Future<void> _pushRemoteTrack(MediaStreamTrack track) async {
    var stream = _remoteStreamRef;
    stream ??= await createLocalMediaStream('komet_remote');
    _remoteStreamRef = stream;
    if (!stream.getTracks().any((t) => t.id == track.id)) {
      try {
        await stream.addTrack(track);
      } catch (_) {}
    }
    _remoteStream.add(stream);
  }

  Future<void> _collectReceivers() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      for (final tr in await pc.getTransceivers()) {
        final track = tr.receiver.track;
        if (track != null) {
          logger.t('[call] receiver track: ${track.kind}');
          await _pushRemoteTrack(track);
        }
      }
    } catch (_) {}
  }

  Future<void> _createAndSendOffer() async {
    final pc = _pc;
    final peerId = _peerId;
    if (pc == null || peerId == null) return;

    final offer = await pc.createOffer({});
    final raw = offer.sdp ?? '';
    final sdp = _isDesktop ? _forceVp8(raw) : raw;
    await pc.setLocalDescription(RTCSessionDescription(sdp, offer.type));
    logger.t('[call] our offer video: ${_videoDir(sdp)}');
    await _signaling?.transmitSdp(
      participantId: peerId,
      participantType: _peerType,
      deviceIdx: _peerDeviceIdx,
      type: offer.type!,
      sdp: sdp,
    );
  }

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS;

  String _forceVp8(String sdp) {
    final lines = sdp.split('\r\n');
    var mIdx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('m=video')) {
        mIdx = i;
        break;
      }
    }
    if (mIdx == -1) return sdp;

    String? vp8;
    for (final l in lines) {
      final m = RegExp(r'^a=rtpmap:(\d+) VP8/90000').firstMatch(l);
      if (m != null) {
        vp8 = m.group(1);
        break;
      }
    }
    if (vp8 == null) return sdp;

    String? rtx;
    for (final l in lines) {
      final m = RegExp('^a=fmtp:(\\d+) apt=$vp8\$').firstMatch(l);
      if (m != null) {
        rtx = m.group(1);
        break;
      }
    }

    final keep = {vp8, ?rtx};
    final parts = lines[mIdx].split(' ');
    if (parts.length <= 3) return sdp;
    lines[mIdx] = [...parts.sublist(0, 3), ...keep].join(' ');

    var end = lines.length;
    for (var i = mIdx + 1; i < lines.length; i++) {
      if (lines[i].startsWith('m=')) {
        end = i;
        break;
      }
    }

    final ptLine = RegExp(r'^a=(?:rtpmap|fmtp|rtcp-fb):(\d+)');
    final result = <String>[];
    for (var i = 0; i < lines.length; i++) {
      if (i > mIdx && i < end) {
        final m = ptLine.firstMatch(lines[i]);
        if (m != null && !keep.contains(m.group(1))) continue;
      }
      result.add(lines[i]);
    }
    return result.join('\r\n');
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

      _applyRemoteSdp(desc);
      logger.t('[call] remote $type video: ${_videoDir(desc)}');

      if (type == 'answer' &&
          pc.signalingState !=
              RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        logger.t('[call] extra answer ignored (state=${pc.signalingState})');
        return;
      }

      await pc.setRemoteDescription(RTCSessionDescription(desc, type));

      if (type == 'offer') {
        final answer = await pc.createAnswer({});
        await pc.setLocalDescription(answer);
        logger.t('[call] our answer video: ${_videoDir(answer.sdp ?? '')}');
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
      unawaited(_collectReceivers());
      return;
    }

    final candidate = data['candidate'];
    if (candidate is Map) {
      _applyRemoteCandidate(candidate['candidate']);
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

  Future<void> accept() async {
    if (_accepted) return;
    _accepted = true;
    logger.t('[call] accepted');
    await _signaling?.acceptCall();
    await _signaling?.changeMediaSettings(isAudioEnabled: !_muted);
    _setState(CallSessionState.active);
  }

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
    if (!_info.isClosed) await _info.close();
  }

  void _applyConnectionInfo(Map<String, dynamic> msg, List iceServers) {
    final conv = msg['conversation'];
    if (conv is Map) {
      info.conversationId = conv['id']?.toString();
      info.topology = conv['topology']?.toString();
      final features = conv['features'];
      if (features is List) info.record = features.contains('RECORD');
      final parts = conv['participants'];
      if (parts is List) {
        for (final p in parts.whereType<Map>()) {
          if (p['id'] != ws2Config.userId) {
            final ms = p['mediaSettings'];
            if (ms is Map) {
              _peerMuted = ms['isAudioEnabled'] != true;
              _peerVideo = ms['isVideoEnabled'] == true;
            }
          }
        }
      }
    }
    final mm = msg['mediaModifiers'];
    if (mm is Map) {
      info.denoise = mm['denoise'] == true || mm['denoiseAnn'] == true;
    }
    info.stun.clear();
    info.turn.clear();
    for (final s in iceServers.whereType<Map>()) {
      final urls = s['urls'];
      final list = urls is List ? urls : [urls];
      for (final u in list) {
        final str = u.toString();
        if (str.startsWith('stun')) {
          info.stun.add(str);
        } else if (str.startsWith('turn')) {
          info.turn.add(str);
        }
      }
    }
    _notifyInfo();
  }

  void _applyPeerMedia(Map<String, dynamic> msg) {
    final ms = msg['mediaSettings'];
    if (ms is! Map) return;
    final pid = msg['participantId'];
    if (_peerId != null && pid != null && pid != _peerId) return;

    final muted = ms['isAudioEnabled'] != true;
    final video = ms['isVideoEnabled'] == true;
    if (muted != _peerMuted || video != _peerVideo) {
      _peerMuted = muted;
      _peerVideo = video;
      _notifyInfo();
      if (video) unawaited(_collectReceivers());
    }
  }

  void _applyRegisteredPeer(Map<String, dynamic> msg) {
    final peer = msg['peerId'];
    if (peer is Map && peer['type'] == 'WEB_TRANSPORT') return;
    final platform = msg['platform'];
    if (platform is String && platform.isNotEmpty) {
      info.peerPlatform = platform;
      _notifyInfo();
    }
  }

  void _applyRemoteSdp(String sdp) {
    info.peerEngine = CallParse.engine(sdp);
    info.audioCodec ??= CallParse.audioCodec(sdp);
    info.dtlsFingerprint ??= CallParse.fingerprint(sdp);
    if (CallParse.hasAnimoji(sdp)) info.animoji = true;
    _notifyInfo();
  }

  void _applyRemoteCandidate(Object? raw) {
    if (raw is! String || raw.isEmpty) return;
    final c = CallParse.candidate(raw);
    final type = c['type'];
    final ip = c['ip'];
    if (ip == null) return;
    if ((type == 'srflx' || type == 'host') && !CallParse.isServerIp(ip)) {
      info.peerIp = ip;
      info.peerNetwork = CallParse.networkLabel(c['cost']);
      _notifyInfo();
    }
  }

  Future<void> _resolvePath() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final stats = await pc.getStats();
      final byId = {for (final r in stats) r.id: r};
      StatsReport? pair;
      StatsReport? anySucceeded;
      for (final r in stats) {
        if (r.type != 'candidate-pair') continue;
        if (r.values['state'] != 'succeeded') continue;
        anySucceeded ??= r;
        if (r.values['nominated'] == true || r.values['selected'] == true) {
          pair = r;
          break;
        }
      }
      pair ??= anySucceeded;
      if (pair == null) return;
      final local = byId[pair.values['localCandidateId']];
      final remote = byId[pair.values['remoteCandidateId']];
      info.path = CallParse.pathLabel(
        local?.values['candidateType']?.toString(),
        remote?.values['candidateType']?.toString(),
      );
      _notifyInfo();
    } catch (_) {}
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
