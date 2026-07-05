import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../utils/logger.dart';
import '../utils/parse.dart';
import 'call_info.dart';
import 'conversation_params.dart';
import 'ws2_signaling.dart';

enum CallRole { caller, callee, joiner }

enum CallSessionState { connecting, ringing, active, ended }

class CallParticipant {
  final int id;
  final bool isSelf;
  int? externalId;
  String state;
  bool audioEnabled;
  bool videoEnabled;
  bool screenSharing;
  bool handRaised;

  CallParticipant({
    required this.id,
    this.isSelf = false,
    this.externalId,
    this.state = '',
    this.audioEnabled = true,
    this.videoEnabled = false,
    this.screenSharing = false,
    this.handRaised = false,
  });
}

class CallChatMessage {
  final String text;
  final bool mine;
  final DateTime time;

  CallChatMessage({required this.text, required this.mine, required this.time});
}

class CallSession {
  final Ws2Config ws2Config;

  final ConversationParams? params;
  final CallRole role;

  CallSession({required this.ws2Config, required this.role, this.params});

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
  bool _remoteDescSet = false;
  bool _ownRemoteStream = false;
  final List<RTCIceCandidate> _pendingCandidates = [];
  Future<void> _tail = Future.value();

  final Map<int, CallParticipant> _participants = {};

  String? _topology;
  List _iceServers = const [];
  Object? _sfuSessionId;
  Set<int> _speaking = const {};

  bool _localVideo = false;
  bool _localScreen = false;
  MediaStream? _localVideoStream;
  RTCRtpSender? _videoSender;

  Timer? _levelTimer;
  final Map<int, int> _speakHold = {};

  static const double _speakLevelOn = 0.05;
  static const int _speakHoldTicks = 3;

  RTCDataChannel? _probeChannel;
  bool _peerIsKomet = false;

  static const String _probeQuestion = 'AreYouKomet?';
  static const String _probeAnswer = 'YesImKomet😎';

  final List<CallChatMessage> _chat = [];
  final _chatController = StreamController<CallChatMessage>.broadcast();
  final _gameController = StreamController<Map<String, dynamic>>.broadcast();

  List<CallChatMessage> get chatLog => List.unmodifiable(_chat);
  Stream<CallChatMessage> get chatMessages => _chatController.stream;
  Stream<Map<String, dynamic>> get gameMessages => _gameController.stream;

  int get selfUserId => ws2Config.userId;
  int? get peerUserId => _peerId;

  bool get localVideo => _localVideo;
  bool get localScreen => _localScreen;
  MediaStream? get localVideoStream => _localVideoStream;

  List<CallParticipant> get participants =>
      _participants.values.toList(growable: false);

  int get participantCount => _participants.length;

  bool isSpeaking(int id) => _speaking.contains(id);

  String? get topology => _topology;

  bool get _wantVideo => params?.isVideo == true;

  final CallInfo info = CallInfo();

  final _state = StreamController<CallSessionState>.broadcast();
  final _remoteStream = StreamController<MediaStream>.broadcast();
  final _info = StreamController<void>.broadcast();
  final _kometDetected = StreamController<void>.broadcast();

  Stream<CallSessionState> get stateStream => _state.stream;
  Stream<MediaStream> get remoteStreamStream => _remoteStream.stream;
  MediaStream? get remoteStream => _remoteStreamRef;

  Stream<void> get infoUpdates => _info.stream;

  Stream<void> get peerKometDetected => _kometDetected.stream;
  bool get peerIsKomet => _peerIsKomet;

  bool get isMuted => _muted;
  bool get peerMuted => _peerMuted;
  bool get peerVideo => _peerVideo;
  bool get mediaConnected => _mediaConnected;

  CallSessionState _current = CallSessionState.connecting;
  DateTime? _activeSince;

  CallSessionState get currentState => _current;

  int get elapsedSeconds => _activeSince == null
      ? 0
      : DateTime.now().difference(_activeSince!).inSeconds;

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
    signaling.notifications.listen(_enqueue, onError: (_) => _end());
    signaling.done.then((_) => _end());
    await signaling.connect();
    _levelTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => unawaited(_sampleLevels()),
    );
  }

  Future<void> _sampleLevels() async {
    final pc = _pc;
    if (pc == null || _ended) return;
    if (!_mediaConnected || _current != CallSessionState.active) return;

    var local = 0.0;
    var remote = 0.0;
    try {
      for (final r in await pc.getStats()) {
        final lvl = r.values['audioLevel'];
        if (lvl is! num) continue;
        final kind = r.values['kind'] ?? r.values['mediaType'];
        if (kind != 'audio') continue;
        if (r.type == 'media-source') {
          local = lvl.toDouble();
        } else if (r.type == 'inbound-rtp') {
          final v = lvl.toDouble();
          if (v > remote) remote = v;
        }
      }
    } catch (_) {
      return;
    }

    final loud = <int>{};
    if (!_muted && local > _speakLevelOn) loud.add(ws2Config.userId);
    final others = _participants.values.where((p) => !p.isSelf).toList();
    if (others.length == 1 && remote > _speakLevelOn) loud.add(others.first.id);

    for (final id in loud) {
      _speakHold[id] = _speakHoldTicks;
    }
    _speakHold.updateAll((id, ticks) => loud.contains(id) ? ticks : ticks - 1);
    _speakHold.removeWhere((_, ticks) => ticks <= 0);

    final next = _speakHold.keys.toSet();
    if (next.length != _speaking.length || !next.containsAll(_speaking)) {
      _speaking = next;
      _notifyInfo();
    }
  }

  void _enqueue(Map<String, dynamic> msg) {
    _tail = _tail.then((_) => _onNotification(msg)).catchError((_) {});
  }

  Future<void> _onNotification(Map<String, dynamic> msg) async {
    if (msg['type'] == 'error') {
      _onWs2Error(msg);
      return;
    }
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
      case 'participant-joined':
      case 'media-settings-changed':
        _onParticipantMedia(msg);
        break;
      case 'participant-state-changed':
        _onParticipantStateChanged(msg);
        break;
      case 'participants-state-changed':
        _onParticipantsStateChanged(msg);
        break;
      case 'participant-left':
      case 'participant-removed':
        _onParticipantLeft(msg);
        break;
      case 'force-media-settings-change':
      case 'switch-micro':
        _onForcedMedia(msg);
        break;
      case 'mute-participant':
        _onMuteParticipant(msg);
        break;
      case 'hungup':
        _onHungup(msg);
        break;
      case 'topology-changed':
        await _onTopologyChanged(msg);
        break;
      case 'producer-updated':
        await _onProducerUpdated(msg);
        break;
      case 'session-state':
        _onSessionState(msg);
        break;
      case 'closed-conversation':
        _end();
        break;
    }
  }

  void _onWs2Error(Map<String, dynamic> msg) {
    final err = msg['error'];
    logger.t('[call] ws2 error: $err');
    if (err == 'conversation-ended') _end();
  }

  int? _participantIdFrom(Object? raw) {
    if (raw is int) return raw;
    if (raw is! String) return null;
    for (final seg in raw.split(':')) {
      if (seg.isEmpty) continue;
      final c = seg[0];
      if (c == 'u' || c == 'g') {
        final v = int.tryParse(seg.substring(1));
        if (v != null) return v;
      } else if (c != 'd') {
        final v = int.tryParse(seg);
        if (v != null) return v;
      }
    }
    return null;
  }

  void _onForcedMedia(Map<String, dynamic> msg) {
    bool? audioOn;
    final ms = msg['mediaSettings'];
    if (ms is Map && ms['isAudioEnabled'] is bool) {
      audioOn = ms['isAudioEnabled'] as bool;
    }
    final muteStates = msg['muteStates'];
    if (muteStates is Map && muteStates['AUDIO'] is String) {
      audioOn = muteStates['AUDIO'] == 'UNMUTE';
    }
    final mute = msg['mute'];
    if (mute is bool) audioOn = !mute;
    if (audioOn == null) return;
    logger.t('[call] forced media audioEnabled=$audioOn raw=$msg');
    _applyMuted(!audioOn);
  }

  void _onMuteParticipant(Map<String, dynamic> msg) {
    final muteStates = msg['muteStates'];
    if (muteStates is! Map || muteStates['AUDIO'] is! String) return;
    final audioOn = muteStates['AUDIO'] == 'UNMUTE';
    final target = _participantIdFrom(msg['participantId']);
    final muteAll = msg['muteAll'] == true;

    if (target != null) {
      final p = _participants[target];
      if (p != null) {
        p.audioEnabled = audioOn;
        _notifyInfo();
      }
    }
    if (muteAll || target == null || target == ws2Config.userId) {
      _applyMuted(!audioOn);
    }
  }

  void _onHungup(Map<String, dynamic> msg) {
    final raw =
        msg['participantId'] ??
        (msg['participant'] is Map ? (msg['participant'] as Map)['id'] : null);
    if (raw is! int) return;
    if (raw == ws2Config.userId) {
      _end();
      return;
    }
    if (_participants.remove(raw) != null) _notifyInfo();
  }

  void _onSessionState(Map<String, dynamic> msg) {
    logger.t(
      '[call][sfu] session-state id=${msg['participantId']} connected=${msg['connected']}',
    );
  }

  void _resolveParticipants(Object? conversation) {
    if (conversation is! Map) return;
    final list = conversation['participants'];
    if (list is! List) return;
    final seen = <int>{};
    for (final p in list.whereType<Map>()) {
      final id = p['id'];
      if (id is! int) continue;
      seen.add(id);
      _upsertParticipant(
        id,
        externalId: _externalId(p['externalId']),
        state: p['state'] as String?,
        mediaSettings: p['mediaSettings'],
        muteStates: p['muteStates'],
      );
    }
    _participants.removeWhere((key, _) => !seen.contains(key));
    _notifyInfo();
  }

  CallParticipant _upsertParticipant(
    int id, {
    int? externalId,
    String? state,
    Object? mediaSettings,
    Object? muteStates,
    bool? handRaised,
  }) {
    final p = _participants.putIfAbsent(
      id,
      () => CallParticipant(id: id, isSelf: id == ws2Config.userId),
    );
    if (externalId != null) p.externalId = externalId;
    if (state != null) p.state = state;
    if (mediaSettings is Map) {
      final a = mediaSettings['isAudioEnabled'];
      final v = mediaSettings['isVideoEnabled'];
      final s = mediaSettings['isScreenSharingEnabled'];
      if (a is bool) p.audioEnabled = a;
      if (v is bool) p.videoEnabled = v;
      if (s is bool) p.screenSharing = s;
    }
    if (muteStates is Map) {
      final a = muteStates['AUDIO'];
      final v = muteStates['VIDEO'];
      final s = muteStates['SCREEN_SHARING'];
      if (a is String) p.audioEnabled = a == 'UNMUTE';
      if (v is String) p.videoEnabled = v == 'UNMUTE';
      if (s is String) p.screenSharing = s == 'UNMUTE';
    }
    if (handRaised != null) p.handRaised = handRaised;
    return p;
  }

  int? _externalId(Object? ext) {
    if (ext is! Map) return null;
    return parseIntOrNull(ext['id']);
  }

  bool? _handFrom(Object? participantState) {
    if (participantState is! Map) return null;
    final state = participantState['state'];
    if (state is! Map || !state.containsKey('hand')) return null;
    return state['hand'] == '1' || state['hand'] == true;
  }

  void _onParticipantMedia(Map<String, dynamic> msg) {
    final id = _participantIdFrom(msg['participantId']);
    if (id == null) return;
    _upsertParticipant(
      id,
      externalId: _externalId(msg['externalId']),
      mediaSettings: msg['mediaSettings'],
      muteStates: msg['muteStates'],
    );
    _maybeAdoptPeer(msg);
    _notifyInfo();
  }

  void _maybeAdoptPeer(Map<String, dynamic> msg) {
    if (role != CallRole.joiner || _peerId != null || _pc == null) return;
    if (_topology == 'SERVER') return;
    final id = msg['participantId'];
    if (id is! int || id == ws2Config.userId) return;
    _peerId = id;
    final type = msg['participantType'];
    if (type is String && type.isNotEmpty) _peerType = type;
    final deviceIdx = msg['deviceIdx'];
    if (deviceIdx is int) _peerDeviceIdx = deviceIdx;
    logger.t('[call] adopting peer $_peerId on join');
    unawaited(_createAndSendOffer());
  }

  void _onParticipantStateChanged(Map<String, dynamic> msg) {
    final id = msg['participantId'];
    if (id is! int) return;
    _upsertParticipant(id, handRaised: _handFrom(msg['participantState']));
    _notifyInfo();
  }

  void _onParticipantsStateChanged(Map<String, dynamic> msg) {
    final list = msg['participants'];
    if (list is! List) return;
    for (final p in list.whereType<Map>()) {
      final id = _participantIdFrom(p['participantId'] ?? p['id']);
      if (id == null) continue;
      _upsertParticipant(
        id,
        externalId: _externalId(p['externalId']),
        state: p['state'] as String?,
        mediaSettings: p['mediaSettings'],
        muteStates: p['muteStates'],
        handRaised: _handFrom(p['participantState']),
      );
    }
    _notifyInfo();
  }

  void _onParticipantLeft(Map<String, dynamic> msg) {
    final id = msg['participantId'];
    if (id is! int) return;
    if (_participants.remove(id) != null) _notifyInfo();
  }

  Future<void> _onConnection(Map<String, dynamic> msg) async {
    final convParams = msg['conversationParams'];
    final conversation = msg['conversation'];

    final ice = _iceServersFrom(convParams) ?? params?.iceServers ?? const [];
    _iceServers = ice;
    _resolvePeer(conversation);
    _resolveParticipants(conversation);
    _applyConnectionInfo(msg, ice);

    _topology =
        (conversation is Map ? conversation['topology']?.toString() : null) ??
        _topology;
    logger.t('[call] connection role=$role peer=$_peerId topology=$_topology');

    if (_topology == 'SERVER') {
      await _setupSfu();
      return;
    }

    final pc = await _createPc(ice);
    _pc = pc;
    await _addLocalMedia(pc);

    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    await _setupKometProbe(pc);

    if (_isDesktop) await _preferVp8Codecs(pc);

    if (role == CallRole.caller) {
      _setState(CallSessionState.ringing);
      await _createAndSendOffer();
    } else if (role == CallRole.joiner) {
      await _createAndSendOffer();
    }
  }

  Future<RTCPeerConnection> _createPc(List ice) async {
    final pc = await createPeerConnection({
      'iceServers': ice,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
    });
    pc.onIceCandidate = _onLocalCandidate;
    pc.onTrack = (event) => unawaited(_onRemoteTrack(event));
    pc.onDataChannel = (channel) => _bindProbeChannel(channel, ask: false);
    pc.onIceConnectionState = (s) => logger.t('[call] ice $s');
    pc.onConnectionState = (s) {
      logger.t('[call] pc $s');
      final connected =
          s == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (connected != _mediaConnected) {
        _mediaConnected = connected;
        _notifyInfo();
        if (connected) {
          if (role == CallRole.joiner || _topology == 'SERVER') {
            _setState(CallSessionState.active);
          }
          unawaited(_resolvePath());
          unawaited(_collectReceivers());
        }
      }
      if ((s == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
              s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) &&
          _topology != 'SERVER') {
        _end();
      }
    };
    return pc;
  }

  Future<void> _addLocalMedia(RTCPeerConnection pc) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': _wantVideo,
    });
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }
  }

  Future<void> _setupKometProbe(RTCPeerConnection pc) async {
    if (_topology == 'SERVER') return;
    try {
      final channel = await pc.createDataChannel(
        'komet',
        RTCDataChannelInit()..ordered = true,
      );
      _probeChannel = channel;
      _bindProbeChannel(channel, ask: true);
    } catch (_) {}
  }

  void _bindProbeChannel(RTCDataChannel channel, {required bool ask}) {
    channel.onMessage = (message) => _onProbeMessage(channel, message);
    channel.onDataChannelState = (state) {
      if (ask && state == RTCDataChannelState.RTCDataChannelOpen) {
        _sendProbe(channel, _probeQuestion);
      }
    };
  }

  void _onProbeMessage(RTCDataChannel channel, RTCDataChannelMessage message) {
    if (message.isBinary) return;
    final text = message.text;

    final frame = _decodeFrame(text);
    if (frame != null && frame['t'] == 'chat') {
      final body = frame['text'];
      if (body is String && body.isNotEmpty) {
        _addChat(
          CallChatMessage(text: body, mine: false, time: DateTime.now()),
        );
      }
      return;
    }
    if (frame != null && frame['t'] == 'game') {
      final data = Map<String, dynamic>.of(frame)..remove('t');
      if (!_gameController.isClosed) _gameController.add(data);
      return;
    }

    if (text == _probeQuestion) {
      _sendProbe(channel, _probeAnswer);
    } else if (text == _probeAnswer) {
      _markPeerKomet();
    }
  }

  Map<String, dynamic>? _decodeFrame(String text) {
    try {
      final v = jsonDecode(text);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  void _sendProbe(RTCDataChannel channel, String text) {
    try {
      channel.send(RTCDataChannelMessage(text));
    } catch (_) {}
  }

  void sendChatMessage(String text) {
    final body = text.trim();
    final channel = _probeChannel;
    if (body.isEmpty || channel == null) return;
    try {
      channel.send(
        RTCDataChannelMessage(jsonEncode({'t': 'chat', 'text': body})),
      );
    } catch (_) {
      return;
    }
    _addChat(CallChatMessage(text: body, mine: true, time: DateTime.now()));
  }

  void sendGame(Map<String, dynamic> data) {
    final channel = _probeChannel;
    if (channel == null) return;
    try {
      channel.send(RTCDataChannelMessage(jsonEncode({'t': 'game', ...data})));
    } catch (_) {}
  }

  void _addChat(CallChatMessage message) {
    _chat.add(message);
    if (!_chatController.isClosed) _chatController.add(message);
  }

  void _markPeerKomet() {
    if (_peerIsKomet) return;
    _peerIsKomet = true;
    logger.t('[call] peer is Komet');
    if (!_kometDetected.isClosed) _kometDetected.add(null);
    _notifyInfo();
  }

  Future<void> _setupSfu() async {
    if (_pc != null) {
      await _pc!.close();
      _pc = null;
      _probeChannel = null;
      _remoteDescSet = false;
      _pendingCandidates.clear();
      for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
      await _localStream?.dispose();
      _localStream = null;
      _videoSender = null;
      await _disposeLocalVideoStream();
      _localVideo = false;
      _localScreen = false;
    }
    _setState(CallSessionState.connecting);
    final pc = await _createPc(_iceServers);
    _pc = pc;
    await _addLocalMedia(pc);
    logger.t('[call][sfu] allocate-consumer');
    await _signaling?.allocateConsumer();
  }

  Future<void> _onTopologyChanged(Map<String, dynamic> msg) async {
    final topo = msg['topology']?.toString();
    if (topo == null) return;
    logger.t('[call] topology-changed -> $topo');
    info.topology = topo;
    final switchingToSfu = topo == 'SERVER' && _topology != 'SERVER';
    _topology = topo;
    _notifyInfo();
    if (switchingToSfu) await _setupSfu();
  }

  Future<void> _onProducerUpdated(Map<String, dynamic> msg) async {
    final pc = _pc;
    if (pc == null) return;

    final session = msg['sessionId'];
    if (session != null) _sfuSessionId = session;

    final description = msg['description'];
    String? sdp;
    var type = 'offer';
    if (description is Map) {
      sdp = (description['sdp'] ?? description['description']) as String?;
      type = (description['type'] as String?) ?? 'offer';
    } else if (description is String) {
      sdp = description;
    }
    if (sdp == null) {
      logger.t('[call][sfu] producer-updated without sdp: $msg');
      return;
    }

    logger.t('[call][sfu] producer offer: ${_mLines(sdp)} m-lines');
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescSet = true;
    await _flushCandidates();

    final answer = await pc.createAnswer({});
    await pc.setLocalDescription(answer);
    await _waitIceGathering(pc, const Duration(seconds: 3));

    final local = await pc.getLocalDescription();
    final answerSdp = local?.sdp ?? answer.sdp ?? '';
    final ssrcs = _extractSsrcs(answerSdp);
    logger.t(
      '[call][sfu] answer: ${_mLines(answerSdp)} m-lines, '
      'ssrcs=${ssrcs.length}',
    );

    await _signaling?.acceptProducer(
      description: answerSdp,
      ssrcs: ssrcs,
      sessionId: _sfuSessionId,
    );

    if (_wantVideo) await _publishCamera();
    unawaited(_collectReceivers());
  }

  Future<void> _publishCamera() async {
    try {
      await _signaling?.changeSimulcast(
        mediaSource: 'CAMERA',
        layers: const [
          {
            'rid': 'h',
            'width': 1280,
            'height': 720,
            'fps': 30,
            'bitrateKbps': 2000,
          },
        ],
      );
    } catch (_) {}
  }

  int _mLines(String sdp) =>
      RegExp(r'^m=', multiLine: true).allMatches(sdp).length;

  List<int> _extractSsrcs(String sdp) {
    final set = <int>{};
    for (final m in RegExp(r'^a=ssrc:(\d+)', multiLine: true).allMatches(sdp)) {
      final v = int.tryParse(m.group(1) ?? '');
      if (v != null) set.add(v);
    }
    return set.toList();
  }

  Future<void> _waitIceGathering(RTCPeerConnection pc, Duration timeout) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final completer = Completer<void>();
    Timer? timer;
    void finish() {
      if (!completer.isCompleted) completer.complete();
    }

    pc.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) finish();
    };
    timer = Timer(timeout, finish);
    await completer.future;
    timer.cancel();
    pc.onIceGatheringState = null;
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
      '[call] remote track: ${event.track.kind} streams=${event.streams.length}',
    );
    if (event.streams.isNotEmpty) {
      _remoteStreamRef = event.streams.first;
      _remoteStream.add(event.streams.first);
    } else {
      await _collectReceivers();
    }
  }

  Future<void> _pushRemoteTrack(MediaStreamTrack track) async {
    var stream = _remoteStreamRef;
    if (stream == null) {
      stream = await createLocalMediaStream('komet_remote');
      _ownRemoteStream = true;
    }
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
    final sdp = offer.sdp ?? '';
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

  Future<void> _preferVp8Codecs(RTCPeerConnection pc) async {
    try {
      final caps = await getRtpSenderCapabilities('video');
      final all = caps.codecs ?? const <RTCRtpCodecCapability>[];
      final hasVp8 = all.any((c) => c.mimeType.toLowerCase() == 'video/vp8');
      if (!hasVp8) return;
      final preferred = all.where((c) {
        final m = c.mimeType.toLowerCase();
        return m == 'video/vp8' || m == 'video/rtx';
      }).toList();
      if (preferred.isEmpty) return;
      for (final t in await pc.getTransceivers()) {
        try {
          await t.setCodecPreferences(preferred);
        } catch (_) {}
      }
    } catch (e) {
      logger.t('[call] setCodecPreferences недоступен: $e');
    }
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
      _remoteDescSet = true;
      await _flushCandidates();

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
      final ice = RTCIceCandidate(
        candidate['candidate'] as String?,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      );
      if (_remoteDescSet) {
        try {
          await pc.addCandidate(ice);
        } catch (_) {}
      } else {
        _pendingCandidates.add(ice);
      }
    }
  }

  Future<void> _flushCandidates() async {
    final pc = _pc;
    if (pc == null || _pendingCandidates.isEmpty) return;
    final pending = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final c in pending) {
      try {
        await pc.addCandidate(c);
      } catch (_) {}
    }
  }

  void _onLocalCandidate(RTCIceCandidate candidate) {
    if (_topology == 'SERVER') return;
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
    await _sendMediaSettings();
    _setState(CallSessionState.active);
  }

  Future<void> sendAudioEnabledSignal(bool enabled) async {
    await _signaling?.changeMediaSettings(isAudioEnabled: enabled);
  }

  Future<void> setMuted(bool muted) async {
    await _applyMuted(muted, announce: true);
  }

  Future<void> _applyMuted(bool muted, {bool announce = false}) async {
    _muted = muted;
    for (final track
        in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    _notifyInfo();
    if (announce) await _sendMediaSettings();
  }

  Future<void> _sendMediaSettings() async {
    await _signaling?.changeMediaSettings(
      isAudioEnabled: !_muted,
      isVideoEnabled: _localVideo,
      isScreenSharingEnabled: _localScreen,
    );
  }

  Future<void> setVideoEnabled(bool on) =>
      on ? _startLocalVideo(screen: false) : _stopLocalVideo();

  Future<void> setScreenSharing(bool on) =>
      on ? _startLocalVideo(screen: true) : _stopLocalVideo();

  Future<void> _startLocalVideo({required bool screen}) async {
    final pc = _pc;
    if (pc == null) return;

    MediaStream stream;
    try {
      stream = screen
          ? await navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
              'video': true,
              'audio': false,
            })
          : await navigator.mediaDevices.getUserMedia(<String, dynamic>{
              'video': true,
              'audio': false,
            });
    } catch (e) {
      logger.t('[call] video capture failed: $e');
      return;
    }

    await _disposeLocalVideoStream();
    _localVideoStream = stream;

    final tracks = stream.getVideoTracks();
    final track = tracks.isEmpty ? null : tracks.first;
    if (track != null) {
      if (_videoSender == null) {
        _videoSender = await pc.addTrack(track, stream);
      } else {
        await _videoSender!.replaceTrack(track);
      }
    }

    _localVideo = !screen;
    _localScreen = screen;

    if (_topology != 'SERVER') await _createAndSendOffer();
    await _sendMediaSettings();
    _notifyInfo();
  }

  Future<void> _stopLocalVideo() async {
    try {
      await _videoSender?.replaceTrack(null);
    } catch (_) {}
    await _disposeLocalVideoStream();
    _localVideo = false;
    _localScreen = false;
    await _sendMediaSettings();
    _notifyInfo();
  }

  Future<void> _disposeLocalVideoStream() async {
    final stream = _localVideoStream;
    _localVideoStream = null;
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await stream.dispose();
    } catch (_) {}
  }

  Future<void> hangup({String? reason}) async {
    final r = reason ?? _autoHangupReason();
    try {
      await _signaling?.hangup(reason: r);
    } catch (_) {}
    _end();
  }

  String _autoHangupReason() {
    if (_current != CallSessionState.active) {
      if (role == CallRole.caller) return 'CANCELED';
      if (role == CallRole.callee && !_accepted) return 'REJECTED';
    }
    return 'HUNGUP';
  }

  bool _ended = false;
  void _end() {
    if (_ended) return;
    _ended = true;
    _setState(CallSessionState.ended);
    _dispose();
  }

  Future<void> _dispose() async {
    _levelTimer?.cancel();
    try {
      await _probeChannel?.close();
    } catch (_) {}
    _probeChannel = null;
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _disposeLocalVideoStream();
    await _pc?.close();
    if (_ownRemoteStream) {
      try {
        await _remoteStreamRef?.dispose();
      } catch (_) {}
    }
    await _signaling?.close();
    if (!_state.isClosed) await _state.close();
    if (!_remoteStream.isClosed) await _remoteStream.close();
    if (!_info.isClosed) await _info.close();
    if (!_kometDetected.isClosed) await _kometDetected.close();
    if (!_chatController.isClosed) await _chatController.close();
    if (!_gameController.isClosed) await _gameController.close();
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
        if (deviceIdxs is List &&
            deviceIdxs.isNotEmpty &&
            deviceIdxs.first is int) {
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
