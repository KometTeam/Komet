import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../config/app_microphone.dart';
import '../config/app_audio_output.dart';
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
    this.initialVideo = false,
  });

  final bool initialVideo;

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
  bool _peerScreen = false;
  bool _mediaConnected = false;
  bool _remoteDescSet = false;
  bool _ownRemoteStream = false;
  // #***! кандидаты пришедшие до remote SDP придерживаем тут
  final List<RTCIceCandidate> _pendingCandidates = [];
  Future<void> _tail = Future.value();
  Map<String, dynamic>? _pendingProducerUpdate;
  bool _processingProducerUpdate = false;

  // #***! участники и их видео, экран звонка подписан
  final Map<int, CallParticipant> _participants = {};
  final Map<int, MediaStream> _participantStreams = {};
  final Map<int, MediaStream> _participantScreens = {};
  final Map<String, MediaStream> _remoteTrackStreams = {};
  final Set<String> _borrowedRemoteStreamIds = {};
  final List<MediaStream> _retiredParticipantStreams = [];
  final Set<int> _screenSlots = {};
  final _participantStreamUpdates = StreamController<int>.broadcast();

  String? _topology;
  List _iceServers = const [];
  Object? _sfuSessionId;
  Set<int> _speaking = const {};

  Future<void> _mediaTail = Future.value();
  int _captureEpoch = 0;
  Timer? _captureHealthTimer;
  bool _checkingCapture = false;
  String? _screenSourceId;
  SourceType? _screenSourceType;
  String? mediaError;
  bool _initialMediaOpened = false;
  String? _cameraDeviceId;
  bool cameraMirrored = true;
  String? _screenSourceName;
  String? get cameraDeviceId => _cameraDeviceId;
  String? get screenSourceName => _screenSourceName;
  bool get isDesktop => _isDesktop;
  bool get peerScreen => _peerScreen;
  bool get peerHasVideo => _peerVideo || _peerScreen;
  bool _localVideo = false;
  bool _localScreen = false;
  MediaStream? _cameraStream;
  MediaStream? _screenStream;
  // #***! отправители аудио камеры и экрана, треки подменяем на лету
  RTCRtpSender? _audioSender;
  RTCRtpSender? _videoSender;
  RTCRtpSender? _screenSender;
  RTCRtpTransceiver? _directVideoTransceiver;
  bool _directScreenSubstitution = false;
  String? _micDeviceId = AppMicrophone.deviceId;
  String? _audioOutputDeviceId = AppAudioOutput.deviceId;
  String? _pulseSource = AppPulseSource.name;
  bool _monitorCapture = false;

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
  StreamSubscription<Map<int, String>>? _sfuSlotSub;
  StreamSubscription<Map<String, int>>? _sfuLevelSub;
  final Map<int, int> _slotParticipant = {};
  Timer? _layoutDebounce;
  int _layoutRetry = 0;
  Timer? _videoStatsTimer;
  Future<void> _slotRebindTail = Future.value();
  int _slotRevision = 0;
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
  bool get _signaledVideo => _directScreenSubstitution || _localVideo;
  bool get _signaledScreen => !_directScreenSubstitution && _localScreen;
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

  MediaStream? streamOf(int participantId, {bool screen = false}) => screen
      ? _participantScreens[participantId]
      : _participantStreams[participantId];

  int get participantCount => _participants.length;

  bool isSpeaking(int id) => _speaking.contains(id);

  String? get topology => _topology;

  bool get _wantVideo => initialVideo || params?.isVideo == true;

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
  String? get audioOutputDeviceId => _audioOutputDeviceId;
  String? get pulseSource => _pulseSource;
  bool get isSpeaker => _speakerOn;
  bool get peerMuted => _peerMuted;
  bool get peerVideo => _peerVideo || _peerScreen;
  bool get peerCamera => _peerVideo;
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
            'isVideoEnabled': _signaledVideo,
            'isAudioEnabled': !_muted,
            'isScreenSharingEnabled': _signaledScreen,
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
    _captureEpoch++;
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
    _directVideoTransceiver = null;
    _directScreenSubstitution = false;
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
    await CallBridge.instance.setScreenShare(false);
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
        _queueProducerUpdate(msg);
        break;
      case 'session-state':
        _onSessionState(msg);
        break;
      case 'closed-conversation':
        _end();
        break;
    }
  }

  void _queueProducerUpdate(Map<String, dynamic> msg) {
    _pendingProducerUpdate = Map<String, dynamic>.from(msg);
    if (_processingProducerUpdate) return;
    _processingProducerUpdate = true;
    unawaited(_drainProducerUpdates());
  }

  Future<void> _drainProducerUpdates() async {
    try {
      while (!_ended) {
        final msg = _pendingProducerUpdate;
        _pendingProducerUpdate = null;
        if (msg == null) return;
        try {
          await _onProducerUpdated(msg);
        } catch (e, st) {
          logger.w('[call][sfu] producer update failed: $e\n$st');
        }
      }
    } finally {
      _processingProducerUpdate = false;
      if (!_ended && _pendingProducerUpdate != null) {
        _queueProducerUpdate(_pendingProducerUpdate!);
      }
    }
  }

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
    if (!p.videoEnabled) unawaited(_removeParticipantStream(id, screen: false));
    if (!p.screenSharing) unawaited(_removeParticipantStream(id, screen: true));
    _notifyInfo();
  }

  Future<void> _removeParticipantStream(int id, {required bool screen}) async {
    final streams = screen ? _participantScreens : _participantStreams;
    final stream = streams.remove(id);
    if (stream == null) return;
    if (!_participantStreamUpdates.isClosed) _participantStreamUpdates.add(id);
    _retiredParticipantStreams.add(stream);
  }

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
    if (_ended) {
      await pc.close();
      return;
    }
    _pc = pc;
    await _addLocalMedia(pc);

    if (_videoSender == null) {
      _directVideoTransceiver = await pc.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.SendRecv),
      );
      _videoSender = _directVideoTransceiver!.sender;
    }

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
          _startVideoDiagnostics(pc);
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
    final local = await navigator.mediaDevices.getUserMedia({
      'audio': AudioDevices.micConstraints(
        _micDeviceId,
        monitorCapture: _monitorCapture,
      ),
      'video': false,
    });
    if (_ended || !identical(pc, _pc)) {
      await _disposeStream(local);
      return;
    }
    _localStream = local;
    for (final track in local.getTracks()) {
      final sender = await pc.addTrack(track, _localStream!);
      if (track.kind == 'audio') _audioSender = sender;
    }
    _applyAudioTracks();
    await applyAudioRoute();
    if (!_initialMediaOpened) {
      _initialMediaOpened = true;
      if (_wantVideo) {
        try {
          await _startCamera(announce: false);
        } catch (e) {
          logger.w('[call] initial camera unavailable: $e');
          mediaError = 'Не удалось включить камеру: $e';
          _notifyInfo();
        }
      }
    }
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

  Future<void> setMicrophone(String? deviceId) => _mediaOperation(() async {
    final previousDevice = _micDeviceId;
    final previousPulse = _pulseSource;
    final previousMonitor = _monitorCapture;
    final next = (deviceId == null || deviceId.isEmpty) ? null : deviceId;
    _micDeviceId = next;
    _pulseSource = null;
    _monitorCapture = false;
    try {
      if (AudioDevices.switchesInsideEngine) {
        if (next == null) {
          throw StateError('Выберите микрофон из списка устройств');
        }
        final devices = await AudioDevices.microphones();
        if (!devices.any((device) => device.id == next)) {
          throw StateError('Микрофон отключён. Обновите список устройств.');
        }
        await AudioDevices.selectInput(next);
      } else {
        if (next != null &&
            !await AudioDevices.microphones().then(
              (devices) => devices.any((d) => d.id == next),
            )) {
          throw StateError('Микрофон отключён. Обновите список устройств.');
        }
        await _replaceMicTrack();
      }
      if (_ended) return;
      await AppMicrophone.save(next ?? '');
      await AppPulseSource.save('');
      await PulseAudio.closeBridge();
    } catch (_) {
      _micDeviceId = previousDevice;
      _pulseSource = previousPulse;
      _monitorCapture = previousMonitor;
      rethrow;
    } finally {
      _notifyInfo();
    }
  });

  Future<void> _replaceMicTrack() async {
    await _prepareMicRoute();
    final sender = _audioSender;
    final epoch = _captureEpoch;
    if (sender == null || _ended) return;
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': AudioDevices.micConstraints(
        _micDeviceId,
        monitorCapture: _monitorCapture,
      ),
      'video': false,
    });
    try {
      if (_ended || epoch != _captureEpoch || sender != _audioSender) {
        await _disposeStream(stream);
        return;
      }
      final tracks = stream.getAudioTracks();
      if (tracks.isEmpty) {
        throw StateError('Микрофон не предоставил аудиопоток');
      }
      tracks.first.enabled = audioTransmitting;
      await sender.replaceTrack(tracks.first);
      if (_ended || epoch != _captureEpoch || sender != _audioSender) {
        await _disposeStream(stream);
        return;
      }
      final previous = _micStream;
      _micStream = stream;
      if (previous != null) {
        await _disposeStream(previous);
      } else {
        for (final old
            in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
          try {
            await old.stop();
          } catch (_) {}
        }
      }
    } catch (_) {
      await _disposeStream(stream);
      rethrow;
    }
  }

  // #***! громкая связь
  Future<void> setSpeaker(bool on) async {
    if (_speakerOn == on) return;
    _speakerOn = on;
    await applyAudioRoute();
    _notifyInfo();
  }

  Future<void> setAudioOutput(String? deviceId) async {
    final previous = _audioOutputDeviceId;
    try {
      _audioOutputDeviceId = await AudioDevices.selectOutput(deviceId);
      await AppAudioOutput.save(_audioOutputDeviceId ?? '');
    } catch (_) {
      _audioOutputDeviceId = previous;
      rethrow;
    } finally {
      _notifyInfo();
    }
  }

  Future<void> _prepareAudioSession() async {
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
    if (_canRouteAudio) {
      try {
        await Helper.setSpeakerphoneOn(_speakerOn);
      } catch (e) {
        logger.w('[call] setSpeakerphoneOn($_speakerOn) недоступен: $e');
      }
      return;
    }
    if (!_isDesktop) return;
    try {
      _audioOutputDeviceId = await AudioDevices.selectOutput(
        _audioOutputDeviceId,
      );
    } catch (e) {
      logger.w('[call][audio] saved output unavailable: $e');
      if (_audioOutputDeviceId != null) {
        _audioOutputDeviceId = null;
        await AppAudioOutput.save('');
        try {
          await AudioDevices.selectOutput(null);
        } catch (fallbackError) {
          logger.w('[call][audio] default output unavailable: $fallbackError');
        }
      }
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

  void _onSfuSlots(Map<int, String> slots) {
    final participants = <int, int>{};
    final screens = <int>{};
    slots.forEach((slot, key) {
      if (slot < 0) return;
      final id = _participantIdFrom(key.split(':').first);
      if (id == null || id == ws2Config.userId) return;
      final participant = _participants[id];
      if (participant == null ||
          (!participant.videoEnabled && !participant.screenSharing)) {
        return;
      }
      participants[slot] = id;
      final requested = slot < _lastLayout.length ? _lastLayout[slot] : null;
      final requestedId = _participantIdFrom(requested?.split(':').first);
      final isScreen = requestedId == id
          ? requested!.endsWith(':sSCREEN')
          : participant.screenSharing && !participant.videoEnabled;
      if (isScreen) screens.add(slot);
    });
    final wantsVideo = _participants.values.any(
      (participant) =>
          !participant.isSelf &&
          (participant.videoEnabled || participant.screenSharing),
    );
    if (wantsVideo && participants.length < _lastLayout.length) {
      for (final entry in _slotParticipant.entries) {
        if (participants.containsKey(entry.key) ||
            entry.key >= _lastLayout.length) {
          continue;
        }
        final requested = _lastLayout[entry.key];
        if (_participantIdFrom(requested.split(':').first) != entry.value) {
          continue;
        }
        participants[entry.key] = entry.value;
        if (requested.endsWith(':sSCREEN')) screens.add(entry.key);
      }
      logger.i(
        '[call][sfu] incomplete slots retained: '
        '${participants.length}/${_lastLayout.length}',
      );
      _scheduleDisplayLayout(delay: const Duration(seconds: 1), force: true);
    }
    final unchanged =
        participants.length == _slotParticipant.length &&
        participants.entries.every((e) => _slotParticipant[e.key] == e.value) &&
        screens.length == _screenSlots.length &&
        screens.containsAll(_screenSlots);
    if (unchanged) return;
    _slotParticipant
      ..clear()
      ..addAll(participants);
    _screenSlots
      ..clear()
      ..addAll(screens);
    logger.i(
      '[call][video] SFU slots changed: participants=${participants.length} '
      'screens=${screens.length}',
    );
    final revision = ++_slotRevision;
    _slotRebindTail = _slotRebindTail.catchError((_) {}).then((_) async {
      if (_ended || revision != _slotRevision) return;
      await _rebindSlotTracks();
    });
  }

  Future<void> _rebindSlotTracks() async {
    await _clearParticipantStreams(dispose: false);
    await _collectReceivers();
    _notifyInfo();
  }

  void _scheduleDisplayLayout({
    Duration delay = const Duration(milliseconds: 300),
    bool force = false,
  }) {
    _layoutDebounce?.cancel();
    _layoutDebounce = Timer(
      delay,
      () => unawaited(_publishDisplayLayout(force: force)),
    );
  }

  // #***! говорим серверу чьи видео и в каком размере нужны
  Future<void> _publishDisplayLayout({bool force = false}) async {
    final commands = _sfuCommands;
    if (commands == null || _topology != 'SERVER' || _ended) return;
    final items = <SfuLayoutItem>[];
    final requested = <String>[];
    for (final p in _participants.values) {
      if (p.isSelf || items.length >= _maxVideoSlots) continue;
      if (!p.videoEnabled && !p.screenSharing) continue;
      if (p.screenSharing) {
        items.add(
          SfuLayoutItem(
            trackKey: 'u${p.id}',
            width: _isDesktop ? 1920 : 1280,
            height: _isDesktop ? 1080 : 720,
          ),
        );
        requested.add('u${p.id}:sSCREEN');
      } else {
        items.add(SfuLayoutItem(trackKey: 'u${p.id}'));
        requested.add('u${p.id}:sCAMERA');
      }
    }
    if (!force &&
        _layoutSent &&
        requested.length == _lastLayout.length &&
        requested.indexed.every((entry) => _lastLayout[entry.$1] == entry.$2)) {
      return;
    }
    if (!await commands.sendDisplayLayout(items)) {
      if (_layoutRetry < 8) {
        _layoutRetry++;
        _scheduleDisplayLayout(delay: const Duration(seconds: 1));
      }
      return;
    }
    _layoutRetry = 0;
    _lastLayout = requested;
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
    final slots = (await pc.getTransceivers())
        .where((t) => mids.contains(t.mid))
        .toList();
    final media = <({MediaStream stream, bool screen})>[
      if (_screenStream != null) (stream: _screenStream!, screen: true),
      if (_cameraStream != null) (stream: _cameraStream!, screen: false),
    ];
    _videoSender = null;
    _screenSender = null;
    _directVideoTransceiver = null;
    final used = <String>{};
    for (final item in media) {
      final tracks = item.stream.getVideoTracks();
      if (tracks.isEmpty) continue;
      final track = tracks.first;
      final matches = slots.where((t) => t.sender.track?.id == track.id);
      final available = slots.where((t) => !used.contains(t.mid));
      if (matches.isEmpty && available.isEmpty) {
        logger.w(
          '[call][sfu] awaiting slot for ${item.screen ? 'screen' : 'camera'}',
        );
        continue;
      }
      final slot = matches.isNotEmpty ? matches.first : available.first;
      used.add(slot.mid);
      logger.i(
        '[call][sfu] attach ${item.screen ? 'screen' : 'camera'} '
        'track=${track.id} enabled=${track.enabled} mid=${slot.mid} '
        'previous=${slot.sender.track?.id}',
      );
      await slot.sender.replaceTrack(track);
      await slot.setDirection(TransceiverDirection.SendOnly);
      logger.i(
        '[call][sfu] attached ${item.screen ? 'screen' : 'camera'} '
        'mid=${slot.mid} senderTrack=${slot.sender.track?.id}',
      );
      if (item.screen) {
        _screenSender = slot.sender;
      } else {
        _videoSender = slot.sender;
      }
    }
    for (final slot in slots.where((t) => !used.contains(t.mid))) {
      await slot.sender.replaceTrack(null);
      await slot.setDirection(TransceiverDirection.SendOnly);
      _videoSender ??= slot.sender;
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
    _screenSlots.clear();
    _lastLayout = const [];
    _layoutSent = false;
    _layoutRetry = 0;
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
      _directVideoTransceiver = null;
    }
    _setState(CallSessionState.connecting);
    final pc = await _createPc(_iceServers);
    if (_ended) {
      await pc.close();
      return;
    }
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
    _directVideoTransceiver = null;
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
    if (_ended) {
      await pc.close();
      return;
    }
    _pc = pc;
    await _addLocalMedia(pc);
    await _republishVideo(pc);
    await _openSfuChannels(pc);
  }

  // #***! после пересборки видео надо опубликовать заново
  Future<void> _republishVideo(RTCPeerConnection pc) async {
    if (_topology == 'SERVER') return;
    final camera = _cameraStream;
    if (camera != null && _videoSender == null) {
      final tracks = camera.getVideoTracks();
      if (tracks.isNotEmpty) {
        _videoSender = await pc.addTrack(tracks.first, camera);
        logger.i(
          '[call][video] republished camera track=${tracks.first.id} '
          'senderTrack=${_videoSender?.track?.id} topology=$_topology',
        );
      }
    }
    final screen = _screenStream;
    if (screen != null && _screenSender == null) {
      final tracks = screen.getVideoTracks();
      if (tracks.isNotEmpty) {
        _screenSender = await pc.addTrack(tracks.first, screen);
        logger.i(
          '[call][video] republished screen track=${tracks.first.id} '
          'senderTrack=${_screenSender?.track?.id} topology=$_topology',
        );
      }
    }
  }

  // #***! сервер сменил топологию
  Future<void> _onTopologyChanged(Map<String, dynamic> msg) async {
    final topo = msg['topology']?.toString();
    if (topo == null) return;
    logger.i('[call] topology-changed -> $topo');
    if (topo == 'SERVER' &&
        !isGroup &&
        _topology == 'DIRECT' &&
        (_pc?.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
            _pc?.iceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateConnected ||
            _pc?.iceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateCompleted)) {
      logger.i('[call] keeping connected one-to-one call on DIRECT topology');
      return;
    }
    info.topology = topo;
    final switchingToSfu = topo == 'SERVER' && _topology != 'SERVER';
    if (switchingToSfu) _directScreenSubstitution = false;
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
    await _applyVideoQuality();

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
    _startVideoDiagnostics(pc);

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
      final reports = await pc.getStats();
      final senderTracks = <String, String>{};
      for (final transceiver in await pc.getTransceivers()) {
        final mid = transceiver.mid;
        final track = transceiver.sender.track;
        if (track != null) senderTracks[mid] = track.id!;
      }
      final rows = <String>[];
      for (final r in reports) {
        if (r.type != 'inbound-rtp' && r.type != 'outbound-rtp') continue;
        final v = r.values;
        if (v['kind'] != 'video' && v['mediaType'] != 'video') continue;
        final mid = v['mid']?.toString();
        rows.add(
          '[${r.type == 'inbound-rtp' ? 'in' : 'out'} '
          'mid=$mid track=${v['trackIdentifier'] ?? senderTracks[mid]} '
          'ssrc=${v['ssrc']} '
          'bytes=${v['bytesReceived'] ?? v['bytesSent']} '
          'packets=${v['packetsReceived'] ?? v['packetsSent']} '
          'lost=${v['packetsLost']} frames='
          '${v['framesDecoded'] ?? v['framesEncoded'] ?? v['framesSent']} '
          'dropped=${v['framesDropped']} '
          '${v['frameWidth']}x${v['frameHeight']} fps='
          '${v['framesPerSecond']} key=${v['keyFramesDecoded'] ?? v['keyFramesEncoded']} '
          'nack=${v['nackCount']} pli=${v['pliCount']} fir=${v['firCount']} '
          'quality=${v['qualityLimitationReason']}]',
        );
      }
      var transportBytes = 0;
      var audioBytes = 0;
      final audioRows = <String>[];
      for (final r in reports) {
        final v = r.values;
        if (r.type == 'transport') {
          final b = v['bytesReceived'];
          if (b is num) transportBytes += b.toInt();
        } else if ((r.type == 'inbound-rtp' || r.type == 'outbound-rtp') &&
            (v['kind'] == 'audio' || v['mediaType'] == 'audio')) {
          if (r.type == 'inbound-rtp') {
            final b = v['bytesReceived'];
            if (b is num) audioBytes += b.toInt();
          }
          audioRows.add(
            '[${r.type == 'inbound-rtp' ? 'in' : 'out'} '
            'mid=${v['mid']} ssrc=${v['ssrc']} '
            'bytes=${v['bytesReceived'] ?? v['bytesSent']} '
            'packets=${v['packetsReceived'] ?? v['packetsSent']} '
            'lost=${v['packetsLost']} jitter=${v['jitter']} '
            'level=${v['audioLevel']} concealed=${v['concealedSamples']} '
            'samples=${v['totalSamplesReceived']}]',
          );
        }
      }
      logger.i(
        '[call][video] stats: ${rows.join(' ')} '
        '| transport=$transportBytes audio=$audioBytes',
      );
      logger.i('[call][audio] stats: ${audioRows.join(' ')}');
    } catch (e) {
      logger.w('[call][video] stats failed: $e');
    }
  }

  void _startVideoDiagnostics(RTCPeerConnection pc) {
    _videoStatsTimer?.cancel();
    _videoStatsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_pc != pc || _ended) {
        timer.cancel();
        return;
      }
      unawaited(_dumpVideoStats(pc));
    });
    unawaited(_dumpVideoStats(pc));
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
    logger.i(
      '[call][video] remote track kind=${event.track.kind} '
      'id=${event.track.id} mid=${event.transceiver?.mid} '
      'enabled=${event.track.enabled} '
      'streams=${event.streams.map((s) => s.id).join(',')}',
    );
    if (event.track.kind != 'video') {
      unawaited(applyAudioRoute());
      return;
    }
    final source = _sourceStreamForTrack(event.track, event.streams);
    if (source != null) {
      _remoteTrackStreams[event.track.id!] = source;
      _borrowedRemoteStreamIds.add(source.id);
    }
    if (_topology == 'SERVER') {
      await _bindParticipantTrack(event.track);
      return;
    }
    await _pushRemoteTrack(event.track, event.streams);
  }

  int? _participantFromTrackId(String? trackId) {
    if (trackId == null) return null;
    final slot = RegExp(r'^video-pat-(\d+)$').firstMatch(trackId);
    if (slot != null) {
      return _slotParticipant[int.parse(slot.group(1)!)];
    }
    final named = RegExp(r'^u?(\d+):s(?:CAMERA|SCREEN)$').firstMatch(trackId);
    if (named != null) return int.tryParse(named.group(1)!);
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
    final id =
        _participantFromTrackId(track.id) ??
        (_topology != 'SERVER' ? _peerId : null);
    if (id == null || id == ws2Config.userId || track.kind != 'video') return;
    final slot = RegExp(r'^video-pat-(\d+)$').firstMatch(track.id ?? '');
    final screen =
        (track.id?.endsWith(':sSCREEN') ?? false) ||
        (slot != null && _screenSlots.contains(int.parse(slot.group(1)!))) ||
        (_topology != 'SERVER' && _peerScreen && !_peerVideo);
    final streams = screen ? _participantScreens : _participantStreams;
    final source = _remoteTrackStreams[track.id];
    if (source != null && source.getVideoTracks().length == 1) {
      streams[id] = source;
      logger.t('[call] remote stream ${source.id} -> participant $id');
      if (!_participantStreamUpdates.isClosed) {
        _participantStreamUpdates.add(id);
      }
      return;
    }
    var stream = streams[id];
    if (stream == null) {
      stream = await createLocalMediaStream(
        'komet_p${id}_${screen ? 'screen' : 'camera'}',
      );
      if (_ended) {
        await stream.dispose();
        return;
      }
      streams[id] = stream;
    }
    if (stream.getTracks().any((t) => t.id == track.id)) return;
    try {
      for (final old in stream.getVideoTracks().toList()) {
        await stream.removeTrack(old);
      }
      await stream.addTrack(track);
    } catch (_) {
      return;
    }
    logger.t('[call] track ${track.id} -> participant $id');
    if (!_participantStreamUpdates.isClosed) _participantStreamUpdates.add(id);
  }

  Future<void> _pushRemoteTrack(
    MediaStreamTrack track,
    List<MediaStream> sourceStreams,
  ) async {
    final source = _sourceStreamForTrack(track, sourceStreams);
    if (source != null) {
      final previous = _remoteStreamRef;
      final disposePrevious = _ownRemoteStream && !identical(previous, source);
      _remoteStreamRef = source;
      _ownRemoteStream = false;
      _remoteStream.add(source);
      if (disposePrevious) {
        try {
          await previous?.dispose();
        } catch (_) {}
      }
      return;
    }
    var stream = _remoteStreamRef;
    if (stream == null || !_ownRemoteStream) {
      stream = await createLocalMediaStream('komet_remote');
      _ownRemoteStream = true;
    }
    _remoteStreamRef = stream;
    for (final old in stream.getVideoTracks().toList()) {
      if (old.id == track.id) continue;
      try {
        await stream.removeTrack(old);
      } catch (_) {}
    }
    if (!stream.getTracks().any((t) => t.id == track.id)) {
      try {
        await stream.addTrack(track);
      } catch (_) {}
    }
    _remoteStream.add(stream);
  }

  MediaStream? _sourceStreamForTrack(
    MediaStreamTrack track,
    List<MediaStream> streams,
  ) {
    return streams.where((stream) {
      return stream.getVideoTracks().any((item) => item.id == track.id);
    }).firstOrNull;
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
    if (pc == null || _topology != 'SERVER') return;
    try {
      for (final tr in await pc.getTransceivers()) {
        final track = tr.receiver.track;
        if (track != null && track.kind == 'video') {
          logger.t('[call] receiver track: ${track.kind} id=${track.id}');
          await _bindParticipantTrack(track);
        }
      }
    } catch (e) {
      logger.w('[call][video] receiver collection failed: $e');
    }
  }

  // #***! создание и отправка offer
  Future<void> _createAndSendOffer({bool iceRestart = false}) async {
    final pc = _pc;
    final peerId = _peerId;
    if (pc == null || peerId == null) return;

    await _applyVideoQuality();
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
      await _applyVideoQuality();

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
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (pc.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }
    final started = DateTime.now();
    var candidateCount = 0;
    var stableSince = started;
    while (!_ended && identical(pc, _pc)) {
      if (pc.iceGatheringState ==
          RTCIceGatheringState.RTCIceGatheringStateComplete) {
        logger.i('[call][sfu] ICE gathering completed');
        return;
      }
      try {
        final local = await pc.getLocalDescription();
        final nextCount = _countCandidates(local?.sdp ?? '');
        if (nextCount != candidateCount) {
          candidateCount = nextCount;
          stableSince = DateTime.now();
        } else if (candidateCount > 0 &&
            DateTime.now().difference(stableSince) >=
                const Duration(milliseconds: 400)) {
          logger.i(
            '[call][sfu] ICE candidates settled while gathering: '
            '$candidateCount',
          );
          return;
        }
      } catch (_) {}
      if (DateTime.now().difference(started) >= timeout) {
        logger.w(
          '[call][sfu] ICE gathering incomplete after $timeout; '
          'sending $candidateCount candidates gathered so far',
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  // #***! свой кандидат уходит собеседнику
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

  // #***! принятие входящего
  Future<void> accept({bool activate = true}) async {
    if (_accepted) return;
    _accepted = true;
    logger.i('[call] accept-call sent (activate=$activate)');
    await _signaling?.acceptCall(
      isAudioEnabled: !_muted,
      isVideoEnabled: _signaledVideo,
      isScreenSharingEnabled: _signaledScreen,
    );
    if (activate) _setState(CallSessionState.active);
  }

  // #***! говорим собеседнику про свой микрофон
  Future<void> sendAudioEnabledSignal(bool enabled) async {
    await _signaling?.changeMediaSettings(
      isAudioEnabled: enabled,
      isVideoEnabled: _signaledVideo,
      isScreenSharingEnabled: _signaledScreen,
    );
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
      isVideoEnabled: _signaledVideo,
      isScreenSharingEnabled: _signaledScreen,
    );
  }

  Future<void> _mediaOperation(Future<void> Function() operation) {
    final epoch = _captureEpoch;
    final next = _mediaTail.then((_) async {
      if (_ended || epoch != _captureEpoch) return;
      await operation();
    });
    _mediaTail = next.catchError((Object e) {
      logger.w('[call] media operation failed: $e');
    });
    return next;
  }

  Future<void> setVideoEnabled(bool on) =>
      _mediaOperation(() => on ? _startCamera() : _stopCamera());

  Future<void> setCameraDevice(String? deviceId) => _mediaOperation(() async {
    if (_cameraDeviceId == deviceId && _localVideo) return;
    final pc = _pc;
    if (pc == null || _ended) return;
    final epoch = _captureEpoch;
    final previousStream = _cameraStream;
    final previousDevice = _cameraDeviceId;
    final previousMirror = cameraMirrored;
    MediaStream? stream;
    var senderChanged = false;
    final started = DateTime.now();
    try {
      if (deviceId != null) {
        final devices = await navigator.mediaDevices.enumerateDevices();
        if (!devices.any(
          (device) =>
              device.kind == 'videoinput' && device.deviceId == deviceId,
        )) {
          throw StateError('Камера отключена. Выберите доступное устройство.');
        }
      }
      logger.i(
        '[call][video] camera switch capture requested device='
        '${deviceId?.hashCode.toUnsigned(32).toRadixString(16) ?? 'default'} '
        'topology=$_topology',
      );
      stream = await navigator.mediaDevices.getUserMedia({
        'video': {
          if (deviceId != null) ...{
            'deviceId': deviceId,
            'optional': [
              {'sourceId': deviceId},
            ],
          } else
            'facingMode': 'user',
          'width': 1280,
          'height': 720,
          'frameRate': 30,
        },
        'audio': false,
      });
      if (!_captureValid(epoch, pc)) {
        await _disposeStream(stream);
        return;
      }
      final tracks = stream.getVideoTracks();
      if (tracks.isEmpty) throw StateError('Камера не предоставила видеопоток');
      _logCaptureCreated('camera switch', stream, started);
      if (!_captureValid(epoch, pc)) {
        await _disposeStream(stream);
        return;
      }
      final track = tracks.first;
      final senderWasAdded =
          _videoSender == null &&
          !_directScreenSubstitution &&
          _topology != 'SERVER';
      if (senderWasAdded) {
        _videoSender = await pc.addTrack(track, stream);
      } else if (!_directScreenSubstitution && _videoSender != null) {
        await _videoSender!.replaceTrack(track);
      }
      senderChanged = true;
      _cameraStream = stream;
      _cameraDeviceId = deviceId;
      cameraMirrored = track.getSettings()['facingMode'] != 'environment';
      _localVideo = true;
      mediaError = null;
      _watchCapture();
      final captured = stream;
      track.onEnded = () {
        if (identical(_cameraStream, captured)) {
          unawaited(
            setVideoEnabled(false).catchError((Object e) {
              logger.w('[call] camera ended: $e');
            }),
          );
        }
      };
      _notifyInfo();
      await _publishMedia(renegotiate: senderWasAdded);
      _scheduleCaptureDiagnostics(
        'camera switch',
        stream,
        _directScreenSubstitution ? _screenSender : _videoSender,
      );
      if (previousStream != null && !identical(previousStream, stream)) {
        await _disposeStream(previousStream);
      }
    } catch (e, st) {
      logger.e('[call][video] camera switch failed', error: e, stackTrace: st);
      if (senderChanged) {
        try {
          await _videoSender?.replaceTrack(
            previousStream?.getVideoTracks().firstOrNull,
          );
        } catch (_) {}
      }
      if (identical(_cameraStream, stream)) {
        _cameraStream = previousStream;
        _cameraDeviceId = previousDevice;
        cameraMirrored = previousMirror;
        _localVideo = previousStream != null;
      }
      await _disposeStream(stream);
      if (_captureValid(epoch, pc)) await _restoreMediaSettings();
      rethrow;
    }
  });

  Future<void> switchCamera() => _mediaOperation(() async {
    final tracks = _cameraStream?.getVideoTracks();
    if (tracks == null || tracks.isEmpty) return;
    cameraMirrored = await Helper.switchCamera(tracks.first);
    _cameraDeviceId = null;
    _notifyInfo();
  });

  Future<void> setScreenSharing(bool on, {DesktopCapturerSource? source}) =>
      _mediaOperation(
        () => on ? _startScreenShare(source) : _stopScreenShare(),
      );

  // #***! ручной переход на серверную топологию
  Future<void> switchToServerTopology({bool force = false}) async {
    if (_topology == 'SERVER') return;
    await _signaling?.switchTopology(force: force);
  }

  bool _captureValid(int epoch, RTCPeerConnection pc) =>
      !_ended && epoch == _captureEpoch && identical(pc, _pc);

  Future<void> _publishMedia({bool renegotiate = true}) async {
    await _sendMediaSettings();
    await _applyVideoQuality();
    if (renegotiate && _topology != 'SERVER') await _createAndSendOffer();
  }

  Future<void> _applyVideoQuality() async {
    await _configureVideoSender(
      _videoSender,
      maxBitrate: 3000000,
      maxFramerate: 30,
      maintainFramerate: false,
    );
    await _configureVideoSender(
      _screenSender,
      maxBitrate: _isDesktop ? 6000000 : 3000000,
      maxFramerate: _isDesktop ? 30 : 20,
      maintainFramerate: true,
      scaleResolutionDownBy: _isDesktop ? 1 : 2,
    );
  }

  Future<void> _configureVideoSender(
    RTCRtpSender? sender, {
    required int maxBitrate,
    required int maxFramerate,
    required bool maintainFramerate,
    double scaleResolutionDownBy = 1,
  }) async {
    if (sender?.track?.kind != 'video') return;
    try {
      final parameters = sender!.parameters;
      parameters.degradationPreference = maintainFramerate
          ? RTCDegradationPreference.MAINTAIN_FRAMERATE
          : RTCDegradationPreference.BALANCED;
      for (final encoding in parameters.encodings ?? const <RTCRtpEncoding>[]) {
        encoding.active = true;
        encoding.maxBitrate = maxBitrate;
        encoding.maxFramerate = maxFramerate;
        encoding.scaleResolutionDownBy = scaleResolutionDownBy;
        encoding.priority = RTCPriorityType.high;
        encoding.networkPriority = RTCPriorityType.high;
      }
      final applied = await sender.setParameters(parameters);
      logger.i(
        '[call][video] RTP quality applied=$applied '
        'track=${sender.track?.id} maxBitrate=$maxBitrate '
        'maxFramerate=$maxFramerate scale=$scaleResolutionDownBy',
      );
    } catch (e) {
      logger.w('[call][video] RTP quality unavailable: $e');
    }
  }

  Future<void> _restoreMediaSettings() async {
    _notifyInfo();
    if (_ended) return;
    try {
      await _publishMedia();
    } catch (e) {
      logger.w('[call] restore media settings failed: $e');
    }
  }

  void _logCaptureCreated(String source, MediaStream stream, DateTime started) {
    final track = stream.getVideoTracks().firstOrNull;
    logger.i(
      '[call][video] $source capture created in '
      '${DateTime.now().difference(started).inMilliseconds}ms '
      'stream=${stream.id} track=${track?.id} enabled=${track?.enabled} '
      'settings=${_diagnosticTrackSettings(track)}',
    );
  }

  Map<String, dynamic> _diagnosticTrackSettings(MediaStreamTrack? track) {
    if (track == null) return const {};
    final settings = Map<String, dynamic>.from(track.getSettings());
    for (final key in const ['deviceId', 'groupId', 'sourceId']) {
      final value = settings[key];
      if (value is String && value.isNotEmpty) {
        settings[key] = value.hashCode.toUnsigned(32).toRadixString(16);
      }
    }
    return settings;
  }

  void _scheduleCaptureDiagnostics(
    String source,
    MediaStream stream,
    RTCRtpSender? sender,
  ) {
    for (final delay in const [Duration(seconds: 1), Duration(seconds: 5)]) {
      Timer(delay, () {
        if (_ended) return;
        final track = stream.getVideoTracks().firstOrNull;
        final active =
            identical(_cameraStream, stream) ||
            identical(_screenStream, stream);
        logger.i(
          '[call][video] $source capture health after ${delay.inSeconds}s '
          'active=$active stream=${stream.id} track=${track?.id} '
          'enabled=${track?.enabled} senderTrack=${sender?.track?.id} '
          'senderAttached=${track != null && sender?.track?.id == track.id} '
          'cameraSender=${_videoSender?.track?.id} '
          'screenSender=${_screenSender?.track?.id} '
          'topology=$_topology pc=${_pc?.connectionState} '
          'ice=${_pc?.iceConnectionState} '
          'settings=${_diagnosticTrackSettings(track)}',
        );
      });
    }
  }

  void _watchCapture() {
    _captureHealthTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_checkCaptureSources());
    });
  }

  Future<void> _checkCaptureSources() async {
    if (_checkingCapture || _ended || !_isDesktop) return;
    _checkingCapture = true;
    try {
      final camera = _cameraStream;
      if (camera != null) {
        final devices = await navigator.mediaDevices.enumerateDevices();
        final id = camera.getVideoTracks().first.getSettings()['deviceId'];
        if (id is String &&
            id.isNotEmpty &&
            !devices.any((d) => d.kind == 'videoinput' && d.deviceId == id) &&
            identical(camera, _cameraStream) &&
            !_ended) {
          mediaError = 'Камера отключена. Выберите доступное устройство.';
          await setVideoEnabled(false);
        }
      }
      final source = _screenSourceId;
      final type = _screenSourceType;
      if (_localScreen && source != null && type != null) {
        final sources = await desktopCapturer.getSources(
          types: [type],
          thumbnailSize: ThumbnailSize(1, 1),
        );
        if (!sources.any((s) => s.id == source) &&
            source == _screenSourceId &&
            !_ended) {
          mediaError =
              'Источник демонстрации закрыт или недоступен. Выберите другое окно или экран.';
          await setScreenSharing(false);
        }
      }
    } catch (e) {
      logger.w('[call] capture source check: $e');
    } finally {
      _checkingCapture = false;
    }
  }

  Future<void> _startCamera({bool announce = true}) async {
    if (_localVideo) return;
    final pc = _pc;
    if (pc == null || _ended) return;
    final epoch = _captureEpoch;
    MediaStream? stream;
    final started = DateTime.now();
    try {
      final device = _cameraDeviceId;
      if (device != null) {
        final devices = await navigator.mediaDevices.enumerateDevices();
        if (!devices.any(
          (d) => d.kind == 'videoinput' && d.deviceId == device,
        )) {
          throw StateError('Камера отключена. Выберите доступное устройство.');
        }
      }
      logger.i(
        '[call][video] camera capture requested device='
        '${device?.hashCode.toUnsigned(32).toRadixString(16) ?? 'default'} '
        'topology=$_topology',
      );
      stream = await navigator.mediaDevices.getUserMedia({
        'video': {
          if (device != null) ...{
            'deviceId': device,
            'optional': [
              {'sourceId': device},
            ],
          } else
            'facingMode': 'user',
          'width': 1280,
          'height': 720,
          'frameRate': 30,
        },
        'audio': false,
      });
      if (!_captureValid(epoch, pc)) {
        await _disposeStream(stream);
        return;
      }
      final tracks = stream.getVideoTracks();
      if (tracks.isEmpty) throw StateError('Камера не предоставила видеопоток');
      _logCaptureCreated('camera', stream, started);
      if (!_captureValid(epoch, pc)) {
        await _disposeStream(stream);
        return;
      }
      final track = tracks.first;
      final sender = _videoSender;
      final senderWasAdded =
          sender == null && !_directScreenSubstitution && _topology != 'SERVER';
      if (senderWasAdded) {
        final added = await pc.addTrack(track, stream);
        if (_captureValid(epoch, pc)) _videoSender = added;
      } else if (!_directScreenSubstitution && sender != null) {
        await sender.replaceTrack(track);
      }
      if (!_captureValid(epoch, pc)) {
        await _disposeStream(stream);
        return;
      }
      _cameraStream = stream;
      cameraMirrored = track.getSettings()['facingMode'] != 'environment';
      _localVideo = true;
      mediaError = null;
      _watchCapture();
      final captured = stream;
      track.onEnded = () {
        if (identical(_cameraStream, captured)) {
          unawaited(
            setVideoEnabled(false).catchError((Object e) {
              logger.w('[call] camera ended: $e');
            }),
          );
        }
      };
      _notifyInfo();
      if (announce) await _publishMedia(renegotiate: senderWasAdded);
      _scheduleCaptureDiagnostics(
        'camera',
        stream,
        _directScreenSubstitution ? _screenSender : _videoSender,
      );
    } catch (e, st) {
      logger.e('[call][video] camera start failed', error: e, stackTrace: st);
      if (identical(_cameraStream, stream)) {
        _cameraStream = null;
        _localVideo = false;
      }
      await _disposeStream(stream);
      if (_captureValid(epoch, pc)) {
        try {
          await _videoSender?.replaceTrack(null);
        } catch (_) {}
        if (announce) await _restoreMediaSettings();
      }
      rethrow;
    }
  }

  Future<void> _stopCamera() async {
    final stream = _cameraStream;
    _cameraStream = null;
    _localVideo = false;
    await _disposeStream(stream);
    try {
      if (!_directScreenSubstitution) {
        await _videoSender?.replaceTrack(null);
      }
    } catch (_) {}
    _notifyInfo();
    if (!_ended) await _sendMediaSettings();
  }

  Future<void> _startScreenShare(DesktopCapturerSource? source) async {
    final pc = _pc;
    if (pc == null || _ended) return;
    final epoch = _captureEpoch;
    final previousStream = _screenStream;
    final previousName = _screenSourceName;
    final previousId = _screenSourceId;
    final previousType = _screenSourceType;
    final previousVideoSender = _videoSender;
    final previousScreenSender = _screenSender;
    final previousVideoTrack = previousVideoSender?.track;
    final previousDirectSubstitution = _directScreenSubstitution;
    MediaStream? stream;
    DesktopCapturerSource? selectedSource = source;
    var senderChanged = false;
    var bridgeEnabled = false;
    final started = DateTime.now();
    try {
      if (_isDesktop && source == null) {
        throw StateError('Выберите окно или экран для демонстрации');
      }
      if (_isDesktop && source != null) {
        final current = await desktopCapturer.getSources(
          types: [source.type],
          thumbnailSize: ThumbnailSize(1, 1),
        );
        selectedSource = current
            .where((candidate) => candidate.id == source.id)
            .firstOrNull;
        if (selectedSource == null) {
          throw StateError(
            'Выбранное окно или экран больше недоступны. Обновите список источников.',
          );
        }
      }
      logger.i(
        '[call][video] screen capture requested type=${selectedSource?.type} '
        'source=${selectedSource?.id.hashCode.toUnsigned(32).toRadixString(16)} '
        'topology=$_topology platform=$defaultTargetPlatform',
      );
      if (defaultTargetPlatform == TargetPlatform.android) {
        if (!await Helper.requestCapturePermission()) {
          throw StateError('Демонстрация экрана отменена');
        }
      }
      if (!_captureValid(epoch, pc)) return;
      if (previousStream == null) {
        await CallBridge.instance.setScreenShare(true);
        bridgeEnabled = true;
      }
      stream = await navigator.mediaDevices.getDisplayMedia({
        'video': selectedSource == null
            ? {
                'mandatory': {
                  'maxWidth': 1280,
                  'maxHeight': 1280,
                  'maxFrameRate': 20.0,
                },
              }
            : {
                'deviceId': {'exact': selectedSource.id},
                'mandatory': {
                  'frameRate': 30.0,
                  'maxWidth': 1920,
                  'maxHeight': 1080,
                },
              },
        'audio': false,
      });
      if (!_captureValid(epoch, pc)) {
        await _disposeStream(stream);
        await CallBridge.instance.setScreenShare(false);
        return;
      }
      final tracks = stream.getVideoTracks();
      if (tracks.isEmpty) {
        throw StateError('Источник не предоставил видеопоток');
      }
      _logCaptureCreated('screen', stream, started);
      if (!_captureValid(epoch, pc)) {
        await _disposeStream(stream);
        await CallBridge.instance.setScreenShare(false);
        return;
      }
      final track = tracks.first;
      final useDirectSubstitution = !isGroup && _topology != 'SERVER';
      var senderWasAdded = false;
      if (useDirectSubstitution) {
        final sender = _screenSender ?? _videoSender;
        if (sender == null) {
          final added = await pc.addTrack(track, stream);
          if (_captureValid(epoch, pc)) _screenSender = added;
          senderWasAdded = true;
        } else {
          await sender.replaceTrack(track);
          _screenSender = sender;
        }
        _videoSender = null;
        _directScreenSubstitution = true;
        logger.i(
          '[call][video] one-to-one DIRECT sender switched to screen '
          'track=${track.id}',
        );
      } else if (_screenSender == null && _topology != 'SERVER') {
        final added = await pc.addTrack(track, stream);
        if (_captureValid(epoch, pc)) _screenSender = added;
        senderWasAdded = true;
      } else if (_screenSender != null) {
        await _screenSender!.replaceTrack(track);
      }
      senderChanged = true;
      if (!_captureValid(epoch, pc)) {
        final restoreTrack = previousDirectSubstitution
            ? previousStream?.getVideoTracks().firstOrNull
            : previousVideoTrack;
        await (_screenSender ?? previousScreenSender)?.replaceTrack(
          restoreTrack,
        );
        _videoSender = previousVideoSender;
        _screenSender = previousScreenSender;
        _directScreenSubstitution = previousDirectSubstitution;
        await _disposeStream(stream);
        if (bridgeEnabled) await CallBridge.instance.setScreenShare(false);
        return;
      }
      _screenStream = stream;
      _screenSourceName = selectedSource?.name;
      _screenSourceId = selectedSource?.id;
      _screenSourceType = selectedSource?.type;
      _localScreen = true;
      mediaError = null;
      _watchCapture();
      final captured = stream;
      track.onEnded = () {
        if (identical(_screenStream, captured)) {
          unawaited(
            setScreenSharing(false).catchError((Object e) {
              logger.w('[call] screen capture ended: $e');
            }),
          );
        }
      };
      logger.i(
        '[call][video] screen capture started type=${selectedSource?.type} '
        'source=${selectedSource?.id.hashCode.toUnsigned(32).toRadixString(16)} '
        'track=${track.id} settings=${_diagnosticTrackSettings(track)}',
      );
      _notifyInfo();
      await _publishMedia(renegotiate: senderWasAdded);
      _scheduleCaptureDiagnostics('screen', stream, _screenSender);
      if (previousStream != null && !identical(previousStream, stream)) {
        await _disposeStream(previousStream);
      }
    } catch (e, st) {
      logger.e(
        '[call][video] screen capture start failed',
        error: e,
        stackTrace: st,
      );
      if (senderChanged) {
        try {
          final restoreTrack = previousDirectSubstitution
              ? previousStream?.getVideoTracks().firstOrNull
              : previousVideoTrack;
          await (_screenSender ?? previousScreenSender)?.replaceTrack(
            restoreTrack,
          );
        } catch (_) {}
      }
      _videoSender = previousVideoSender;
      _screenSender = previousScreenSender;
      _directScreenSubstitution = previousDirectSubstitution;
      if (identical(_screenStream, stream)) {
        _screenStream = previousStream;
        _screenSourceName = previousName;
        _screenSourceId = previousId;
        _screenSourceType = previousType;
        _localScreen = previousStream != null;
      }
      await _disposeStream(stream);
      if (bridgeEnabled) await CallBridge.instance.setScreenShare(false);
      if (_captureValid(epoch, pc)) {
        await _restoreMediaSettings();
      }
      rethrow;
    }
  }

  Future<void> _stopScreenShare() async {
    final stream = _screenStream;
    final directSubstitution = _directScreenSubstitution;
    final sender = _screenSender;
    _screenStream = null;
    _screenSourceName = null;
    _screenSourceId = null;
    _screenSourceType = null;
    _localScreen = false;
    if (directSubstitution) {
      try {
        final cameraTrack = _cameraStream?.getVideoTracks().firstOrNull;
        await sender?.replaceTrack(cameraTrack);
      } catch (_) {}
      _videoSender = sender;
      _screenSender = null;
      _directScreenSubstitution = false;
      await _applyVideoQuality();
      logger.i(
        '[call][video] one-to-one DIRECT sender restored to camera '
        'track=${_videoSender?.track?.id}',
      );
    } else {
      try {
        await _screenSender?.replaceTrack(null);
      } catch (_) {}
    }
    await _disposeStream(stream);
    await CallBridge.instance.setScreenShare(false);
    _notifyInfo();
    if (!_ended) await _sendMediaSettings();
  }

  Future<void> _clearParticipantStreams({bool dispose = true}) async {
    final candidates = [
      ..._participantStreams.values,
      ..._participantScreens.values,
      if (dispose) ..._retiredParticipantStreams,
    ];
    final streamsById = <String, MediaStream>{};
    for (final stream in candidates) {
      streamsById[stream.id] = stream;
    }
    final entries = streamsById.values.toList(growable: false);
    final ids = {..._participantStreams.keys, ..._participantScreens.keys};
    _participantStreams.clear();
    _participantScreens.clear();
    if (dispose) {
      _retiredParticipantStreams.clear();
    } else {
      _retiredParticipantStreams.addAll(entries);
    }
    for (final id in ids) {
      if (!_participantStreamUpdates.isClosed) {
        _participantStreamUpdates.add(id);
      }
    }
    if (dispose) {
      for (final stream in entries) {
        if (_borrowedRemoteStreamIds.contains(stream.id)) continue;
        try {
          await stream.dispose();
        } catch (_) {}
      }
    }
  }

  Future<void> _disposeStream(MediaStream? stream) async {
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      track.onEnded = null;
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
    _captureEpoch++;
    _captureHealthTimer?.cancel();
    _captureHealthTimer = null;
    _pendingProducerUpdate = null;
    _setState(CallSessionState.ended);
    _dispose();
  }

  // #***! освобождаем всё, соединение дорожки подписки стримы
  Future<void> _dispose() async {
    _localVideo = false;
    _localScreen = false;
    await CallBridge.instance.setScreenShare(false);
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
    _remoteTrackStreams.clear();
    _borrowedRemoteStreamIds.clear();
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
              _peerScreen = ms['isScreenSharingEnabled'] == true;
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
    final screen = ms['isScreenSharingEnabled'] == true;
    if (muted != _peerMuted || video != _peerVideo || screen != _peerScreen) {
      _peerMuted = muted;
      _peerVideo = video;
      _peerScreen = screen;
      final participant = _peerId;
      if (participant != null) {
        if (!video) {
          unawaited(_removeParticipantStream(participant, screen: false));
        }
        if (!screen) {
          unawaited(_removeParticipantStream(participant, screen: true));
        }
      }
      _notifyInfo();
      if (video || screen) unawaited(_collectReceivers());
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
