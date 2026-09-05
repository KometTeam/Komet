import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_microphone.dart';
import '../config/app_pulse_source.dart';
import '../config/call_no_mute.dart';
import '../utils/logger.dart';
import '../utils/parse.dart';
import 'audio_devices.dart';
import 'call_admin.dart';
import 'call_bridge.dart';
import 'call_info.dart';
import 'conversation_params.dart';
import 'pulse_audio.dart';
import 'sfu_data_channel.dart';
import 'ws2_signaling.dart';

// #***! кто мы в звонке
enum CallRole { caller, callee, joiner }

// #***! состояние звонка от подключения до конца
enum CallSessionState { connecting, ringing, active, ended }

// #***! участник звонка, медиа роли и поднятая рука
class CallParticipant {
  final int id;
  final bool isSelf;
  int? externalId;
  String state;
  bool audioEnabled;
  bool videoEnabled;
  bool screenSharing;
  bool handRaised;
  List<String> roles;

  CallParticipant({
    required this.id,
    this.isSelf = false,
    this.externalId,
    this.state = '',
    this.audioEnabled = true,
    this.videoEnabled = false,
    this.screenSharing = false,
    this.handRaised = false,
    this.roles = const [],
  });

  bool get isAdmin => roles.contains('ADMIN') || roles.contains('CREATOR');
  bool get isCreator => roles.contains('CREATOR');
  bool get isSpeaker => roles.contains('SPEAKER');
}

// #***! сообщение в чате звонка
class CallChatMessage {
  final String text;
  final bool mine;
  final DateTime time;

  CallChatMessage({required this.text, required this.mine, required this.time});
}

// #***! весь звонок целиком, сигналка WebRTC участники чат и переподключения
class CallSession {
  final Ws2Config ws2Config;

  final ConversationParams? params;
  final CallRole role;
  final bool isGroup;

  CallSession({
    required this.ws2Config,
    required this.role,
    this.params,
    this.isGroup = false,
  });

  Ws2Signaling? _signaling;
  // #***! _pc это единственное соединение, в SFU оно пересоздаётся
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  MediaStream? _micStream;
  MediaStream? _remoteStreamRef;

  int? _peerId;
  String _peerType = 'USER';
  int _peerDeviceIdx = 0;

  // #***! флаги своей и чужой стороны
  bool _muted = false;
  bool _speakerOn = false;
  bool _accepted = false;
  bool _peerMuted = false;
  bool _peerVideo = false;
  bool _mediaConnected = false;
  bool _remoteDescSet = false;
  bool _ownRemoteStream = false;
  // #***! кандидаты пришедшие до remote SDP придерживаем тут
  final List<RTCIceCandidate> _pendingCandidates = [];
  Future<void> _tail = Future.value();

  // #***! участники и их видео, экран звонка подписан
  final Map<int, CallParticipant> _participants = {};
  final Map<int, MediaStream> _participantStreams = {};
  final _participantStreamUpdates = StreamController<int>.broadcast();

  String? _topology;
  List _iceServers = const [];
  Object? _sfuSessionId;
  Set<int> _speaking = const {};

  bool _localVideo = false;
  bool _localScreen = false;
  MediaStream? _cameraStream;
  MediaStream? _screenStream;
  // #***! отправители аудио камеры и экрана, треки подменяем на лету
  RTCRtpSender? _audioSender;
  RTCRtpSender? _videoSender;
  RTCRtpSender? _screenSender;
  String? _micDeviceId = AppMicrophone.deviceId;
  String? _pulseSource = AppPulseSource.name;
  bool _monitorCapture = false;

  Completer<void>? _gatherDone;
  // #***! автопереподключение, до 12 попыток с растущей задержкой
  bool _gotConnection = false;

  bool _reconnecting = false;
  bool _iceRestarting = false;
  int _iceRestarts = 0;
  static const int _maxIceRestarts = 6;
  static const int _maxReconnectAttempts = 12;
  static const Duration _maxReconnectDelay = Duration(seconds: 20);

  bool get isReconnecting => _reconnecting;

  Timer? _levelTimer;
  // #***! говорящего ловим по уровню звука с удержанием, иначе мигает
  final Map<int, int> _speakHold = {};

  static const double _speakLevelOn = 0.05;
  static const int _speakHoldTicks = 3;

  // #***! проба ты тоже комет, сейчас выключена
  RTCDataChannel? _probeChannel;
  bool _peerIsKomet = false;

  // #***! каналы SFU, раскладка слоты и уровни
  final List<RTCDataChannel> _sfuChannels = [];
  SfuCommandChannel? _sfuCommands;
  StreamSubscription<Map<String, int>>? _sfuSlotSub;
  StreamSubscription<Map<String, int>>? _sfuLevelSub;
  final Map<int, int> _slotParticipant = {};
  Timer? _layoutDebounce;
  Timer? _videoStatsTimer;
  List<String> _lastLayout = const [];
  bool _layoutSent = false;

  // #***! не больше 10 видеослотов, дальше сеть не тянет
  static const int _maxVideoSlots = 10;
  static const int _sfuSpeakLevel = 50;
  static const Duration _levelTtl = Duration(seconds: 6);
  final Map<int, ({int level, DateTime at})> _levelState = {};

  static const List<String> _sfuChannelLabels = [
    'producerCommand',
    'producerNotification',
  ];

  static const bool _kometProbeEnabled = false;
  static const String _probeQuestion = 'AreYouKomet?';
  static const String _probeAnswer = 'YesImKomet😎';

  // #***! чат и игра идут по тому же каналу
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
  MediaStream? get localVideoStream =>
      _localScreen ? _screenStream : _cameraStream;
  MediaStream? get localCameraStream => _cameraStream;
  MediaStream? get localScreenStream => _screenStream;

  CallAdmin? get admin {
    final signaling = _signaling;
    return signaling == null ? null : CallAdmin(signaling);
  }

  List<CallParticipant> get participants =>
      _participants.values.toList(growable: false);

  Map<int, MediaStream> get participantStreams =>
      Map.unmodifiable(_participantStreams);

  Stream<int> get participantStreamUpdates => _participantStreamUpdates.stream;

  MediaStream? streamOf(int participantId) =>
      _participantStreams[participantId];

  int get participantCount => _participants.length;

  bool isSpeaking(int id) => _speaking.contains(id);

  String? get topology => _topology;

  bool get _wantVideo => params?.isVideo == true;

  final CallInfo info = CallInfo();

  // #***! стримы наружу
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
  bool get audioTransmitting => !_muted || CallNoMute.enabled;
  String? get micDeviceId => _micDeviceId;
  String? get pulseSource => _pulseSource;
  bool get isSpeaker => _speakerOn;
  bool get peerMuted => _peerMuted;
  bool get peerVideo => _peerVideo;
  bool get mediaConnected => _mediaConnected;

  CallSessionState _current = CallSessionState.connecting;
  DateTime? _activeSince;

  CallSessionState get currentState => _current;

  int get elapsedSeconds => _activeSince == null
      ? 0
      : DateTime.now().difference(_activeSince!).inSeconds;

  // #***! смена состояния с оповещением юишки
  void _setState(CallSessionState s) {
    if (_current == s || _current == CallSessionState.ended) return;
    if (s == CallSessionState.active) _activeSince ??= DateTime.now();
    _current = s;
    _state.add(s);
  }

  void _notifyInfo() {
    if (!_info.isClosed) _info.add(null);
    if (_topology == 'SERVER') _scheduleDisplayLayout();
  }

  // #***! главный вход, поднимаем сигналку и медиа
  Future<void> start() async {
    _setState(CallSessionState.connecting);
    info.region = ws2Config.uri.host;
    await _openSignaling();
    _levelTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => unawaited(_sampleLevels()),
    );
  }

  // #***! подключение к ws2
  Future<void> _openSignaling() async {
    final signaling = Ws2Signaling(ws2Config);
    _signaling = signaling;
    signaling.notifications.listen(
      _enqueue,
      onError: (_) => _onSignalingLost(),
    );
    signaling.done.then((_) => _onSignalingLost());
    await signaling.connect();
    logger.i('[call] signaling connected to ${ws2Config.uri.host}');
    logger.i('[call] ws2 url ${_maskedUrl()}');
    unawaited(_wakeSignalingIfSilent(signaling));
    Timer(const Duration(seconds: 10), () {
      if (_ended || _gotConnection) return;
      logger.w(
        '[call] ws2 молчит 10 с: нотификация "connection" не пришла — '
        'конференция закрыта или токен протух',
      );
    });
  }

  // #***! адрес в логах маскируем, в нём токен
  String _maskedUrl() {
    final token = ws2Config.uri.queryParameters['token'];
    if (token == null || token.length < 12) return ws2Config.uri.toString();
    final masked =
        '${token.substring(0, 4)}…${token.substring(token.length - 6)}';
    return ws2Config.uri.toString().replaceAll(
      Uri.encodeQueryComponent(token),
      masked,
    );
  }

  // #***! сигналка молчит, дёргаем командой иначе висим до таймаута
  /// Кадры ws2 приходят в broadcast-канал Rust-ядра, а подписка на него
  /// создаётся уже после того, как сокет открыт: нотификацию `connection`,
  /// присланную сразу после хэндшейка, ядро выбрасывает. Если её нет — толкаем
  /// сервер командой (ответы идут по sequence и гонке не подвержены).
  Future<void> _wakeSignalingIfSilent(Ws2Signaling signaling) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_ended || _gotConnection || _signaling != signaling) return;

    logger.w('[call] "connection" не пришла за 1.2 с — бужу ws2');
    try {
      final response = await signaling.sendCommand(
        'change-media-settings',
        extra: {
          'mediaSettings': {
            'isVideoEnabled': _localVideo,
            'isAudioEnabled': !_muted,
            'isScreenSharingEnabled': _localScreen,
            'isAnimojiEnabled': false,
          },
        },
      );
      logger.i('[call] ws2 wake ok: $response');
    } catch (e) {
      logger.w('[call] ws2 wake failed: $e');
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (_ended || _gotConnection || _signaling != signaling) return;

    logger.w('[call] всё ещё тихо — шлю accept-call вслепую');
    try {
      await accept(activate: false);
    } catch (e) {
      logger.w('[call] accept-call failed: $e');
    }
  }

  // #***! обрыв сигналки
  void _onSignalingLost() {
    if (_ended || _reconnecting) return;
    logger.w('[call] signaling lost, reconnecting');
    unawaited(_reconnect());
  }

  // #***! переподключение с растущей задержкой
  Future<void> _reconnect() async {
    _reconnecting = true;
    _setState(CallSessionState.connecting);
    _notifyInfo();

    for (var attempt = 1; attempt <= _maxReconnectAttempts; attempt++) {
      final backoff = Duration(seconds: 1 << (attempt - 1));
      final delay = backoff > _maxReconnectDelay ? _maxReconnectDelay : backoff;
      await Future<void>.delayed(delay);
      if (_ended) break;

      logger.i('[call] reconnect attempt $attempt/$_maxReconnectAttempts');
      try {
        await _resetForReconnect();
        await _openSignaling();
        _reconnecting = false;
        return;
      } catch (e) {
        logger.w('[call] reconnect attempt $attempt failed: $e');
      }
    }

    _reconnecting = false;
    if (!_ended) {
      logger.w('[call] reconnect gave up');
      _end();
    }
  }

  // #***! сначала restart ICE, это дешевле полного пересоздания
  Future<void> _restartIce() async {
    if (_ended || _iceRestarting || _topology == 'SERVER') return;
    if (_iceRestarts >= _maxIceRestarts) {
      logger.w('[call] ice restart budget exhausted, ending call');
      _end();
      return;
    }
    _iceRestarting = true;
    _iceRestarts++;
    _setState(CallSessionState.connecting);
    _notifyInfo();
    logger.i('[call] ice restart $_iceRestarts/$_maxIceRestarts');
    try {
      _pendingCandidates.clear();
      await _createAndSendOffer(iceRestart: true);
    } catch (e) {
      logger.w('[call] ice restart failed: $e');
    } finally {
      _iceRestarting = false;
    }
  }

  // #***! полный сброс медиа перед новой попыткой
  Future<void> _resetForReconnect() async {
    try {
      await _signaling?.close();
    } catch (_) {}
    _signaling = null;

    try {
      await _probeChannel?.close();
    } catch (_) {}
    _probeChannel = null;
    await _closeSfuChannels();

    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;

    _audioSender = null;
    _videoSender = null;
    _screenSender = null;
    _remoteDescSet = false;
    _pendingCandidates.clear();
    _accepted = false;
    _mediaConnected = false;
    _sfuSessionId = null;
    await _clearParticipantStreams();

    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;
    await _disposeMicStream();

    await _disposeStream(_cameraStream);
    await _disposeStream(_screenStream);
    _cameraStream = null;
    _screenStream = null;
    _localVideo = false;
    _localScreen = false;
  }

  // #***! замер уровней звука для подсветки говорящего
  Future<void> _sampleLevels() async {
    final pc = _pc;
    if (pc == null || _ended || _topology == 'SERVER') return;
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
    if (audioTransmitting && local > _speakLevelOn) loud.add(ws2Config.userId);
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

  // #***! уведомления строго по очереди
  void _enqueue(Map<String, dynamic> msg) {
    _tail = _tail.then((_) => _onNotification(msg)).catchError((
      Object e,
      StackTrace st,
    ) {
      logger.w('[call] handler failed for ${msg['notification']}: $e\n$st');
    });
  }

  // #***! роутер уведомлений сигналки
  Future<void> _onNotification(Map<String, dynamic> msg) async {
    final name = msg['notification'] ?? msg['response'] ?? msg['type'];
    logger.i('[call] ws2 <- $name');
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
      case 'participant-added':
        _onParticipantJoined(msg);
        break;
      case 'media-settings-changed':
        _onParticipantMedia(msg);
        break;
      case 'participant-state-changed':
        _onParticipantStateChanged(msg);
        break;
      case 'roles-changed':
        _onRolesChanged(msg);
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

  // #***! сервер вернул ошибку
  void _onWs2Error(Map<String, dynamic> msg) {
    final err = msg['error'];
    logger.w('[call] ws2 error: $err raw=$msg');
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

  // #***! админ требует включить микрофон или камеру
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

  // #***! нас или другого замьютили
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

  // #***! звонок завершили с той стороны
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

  // #***! разбор состава участников
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
        roles: p['roles'],
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
    Object? roles,
  }) {
    final p = _participants.putIfAbsent(
      id,
      () => CallParticipant(id: id, isSelf: id == ws2Config.userId),
    );
    if (externalId != null) p.externalId = externalId;
    if (state != null) p.state = state;
    if (mediaSettings is Map) {
      p.audioEnabled = mediaSettings['isAudioEnabled'] == true;
      p.videoEnabled = mediaSettings['isVideoEnabled'] == true;
      p.screenSharing = mediaSettings['isScreenSharingEnabled'] == true;
    }
    if (muteStates is Map) {
      final a = muteStates['AUDIO'];
      final v = muteStates['VIDEO'];
      final s = muteStates['SCREEN_SHARING'];
      if (a is String && a != 'UNMUTE') p.audioEnabled = false;
      if (v is String && v != 'UNMUTE') p.videoEnabled = false;
      if (s is String && s != 'UNMUTE') p.screenSharing = false;
    }
    if (handRaised != null) p.handRaised = handRaised;
    if (roles is List) {
      p.roles = roles.whereType<String>().toList(growable: false);
    }
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

  // #***! участник включил или выключил медиа
  void _onParticipantMedia(Map<String, dynamic> msg) {
    final id = _participantIdFrom(msg['participantId']);
    if (id == null) return;
    final p = _upsertParticipant(
      id,
      externalId: _externalId(msg['externalId']),
      mediaSettings: msg['mediaSettings'],
      muteStates: msg['muteStates'],
    );
    logger.i(
      '[call] media $id video=${p.videoEnabled} audio=${p.audioEnabled} '
      'screen=${p.screenSharing} raw=${msg['mediaSettings']}',
    );
    _maybeAdoptPeer(id, msg);
    _notifyInfo();
  }

  // #***! кто то вошёл
  void _onParticipantJoined(Map<String, dynamic> msg) {
    final nested = msg['participant'];
    final p = nested is Map ? nested : msg;
    final id = _participantIdFrom(
      p['id'] ?? p['participantId'] ?? msg['participantId'],
    );
    if (id == null) return;
    _upsertParticipant(
      id,
      externalId: _externalId(p['externalId']),
      state: p['state'] as String?,
      mediaSettings: p['mediaSettings'],
      muteStates: p['muteStates'],
      handRaised: _handFrom(p['participantState']),
      roles: p['roles'],
    );
    _maybeAdoptPeer(id, p);
    _notifyInfo();
  }

  // #***! в звонке один на один второй это собеседник, запоминаем
  void _maybeAdoptPeer(int id, Map<dynamic, dynamic> source) {
    if (role != CallRole.joiner || _peerId != null || _pc == null) return;
    if (_topology == 'SERVER') return;
    if (id == ws2Config.userId) return;
    _peerId = id;
    final type = source['participantType'] ?? source['idType'];
    if (type is String && type.isNotEmpty) _peerType = type;
    final deviceIdx = source['deviceIdx'];
    if (deviceIdx is int) _peerDeviceIdx = deviceIdx;
    logger.t('[call] adopting peer $_peerId on join');
    unawaited(_createAndSendOffer());
  }

  // #***! сменились роли
  void _onRolesChanged(Map<String, dynamic> msg) {
    final id = _participantIdFrom(msg['participantId']);
    if (id == null) return;
    _upsertParticipant(id, roles: msg['roles']);
    _notifyInfo();
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
        roles: p['roles'],
      );
    }
    _notifyInfo();
  }

  // #***! участник вышел
  void _onParticipantLeft(Map<String, dynamic> msg) {
    final id = msg['participantId'];
    if (id is! int) return;
    if (_participants.remove(id) != null) _notifyInfo();
  }

  // #***! параметры медиа от сервера, отсюда начинается WebRTC
  Future<void> _onConnection(Map<String, dynamic> msg) async {
    _gotConnection = true;
    logger.i('[call] connection notification received');
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
    logger.i('[call] connection role=$role peer=$_peerId topology=$_topology');

    if (_topology == 'SERVER') {
      await accept(activate: role != CallRole.caller);
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
    await accept(activate: role != CallRole.caller);
  }

  // #***! создание RTCPeerConnection с ICE серверами
  Future<RTCPeerConnection> _createPc(List ice) async {
    final pc = await createPeerConnection({
      'iceServers': ice,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'tcpCandidatePolicy': 'enabled',
      'continualGatheringPolicy': 'gather_continually',
      'audioJitterBufferMaxPackets': 200,
    });
    pc.onIceCandidate = _onLocalCandidate;
    pc.onIceGatheringState = (s) {
      logger.i('[call] ice gathering $s');
      if (s != RTCIceGatheringState.RTCIceGatheringStateComplete) return;
      final done = _gatherDone;
      if (done != null && !done.isCompleted) done.complete();
    };
    pc.onTrack = (event) => unawaited(_onRemoteTrack(event));
    pc.onDataChannel = (channel) {
      if (!_kometProbeEnabled) return;
      _bindProbeChannel(channel, ask: false);
    };
    pc.onIceConnectionState = (s) {
      logger.i('[call] ice $s');
      if (s != RTCIceConnectionState.RTCIceConnectionStateFailed) return;
      if (_topology != 'SERVER' || _ended) return;
      unawaited(_dumpIceStats(pc));
      logger.w('[call][sfu] ice failed, request-realloc');
      unawaited(
        _signaling?.requestRealloc().catchError(
              (e) => logger.w('[call] request-realloc failed: $e'),
            ) ??
            Future.value(),
      );
    };
    pc.onConnectionState = (s) {
      logger.i('[call] pc $s');
      final connected =
          s == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      if (connected != _mediaConnected) {
        _mediaConnected = connected;
        _notifyInfo();
        if (connected) {
          _iceRestarts = 0;
          if (role == CallRole.joiner || _topology == 'SERVER') {
            _setState(CallSessionState.active);
          }
          unawaited(applyAudioRoute());
          unawaited(_resolvePath());
          unawaited(_collectReceivers());
        }
      }
      if (_topology == 'SERVER') return;
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _end();
        return;
      }
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        unawaited(_restartIce());
      }
    };
    return pc;
  }

  // #***! свои дорожки, микрофон всегда видео по требованию
  Future<void> _addLocalMedia(RTCPeerConnection pc) async {
    await _prepareAudioSession();
    await _disposeMicStream();
    try {
      await _prepareMicRoute();
    } catch (e) {
      logger.w(
        '[call][pulse] маршрут недоступен, беру устройство по умолчанию: $e',
      );
      await _resetMicRoute();
    }
    await _selectMicInsideEngine();
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': AudioDevices.micConstraints(
        _micDeviceId,
        monitorCapture: _monitorCapture,
      ),
      'video': _wantVideo,
    });
    for (final track in _localStream!.getTracks()) {
      final sender = await pc.addTrack(track, _localStream!);
      if (track.kind == 'audio') _audioSender = sender;
    }
    _applyAudioTracks();
    await applyAudioRoute();
  }

  // #***! на мобилках микрофон выбирает движок
  Future<void> _selectMicInsideEngine() async {
    final deviceId = _micDeviceId;
    if (deviceId == null || !AudioDevices.switchesInsideEngine) return;
    await AudioDevices.selectInput(deviceId);
  }

  Future<void> _disposeMicStream() async {
    final stream = _micStream;
    _micStream = null;
    await _disposeStream(stream);
  }

  List<MediaStreamTrack> get _audioTracks =>
      _micStream?.getAudioTracks() ??
      _localStream?.getAudioTracks() ??
      const <MediaStreamTrack>[];

  void _applyAudioTracks() {
    for (final track in _audioTracks) {
      track.enabled = audioTransmitting;
    }
  }

  // #***! на линуксе источник через PulseAudio а не через WebRTC
  Future<void> setPulseSource(String? sourceName) async {
    final previous = _pulseSource;
    final next = (sourceName == null || sourceName.isEmpty) ? null : sourceName;
    _pulseSource = next;
    if (next == null) await _resetMicRoute();
    try {
      await _replaceMicTrack();
    } catch (e) {
      _pulseSource = previous;
      await _resetMicRoute();
      rethrow;
    }
    await AppPulseSource.save(next ?? '');
    _notifyInfo();
  }

  Future<void> _resetMicRoute() async {
    _pulseSource = null;
    _monitorCapture = false;
    _micDeviceId = AppMicrophone.deviceId;
    await PulseAudio.closeBridge();
  }

  Future<void> _prepareMicRoute() async {
    final wanted = _pulseSource;
    if (!PulseAudio.supported || wanted == null) {
      _monitorCapture = false;
      await PulseAudio.closeBridge();
      return;
    }
    final source = await PulseAudio.find(wanted);
    if (source == null) {
      logger.w('[call][pulse] источник $wanted пропал');
      await _resetMicRoute();
      return;
    }
    _monitorCapture = source.isMonitor;
    if (!source.isMonitor) {
      final direct = await AudioDevices.findDevice(source.name);
      if (direct != null) {
        _micDeviceId = direct;
        await PulseAudio.closeBridge();
        return;
      }
    }
    final bridge = await PulseAudio.openBridge(source.name);
    final device = bridge == null
        ? null
        : await AudioDevices.findDevice(bridge, attempts: 8);
    if (device == null) {
      await PulseAudio.closeBridge();
      throw PulseRouteException(source.label);
    }
    _micDeviceId = device;
  }

  // #***! смена микрофона на ходу, подменяем дорожку в идущем звонке
  Future<void> setMicrophone(String? deviceId) async {
    final next = (deviceId == null || deviceId.isEmpty) ? null : deviceId;
    _micDeviceId = next;
    _pulseSource = null;
    _monitorCapture = false;
    await AppMicrophone.save(next ?? '');
    await AppPulseSource.save('');
    await PulseAudio.closeBridge();
    if (AudioDevices.switchesInsideEngine) {
      await _selectMicInsideEngine();
    } else {
      await _replaceMicTrack();
    }
    _notifyInfo();
  }

  Future<void> _replaceMicTrack() async {
    await _prepareMicRoute();
    final sender = _audioSender;
    if (sender == null) return;
    final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': AudioDevices.micConstraints(
        _micDeviceId,
        monitorCapture: _monitorCapture,
      ),
      'video': false,
    });
    final tracks = stream.getAudioTracks();
    if (tracks.isEmpty) {
      await _disposeStream(stream);
      return;
    }
    final track = tracks.first;
    track.enabled = audioTransmitting;
    await sender.replaceTrack(track);
    final previous = _micStream;
    _micStream = stream;
    if (previous != null) {
      await _disposeStream(previous);
    } else {
      for (final old
          in _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
        try {
          await old.stop();
        } catch (_) {}
      }
    }
  }

  // #***! громкая связь
  Future<void> setSpeaker(bool on) async {
    if (_speakerOn == on) return;
    _speakerOn = on;
    await applyAudioRoute();
    _notifyInfo();
  }

  Future<void> _prepareAudioSession() async {
    if (!_canRouteAudio) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.communication,
        );
      } catch (e) {
        logger.w('[call] setAndroidAudioConfiguration: $e');
      }
    }
    await applyAudioRoute();
  }

  // #***! маршрут звука, динамик наушники гарнитура
  Future<void> applyAudioRoute() async {
    if (!_canRouteAudio) return;
    try {
      await Helper.setSpeakerphoneOn(_speakerOn);
    } catch (e) {
      logger.w('[call] setSpeakerphoneOn($_speakerOn) недоступен: $e');
    }
  }

  static bool get _canRouteAudio =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // #***! служебные каналы SFU
  Future<void> _openSfuChannels(RTCPeerConnection pc) async {
    await _closeSfuChannels();
    final commands = SfuCommandChannel();
    _sfuCommands = commands;
    _sfuSlotSub = commands.slotUpdates.listen(_onSfuSlots);
    _sfuLevelSub = commands.audioLevels.listen(_onSfuLevels);
    for (final label in _sfuChannelLabels) {
      try {
        final channel = await pc.createDataChannel(
          label,
          RTCDataChannelInit()
            ..ordered = true
            ..maxRetransmitTime = 10000000,
        );
        channel.onDataChannelState = (state) {
          logger.i('[call][sfu] data channel $label $state');
          if (state == RTCDataChannelState.RTCDataChannelOpen) {
            _scheduleDisplayLayout();
          }
        };
        commands.bind(channel);
        _sfuChannels.add(channel);
      } catch (e) {
        logger.w('[call][sfu] data channel $label failed: $e');
      }
    }
  }

  // #***! уровни звука от SFU, по ним подсвечиваем говорящего
  void _onSfuLevels(Map<String, int> levels) {
    final now = DateTime.now();
    levels.forEach((key, level) {
      final id = _participantIdFrom(key.split(':').first);
      if (id != null) _levelState[id] = (level: level, at: now);
    });
    _levelState.removeWhere((_, v) => now.difference(v.at) > _levelTtl);

    final loud = _levelState.entries
        .where((e) => e.value.level >= _sfuSpeakLevel)
        .map((e) => e.key)
        .toSet();
    logger.i('[call][sfu] levels: $levels speaking=$loud');
    if (loud.length == _speaking.length && loud.containsAll(_speaking)) return;
    _speaking = loud;
    _notifyInfo();
  }

  // #***! слот -> участник, сервер шлёт видео слотами а не по id
  void _onSfuSlots(Map<String, int> slots) {
    if (slots.isEmpty) return;
    _slotParticipant.clear();
    slots.forEach((key, slot) {
      if (slot < 0) return;
      final id = _participantIdFrom(key.split(':').first);
      if (id != null) _slotParticipant[slot] = id;
    });
    unawaited(_rebindSlotTracks());
  }

  Future<void> _rebindSlotTracks() async {
    await _clearParticipantStreams();
    await _collectReceivers();
    _notifyInfo();
  }

  void _scheduleDisplayLayout() {
    _layoutDebounce?.cancel();
    _layoutDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_publishDisplayLayout()),
    );
  }

  // #***! говорим серверу чьи видео и в каком размере нужны
  Future<void> _publishDisplayLayout({bool force = false}) async {
    final commands = _sfuCommands;
    if (commands == null || _topology != 'SERVER' || _ended) return;
    final items = <SfuLayoutItem>[];
    for (final p in _participants.values) {
      if (p.isSelf || items.length >= _maxVideoSlots) continue;
      if (!p.videoEnabled && !p.screenSharing) continue;
      items.add(
        SfuLayoutItem(
          trackKey: 'u${p.id}:${p.screenSharing ? 'sSCREEN' : 'sCAMERA'}',
        ),
      );
    }
    final keys = items.map((i) => i.trackKey).toList(growable: false);
    if (!force &&
        _layoutSent &&
        keys.length == _lastLayout.length &&
        keys.every(_lastLayout.contains)) {
      return;
    }
    if (!await commands.sendDisplayLayout(items)) return;
    _lastLayout = keys;
    _layoutSent = true;
  }

  Set<String> _videoSlotMids(String sdp) {
    final mids = <String>{};
    String? kind;
    String? mid;
    var recvOnly = false;

    void flush() {
      final id = mid;
      if (kind == 'video' && recvOnly && id != null) mids.add(id);
    }

    for (var line in sdp.split('\n')) {
      line = line.trim();
      if (line.startsWith('m=')) {
        flush();
        kind = line.substring(2).split(' ').first;
        mid = null;
        recvOnly = false;
      } else if (line.startsWith('a=mid:')) {
        mid = line.substring(6);
      } else if (line == 'a=recvonly') {
        recvOnly = true;
      }
    }
    flush();
    return mids;
  }

  // #***! перед чужим видео надо завести под него слот в SDP
  Future<void> _prepareVideoSlot(RTCPeerConnection pc, String offerSdp) async {
    final mids = _videoSlotMids(offerSdp);
    if (mids.isEmpty) return;
    for (final transceiver in await pc.getTransceivers()) {
      final mid = transceiver.mid;
      if (!mids.contains(mid)) continue;
      final tracks =
          _cameraStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
      if (tracks.isNotEmpty) {
        try {
          await transceiver.sender.replaceTrack(tracks.first);
        } catch (e) {
          logger.w('[call][sfu] video slot $mid replaceTrack failed: $e');
        }
      }
      try {
        await transceiver.setDirection(TransceiverDirection.SendOnly);
      } catch (e) {
        logger.w('[call][sfu] video slot $mid setDirection failed: $e');
        continue;
      }
      _videoSender = transceiver.sender;
      logger.i('[call][sfu] video slot mid=$mid -> sendonly');
      return;
    }
  }

  Future<void> _closeSfuChannels() async {
    _layoutDebounce?.cancel();
    _layoutDebounce = null;
    await _sfuSlotSub?.cancel();
    _sfuSlotSub = null;
    await _sfuLevelSub?.cancel();
    _sfuLevelSub = null;
    await _sfuCommands?.dispose();
    _sfuCommands = null;
    _slotParticipant.clear();
    _lastLayout = const [];
    _layoutSent = false;
    final channels = List<RTCDataChannel>.from(_sfuChannels);
    _sfuChannels.clear();
    for (final channel in channels) {
      try {
        await channel.close();
      } catch (_) {}
    }
  }

  // #***! свой ли клиент на той стороне, от этого чат и игры
  Future<void> _setupKometProbe(RTCPeerConnection pc) async {
    if (!_kometProbeEnabled || _topology == 'SERVER') return;
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

  // #***! чат звонка идёт по каналу мимо сервера сообщений
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

  // #***! шашки шлют ходы тем же каналом
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

  // #***! переход в SFU, пересобираем соединение под сервер микшер
  Future<void> _setupSfu() async {
    if (_pc != null) {
      await _closeSfuChannels();
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
      await _disposeMicStream();
      _audioSender = null;
      _videoSender = null;
      _screenSender = null;
    }
    _setState(CallSessionState.connecting);
    final pc = await _createPc(_iceServers);
    _pc = pc;
    await _addLocalMedia(pc);
    await _republishVideo(pc);
    await _openSfuChannels(pc);
    logger.i(
      '[call][sfu] allocate-consumer camera=$_localVideo screen=$_localScreen',
    );
    try {
      final reply = await _signaling?.allocateConsumer();
      logger.i('[call][sfu] allocate-consumer reply: $reply');
    } catch (e) {
      logger.w('[call][sfu] allocate-consumer failed: $e');
    }
  }

  Future<void> _rebuildSfuPc() async {
    await _closeSfuChannels();
    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    _audioSender = null;
    _videoSender = null;
    _screenSender = null;
    _remoteDescSet = false;
    _pendingCandidates.clear();
    await _clearParticipantStreams();

    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      try {
        await track.stop();
      } catch (_) {}
    }
    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    final pc = await _createPc(_iceServers);
    _pc = pc;
    await _addLocalMedia(pc);
    await _republishVideo(pc);
    await _openSfuChannels(pc);
  }

  // #***! после пересборки видео надо опубликовать заново
  Future<void> _republishVideo(RTCPeerConnection pc) async {
    final camera = _cameraStream;
    if (camera != null) {
      final tracks = camera.getVideoTracks();
      if (tracks.isNotEmpty) {
        _videoSender = await pc.addTrack(tracks.first, camera);
      }
    }
    final screen = _screenStream;
    if (screen != null) {
      final tracks = screen.getVideoTracks();
      if (tracks.isNotEmpty) {
        _screenSender = await pc.addTrack(tracks.first, screen);
      }
    }
  }

  // #***! сервер сменил топологию
  Future<void> _onTopologyChanged(Map<String, dynamic> msg) async {
    final topo = msg['topology']?.toString();
    if (topo == null) return;
    logger.i('[call] topology-changed -> $topo');
    info.topology = topo;
    final switchingToSfu = topo == 'SERVER' && _topology != 'SERVER';
    _topology = topo;
    _notifyInfo();
    if (switchingToSfu) await _setupSfu();
  }

  // #***! сервер сказал про новый чужой поток
  Future<void> _onProducerUpdated(Map<String, dynamic> msg) async {
    logger.i(
      '[call][sfu] producer-updated fields=${msg.keys.toList()} '
      'sessionId=${msg['sessionId']}',
    );
    if (_pc == null) return;

    final session = msg['sessionId'];
    final previous = _sfuSessionId;
    if (session != null) _sfuSessionId = session;
    if (previous != null && session != null && session != previous) {
      logger.i('[call][sfu] session changed, recreating peer connection');
      await _rebuildSfuPc();
    }

    final pc = _pc;
    if (pc == null) return;

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
      logger.w('[call][sfu] producer-updated without sdp: $msg');
      return;
    }

    final ssrcs = _extractSsrcs(sdp);
    logger.i(
      '[call][sfu] producer offer: ${_mLines(sdp)} m-lines, '
      'ssrcs=${ssrcs.length}, candidates=${_countCandidates(sdp)} '
      '(${_candidateTypes(sdp)}), ${_sdpSummary(sdp)}, ice=${_iceServerUrls()}',
    );
    logger.i('[call][sfu] producer m-lines: ${_mLineDetails(sdp)}');
    logger.i('[call][sfu] producer video codecs: ${_videoCodecs(sdp)}');
    await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescSet = true;
    await _flushCandidates();
    await _addRemoteCandidatesFromSdp(pc, sdp);
    await _prepareVideoSlot(pc, sdp);

    final answer = await pc.createAnswer({});
    if (_pc != pc) return;
    await pc.setLocalDescription(answer);
    if (_pc != pc) {
      logger.w('[call][sfu] peer connection replaced, dropping answer');
      return;
    }

    await _awaitIceGathering(pc);
    if (_pc != pc) {
      logger.w('[call][sfu] peer connection replaced while gathering');
      return;
    }

    RTCSessionDescription? local;
    try {
      local = await pc.getLocalDescription();
    } catch (e) {
      logger.w('[call][sfu] getLocalDescription failed: $e');
    }
    final answerSdp = local?.sdp ?? answer.sdp ?? '';
    if (answerSdp.isEmpty) return;
    logger.i(
      '[call][sfu] answer: ${_mLines(answerSdp)} m-lines, '
      'candidates=${_countCandidates(answerSdp)} '
      '(${_candidateTypes(answerSdp)}), ${_sdpSummary(answerSdp)}, '
      'gathering=${pc.iceGatheringState}',
    );
    logger.i('[call][sfu] answer m-lines: ${_mLineDetails(answerSdp)}');
    logger.i('[call][sfu] answer video codecs: ${_videoCodecs(answerSdp)}');
    logger.i(
      '[call][sfu] video feedback: offer=[${_videoFeedback(sdp)}] '
      'answer=[${_videoFeedback(answerSdp)}]',
    );
    await _logSenders();

    try {
      logger.i('[call][sfu] accept-producer ssrcs=$ssrcs');
      final reply = await _signaling?.acceptProducer(
        description: _labelLocalTracks(answerSdp),
        ssrcs: ssrcs,
        sessionId: _sfuSessionId,
      );
      logger.i('[call][sfu] accept-producer reply: $reply');
    } catch (e) {
      logger.w('[call][sfu] accept-producer failed: $e');
    }

    Timer(const Duration(seconds: 5), () {
      if (_pc == pc && !_ended) unawaited(_dumpIceStats(pc));
    });
    _videoStatsTimer?.cancel();
    _videoStatsTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (_pc != pc || _ended) {
        t.cancel();
        return;
      }
      unawaited(_dumpVideoStats(pc));
    });

    if (_accepted) await _sendMediaSettings();
    unawaited(_collectReceivers());
    unawaited(_publishDisplayLayout(force: true));
  }

  // #***! дальше разбор SDP ради отладочной сводки
  int _countCandidates(String sdp) =>
      RegExp(r'^a=candidate:', multiLine: true).allMatches(sdp).length;

  String _candidateTypes(String sdp) {
    final counts = <String, int>{};
    for (final m in RegExp(
      r'^a=candidate:.* typ (\w+)',
      multiLine: true,
    ).allMatches(sdp)) {
      final type = m.group(1) ?? '?';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts.isEmpty
        ? 'none'
        : counts.entries.map((e) => '${e.key}=${e.value}').join(' ');
  }

  Future<void> _addRemoteCandidatesFromSdp(
    RTCPeerConnection pc,
    String sdp,
  ) async {
    final mid = RegExp(r'^a=mid:(\S+)', multiLine: true).firstMatch(sdp);
    if (mid == null) return;
    final seen = <String>{};
    var added = 0;
    for (final m in RegExp(
      r'^a=(candidate:\S.*)$',
      multiLine: true,
    ).allMatches(sdp)) {
      final line = m.group(1)!.trim();
      if (!seen.add(line)) continue;
      try {
        await pc.addCandidate(RTCIceCandidate(line, mid.group(1), 0));
        added++;
      } catch (_) {}
    }
    logger.i(
      '[call][sfu] remote candidates added=$added: '
      '${seen.map((c) => c.split(' ').take(6).join(' ')).join(' | ')}',
    );
  }

  Future<void> _dumpVideoStats(RTCPeerConnection pc) async {
    try {
      final rows = <String>[];
      for (final r in await pc.getStats()) {
        if (r.type != 'inbound-rtp') continue;
        final v = r.values;
        if (v['kind'] != 'video' && v['mediaType'] != 'video') continue;
        rows.add(
          '[ssrc=${v['ssrc']} bytes=${v['bytesReceived']} '
          'packets=${v['packetsReceived']} decoded=${v['framesDecoded']} '
          '${v['frameWidth']}x${v['frameHeight']}]',
        );
      }
      var transportBytes = 0;
      var audioBytes = 0;
      for (final r in await pc.getStats()) {
        final v = r.values;
        if (r.type == 'transport') {
          final b = v['bytesReceived'];
          if (b is num) transportBytes += b.toInt();
        } else if (r.type == 'inbound-rtp' &&
            (v['kind'] == 'audio' || v['mediaType'] == 'audio')) {
          final b = v['bytesReceived'];
          if (b is num) audioBytes += b.toInt();
        }
      }
      logger.i(
        '[call][sfu] inbound video: ${rows.join(' ')} '
        '| transport=$transportBytes audio=$audioBytes',
      );
    } catch (e) {
      logger.w('[call][sfu] video stats failed: $e');
    }
  }

  Future<void> _dumpIceStats(RTCPeerConnection pc) async {
    try {
      final reports = await pc.getStats();
      final candidates = <String, String>{};
      for (final r in reports) {
        if (r.type != 'local-candidate' && r.type != 'remote-candidate') {
          continue;
        }
        final v = r.values;
        candidates[r.id] =
            '${v['candidateType']}/${v['protocol']} '
            '${v['ip'] ?? v['address']}:${v['port']}';
      }

      for (final r in reports) {
        if (r.type != 'candidate-pair' && r.type != 'googCandidatePair') {
          continue;
        }
        final v = r.values;
        final from = candidates[v['localCandidateId']] ?? '?';
        final to = candidates[v['remoteCandidateId']] ?? '?';
        logger.w(
          '[call][sfu] pair ${v['state'] ?? v['googState']}: $from -> $to '
          'sent=${v['requestsSent']} recv=${v['responsesReceived']} '
          'inRecv=${v['requestsReceived']} nominated=${v['nominated']}',
        );
      }
    } catch (e) {
      logger.w('[call][sfu] ice stats failed: $e');
    }
  }

  String _iceServerUrls() =>
      _iceServers.whereType<Map>().map((s) => '${s['urls']}').join(' | ');

  String _sdpSummary(String sdp) {
    final bundle = RegExp(
      r'^a=group:BUNDLE (.*)$',
      multiLine: true,
    ).firstMatch(sdp);
    final mids = bundle == null
        ? 'none'
        : '${bundle.group(1)!.trim().split(RegExp(r'\s+')).length}';
    final ufrags = RegExp(
      r'^a=ice-ufrag:(\S+)',
      multiLine: true,
    ).allMatches(sdp).map((m) => m.group(1)).toSet().length;
    var active = 0;
    var total = 0;
    for (final m in RegExp(r'^m=\S+ (\d+)', multiLine: true).allMatches(sdp)) {
      total++;
      if (m.group(1) != '0') active++;
    }
    final setup = RegExp(
      r'^a=setup:(\S+)',
      multiLine: true,
    ).allMatches(sdp).map((m) => m.group(1)).toSet().join(',');
    final lite = sdp.contains('a=ice-lite') ? ' ice-lite' : '';
    return 'bundle=$mids ufrags=$ufrags active=$active/$total '
        'setup=$setup$lite';
  }

  String _videoFeedback(String sdp) {
    final fb = <String>{};
    var inVideo = false;
    for (var line in sdp.split('\n')) {
      line = line.trim();
      if (line.startsWith('m=')) {
        inVideo = line.startsWith('m=video');
      } else if (inVideo && line.startsWith('a=rtcp-fb:')) {
        final idx = line.indexOf(' ');
        if (idx > 0) fb.add(line.substring(idx + 1));
      } else if (inVideo && line.startsWith('a=extmap:')) {
        if (line.contains('transport-wide-cc')) fb.add('extmap:transport-cc');
      }
    }
    return fb.isEmpty ? 'нет' : fb.join(', ');
  }

  String _videoCodecs(String sdp) {
    final codecs = <String>{};
    var inVideo = false;
    for (var line in sdp.split('\n')) {
      line = line.trim();
      if (line.startsWith('m=')) {
        inVideo = line.startsWith('m=video');
      } else if (inVideo && line.startsWith('a=rtpmap:')) {
        final m = RegExp(r'^a=rtpmap:\d+ ([^/]+)/').firstMatch(line);
        if (m != null) codecs.add(m.group(1)!);
      }
    }
    return codecs.isEmpty ? 'нет' : codecs.join(',');
  }

  int _mLines(String sdp) =>
      RegExp(r'^m=', multiLine: true).allMatches(sdp).length;

  String _mLineDetails(String sdp) {
    final rows = <String>[];
    String? kind;
    String? port;
    String? mid;
    String? dir;
    String? msid;

    void flush() {
      if (kind == null) return;
      rows.add(
        '[$kind:$port mid=${mid ?? '?'} ${dir ?? '?'} msid=${msid ?? '-'}]',
      );
    }

    for (var line in sdp.split('\n')) {
      line = line.trim();
      if (line.startsWith('m=')) {
        flush();
        final parts = line.substring(2).split(' ');
        kind = parts.isEmpty ? '?' : parts.first;
        port = parts.length > 1 ? parts[1] : '?';
        mid = null;
        dir = null;
        msid = null;
      } else if (line.startsWith('a=mid:')) {
        mid = line.substring(6);
      } else if (line == 'a=sendrecv' ||
          line == 'a=recvonly' ||
          line == 'a=sendonly' ||
          line == 'a=inactive') {
        dir = line.substring(2);
      } else if (line.startsWith('a=msid:')) {
        msid = line.substring(7);
      }
    }
    flush();
    return rows.join(' ');
  }

  List<String> _extractSsrcs(String sdp) {
    final set = <String>{};
    for (final m in RegExp(r'a=ssrc:(\d+)', multiLine: true).allMatches(sdp)) {
      final v = m.group(1);
      if (v != null) set.add(v);
    }
    return set.toList();
  }

  String _labelLocalTracks(String sdp) {
    final self = 'u${ws2Config.userId}';
    final names = <String, String>{};
    final camera = _videoSender?.track?.id;
    final screen = _screenSender?.track?.id;
    if (camera != null && camera.isNotEmpty) names[camera] = '$self:sCAMERA';
    if (screen != null && screen.isNotEmpty) names[screen] = '$self:sSCREEN';
    if (names.isEmpty) return sdp;

    var out = sdp;
    for (final entry in names.entries) {
      final id = RegExp.escape(entry.key);
      final name = entry.value;
      out = out.replaceAllMapped(
        RegExp('^a=msid:(\\S+) $id\\s*\$', multiLine: true),
        (m) => 'a=msid:${m[1]} $name',
      );
      out = out.replaceAllMapped(
        RegExp('^(a=ssrc:\\d+ msid:\\S+) $id\\s*\$', multiLine: true),
        (m) => '${m[1]} $name',
      );
      out = out.replaceAllMapped(
        RegExp('^(a=ssrc:\\d+ label:)$id\\s*\$', multiLine: true),
        (m) => '${m[1]}$name',
      );
    }
    return out;
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

  // #***! пришла чужая дорожка
  Future<void> _onRemoteTrack(RTCTrackEvent event) async {
    logger.t(
      '[call] remote track: ${event.track.kind} id=${event.track.id} '
      'streams=${event.streams.length}',
    );
    await _bindParticipantTrack(event.track);
    if (event.streams.isNotEmpty) {
      _remoteStreamRef = event.streams.first;
      _remoteStream.add(event.streams.first);
    } else {
      await _collectReceivers();
    }
  }

  int? _participantFromTrackId(String? trackId) {
    if (trackId == null) return null;
    final slot = RegExp(r'^video-pat-(\d+)$').firstMatch(trackId);
    if (slot != null) {
      return _slotParticipant[int.parse(slot.group(1)!)];
    }
    for (final prefix in const ['video-', 'audio-']) {
      if (trackId.length > prefix.length && trackId.startsWith(prefix)) {
        final parsed = _participantIdFrom(trackId.substring(prefix.length));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  // #***! привязываем дорожку к участнику по слоту
  Future<void> _bindParticipantTrack(MediaStreamTrack track) async {
    final id = _participantFromTrackId(track.id);
    if (id == null || id == ws2Config.userId) return;
    var stream = _participantStreams[id];
    if (stream == null) {
      stream = await createLocalMediaStream('komet_p$id');
      _participantStreams[id] = stream;
    }
    if (stream.getTracks().any((t) => t.id == track.id)) return;
    try {
      await stream.addTrack(track);
    } catch (_) {
      return;
    }
    logger.t('[call] track ${track.id} -> participant $id');
    if (!_participantStreamUpdates.isClosed) _participantStreamUpdates.add(id);
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

  Future<void> _logSenders() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final rows = <String>[];
      for (final tr in await pc.getTransceivers()) {
        final sent = tr.sender.track;
        final received = tr.receiver.track;
        rows.add(
          '[mid=${tr.mid} dir=${await tr.getCurrentDirection()} '
          'send=${sent == null ? '-' : '${sent.kind}:${sent.id}'} '
          'recv=${received == null ? '-' : '${received.kind}:${received.id}'}]',
        );
      }
      logger.i('[call][sfu] transceivers: ${rows.join(' ')}');
    } catch (e) {
      logger.w('[call][sfu] transceiver dump failed: $e');
    }
  }

  Future<void> _collectReceivers() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      for (final tr in await pc.getTransceivers()) {
        final track = tr.receiver.track;
        if (track != null) {
          logger.t('[call] receiver track: ${track.kind} id=${track.id}');
          await _bindParticipantTrack(track);
          await _pushRemoteTrack(track);
        }
      }
    } catch (_) {}
  }

  // #***! создание и отправка offer
  Future<void> _createAndSendOffer({bool iceRestart = false}) async {
    final pc = _pc;
    final peerId = _peerId;
    if (pc == null || peerId == null) return;

    final offer = await pc.createOffer(iceRestart ? {'iceRestart': true} : {});
    final sdp = offer.sdp ?? '';
    await pc.setLocalDescription(RTCSessionDescription(sdp, offer.type));
    logger.t('[call] our offer video: ${_videoDir(sdp)}');
    await _signaling?.transmitSdp(
      participantId: peerId,
      participantType: _peerType,
      deviceIdx: _peerDeviceIdx,
      type: offer.type!,
      sdp: _labelLocalTracks(sdp),
    );
  }

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS;

  // #***! на десктопе форсим VP8, аппаратный H.264 там часто битый
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

  // #***! пришёл SDP или кандидат от собеседника
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

      if (type == 'offer' &&
          pc.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        logger.w('[call] offer glare, rolling back local offer');
        await pc.setLocalDescription(RTCSessionDescription(null, 'rollback'));
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
            sdp: _labelLocalTracks(answer.sdp!),
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

  // #***! придержанные кандидаты отправляем в соединение
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

  // #***! ждём сбора кандидатов но не бесконечно
  Future<void> _awaitIceGathering(
    RTCPeerConnection pc, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final done = Completer<void>();
    _gatherDone = done;
    try {
      await done.future.timeout(timeout);
      logger.i('[call][sfu] relay candidate gathered');
    } catch (_) {
      logger.w('[call][sfu] no relay candidate within $timeout');
    } finally {
      _gatherDone = null;
    }
  }

  // #***! свой кандидат уходит собеседнику
  void _onLocalCandidate(RTCIceCandidate candidate) {
    final line = candidate.candidate;
    if (line != null && line.contains(' typ relay')) {
      final done = _gatherDone;
      if (done != null && !done.isCompleted) done.complete();
    }
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

  // #***! принятие входящего
  Future<void> accept({bool activate = true}) async {
    if (_accepted) return;
    _accepted = true;
    logger.i('[call] accept-call sent (activate=$activate)');
    await _signaling?.acceptCall(
      isAudioEnabled: !_muted,
      isVideoEnabled: _localVideo,
      isScreenSharingEnabled: _localScreen,
    );
    if (activate) _setState(CallSessionState.active);
  }

  // #***! говорим собеседнику про свой микрофон
  Future<void> sendAudioEnabledSignal(bool enabled) async {
    await _signaling?.changeMediaSettings(isAudioEnabled: enabled);
  }

  // #***! мьют, дорожку не убираем а глушим иначе собеседник увидит разрыв
  Future<void> setMuted(bool muted) async {
    await _applyMuted(muted, announce: true);
  }

  Future<void> _applyMuted(bool muted, {bool announce = false}) async {
    _muted = muted;
    _applyAudioTracks();
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

  // #***! камера и демонстрация экрана
  Future<void> setVideoEnabled(bool on) => on ? _startCamera() : _stopCamera();

  Future<void> setScreenSharing(bool on) =>
      on ? _startScreenShare() : _stopScreenShare();

  // #***! ручной переход на серверную топологию
  Future<void> switchToServerTopology({bool force = false}) async {
    if (_topology == 'SERVER') return;
    try {
      await _signaling?.switchTopology(force: force);
    } catch (e) {
      logger.w('[call] switch-topology failed: $e');
    }
  }

  // #***! включение камеры
  Future<void> _startCamera() async {
    final pc = _pc;
    if (pc == null) return;

    final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'video': true,
      'audio': false,
    });

    await _disposeStream(_cameraStream);
    _cameraStream = stream;

    final tracks = stream.getVideoTracks();
    final track = tracks.isEmpty ? null : tracks.first;
    if (track != null) {
      if (_videoSender == null) {
        _videoSender = await pc.addTrack(track, stream);
      } else {
        await _videoSender!.replaceTrack(track);
      }
    }

    _localVideo = true;
    await _renegotiate();
    await _sendMediaSettings();
    _notifyInfo();
  }

  Future<void> _stopCamera() async {
    try {
      await _videoSender?.replaceTrack(null);
    } catch (_) {}
    await _disposeStream(_cameraStream);
    _cameraStream = null;
    _localVideo = false;
    await _sendMediaSettings();
    _notifyInfo();
  }

  // #***! демонстрация экрана, на мобилках нужно своё разрешение
  Future<void> _startScreenShare() async {
    if (_pc == null) return;

    await CallBridge.instance.setScreenShare(true);

    _localScreen = true;
    await _sendMediaSettings();
    _notifyInfo();

    final MediaStream stream;
    try {
      stream = await _captureScreen();
    } catch (e) {
      _localScreen = false;
      await CallBridge.instance.setScreenShare(false);
      await _sendMediaSettings();
      _notifyInfo();
      rethrow;
    }
    logger.i('[call] screen captured, topology=$_topology');

    await _disposeStream(_screenStream);
    _screenStream = stream;

    final pc = _pc;
    if (pc == null) return;

    final tracks = stream.getVideoTracks();
    final track = tracks.isEmpty ? null : tracks.first;
    if (track != null) {
      if (_screenSender == null) {
        _screenSender = await pc.addTrack(track, stream);
      } else {
        await _screenSender!.replaceTrack(track);
      }
    }

    logger.i('[call] screen share published, topology=$_topology');
    await _renegotiate();
    await _sendMediaSettings();
    _notifyInfo();
  }

  Future<MediaStream> _captureScreen() async {
    if (!_isDesktop) {
      return navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
        'video': true,
        'audio': false,
      });
    }
    final sources = await desktopCapturer.getSources(
      types: [SourceType.Screen],
    );
    if (sources.isEmpty) {
      throw StateError('нет доступных экранов для захвата');
    }
    return navigator.mediaDevices.getDisplayMedia(<String, dynamic>{
      'video': {
        'deviceId': {'exact': sources.first.id},
        'mandatory': {'frameRate': 30.0},
      },
      'audio': false,
    });
  }

  Future<void> _stopScreenShare() async {
    try {
      await _screenSender?.replaceTrack(null);
    } catch (_) {}
    await _disposeStream(_screenStream);
    _screenStream = null;
    _localScreen = false;
    await CallBridge.instance.setScreenShare(false);
    await _sendMediaSettings();
    _notifyInfo();
  }

  // #***! пересогласование после смены дорожек
  Future<void> _renegotiate() async {
    if (_topology == 'SERVER') return;
    try {
      await _createAndSendOffer();
    } catch (e) {
      logger.w('[call] renegotiation offer failed: $e');
    }
  }

  Future<void> _clearParticipantStreams() async {
    final entries = Map<int, MediaStream>.from(_participantStreams);
    _participantStreams.clear();
    for (final id in entries.keys) {
      if (!_participantStreamUpdates.isClosed) {
        _participantStreamUpdates.add(id);
      }
    }
    for (final stream in entries.values) {
      try {
        await stream.dispose();
      } catch (_) {}
    }
  }

  Future<void> _disposeStream(MediaStream? stream) async {
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

  // #***! завершение звонка
  Future<void> hangup({String? reason}) async {
    final r = reason ?? _autoHangupReason();
    try {
      await _signaling?.hangup(reason: r);
    } catch (_) {}
    _end();
  }

  // #***! причину подбираем по тому на каком этапе прервались
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

  // #***! освобождаем всё, соединение дорожки подписки стримы
  Future<void> _dispose() async {
    _levelTimer?.cancel();
    _videoStatsTimer?.cancel();
    try {
      await _probeChannel?.close();
    } catch (_) {}
    _probeChannel = null;
    await _closeSfuChannels();
    for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _localStream?.dispose();
    await _disposeMicStream();
    await PulseAudio.closeBridge();
    await _disposeStream(_cameraStream);
    await _disposeStream(_screenStream);
    _cameraStream = null;
    _screenStream = null;
    await _pc?.close();
    if (_ownRemoteStream) {
      try {
        await _remoteStreamRef?.dispose();
      } catch (_) {}
    }
    await _clearParticipantStreams();
    await _signaling?.close();
    if (!_participantStreamUpdates.isClosed) {
      await _participantStreamUpdates.close();
    }
    if (!_state.isClosed) await _state.close();
    if (!_remoteStream.isClosed) await _remoteStream.close();
    if (!_info.isClosed) await _info.close();
    if (!_kometDetected.isClosed) await _kometDetected.close();
    if (!_chatController.isClosed) await _chatController.close();
    if (!_gameController.isClosed) await _gameController.close();
  }

  // #***! параметры соединения в отладочную сводку
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

  // #***! напрямую идём или через TURN
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

  // #***! вычисляем собеседника в звонке один на один
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

  // #***! ICE серверы в формате WebRTC
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
