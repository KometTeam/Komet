import 'dart:async';
import 'dart:math' show cos, pi;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show MediaStream, RTCVideoRenderer, RTCVideoValue, RTCVideoViewObjectFit;
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../core/cache/info_cache.dart';
import '../../../core/calls/active_call.dart';
import '../../../core/calls/call_controller.dart';
import '../../../core/calls/call_info.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/config/app_colors.dart';
import '../../../core/config/launch_flags.dart';
import '../../../core/storage/app_database.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/screen_wake.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/official_name.dart';
import '../../widgets/call_video_view.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/sheet_helpers.dart';
import 'call_controls.dart';
import 'call_fullscreen.dart';
import 'call_glyphs.dart';
import 'call_mic_sheet.dart';
import 'call_participant_tile.dart';
import 'call_participants_sheet.dart';
import 'call_stage.dart';
import 'group_call_view.dart';
import 'komet_hub.dart';
import 'remote_screen_view.dart';
import '../../../core/config/app_fonts.dart';
import '../../../core/utils/seed_scheme.dart';

class CallScreen extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  final CallSession? session;
  final IncomingCall? incoming;
  final bool isGroup;
  final bool autoAccept;

  const CallScreen({
    super.key,
    required this.name,
    this.avatarUrl,
    this.session,
    this.incoming,
    this.isGroup = false,
    this.autoAccept = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  CallSession? _session;
  StreamSubscription<CallSessionState>? _stateSub;
  StreamSubscription<void>? _canceledSub;
  StreamSubscription<void>? _infoSub;
  StreamSubscription<void>? _kometSub;
  StreamSubscription<CallChatMessage>? _chatSub;
  StreamSubscription<MediaStream>? _remoteStreamSub;
  bool _chatOpen = false;
  bool _stageOpen = false;
  CallSessionState _state = CallSessionState.connecting;
  bool _incomingPending = false;

  bool _isMuted = false;
  bool _isSpeaker = false;

  late final AnimationController _dotsController;
  late final AnimationController _videoController;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<int, RTCVideoRenderer> _tileRenderers = {};
  StreamSubscription<int>? _tileStreamSub;
  bool _rendererReady = false;
  bool _localRendererReady = false;
  String? _attachedVideoTrackId;
  MediaStream? _pendingStream;

  Color? _seedKey;
  ColorScheme? _scheme;

  late String _name = widget.name;
  late String? _avatarUrl = widget.avatarUrl;

  final Map<int, _PeerInfo> _peerInfo = {};
  ProfileData? _selfProfile;

  bool get _isGroup => widget.isGroup || (_session?.participantCount ?? 0) > 2;

  void _onTileStream(int id) {
    final stream = _session?.streamOf(id);
    final existing = _tileRenderers[id];
    if (existing != null) {
      existing.srcObject = stream;
      if (mounted) setState(() {});
      return;
    }
    if (stream == null) return;
    unawaited(_createTileRenderer(id, stream));
  }

  Future<void> _createTileRenderer(int id, MediaStream stream) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    if (!mounted) {
      await renderer.dispose();
      return;
    }
    renderer.srcObject = stream;
    _tileRenderers[id] = renderer;
    setState(() {});
  }

  RTCVideoRenderer? _tileRenderer(CallParticipant p) {
    if (p.isSelf) return null;
    final own = _tileRenderers[p.id];
    final src = own?.srcObject;
    if (src != null && src.getVideoTracks().isNotEmpty) return own;
    return _tileVideoReady ? _remoteRenderer : null;
  }

  bool get _tileVideoReady {
    if (_session?.topology == 'SERVER') return false;
    final others = (_session?.participants ?? const <CallParticipant>[])
        .where((x) => !x.isSelf)
        .length;
    if (others != 1) return false;
    final src = _remoteRenderer.srcObject;
    return src != null && src.getVideoTracks().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    ActiveCall.instance.enterScreen();
    unawaited(ScreenWake.instance.acquire(this));
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _videoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _initRenderer();

    unawaited(_loadSelfProfile());
    _incomingPending = widget.session == null && widget.incoming != null;
    if (widget.session != null) _bind(widget.session!);

    final incoming = widget.incoming;
    if (incoming != null && (_name.isEmpty || _avatarUrl == null)) {
      _resolvePeerInfo(incoming.callerId);
    }
    if (incoming != null) {
      _canceledSub = CallController.instance.incomingCanceled.listen((_) {
        if (mounted && _incomingPending) _close();
      });
    }
    if (widget.autoAccept && incoming != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _incomingPending) _accept();
      });
    }
  }

  Future<void> _loadSelfProfile() async {
    try {
      final profile = await AppDatabase.loadActiveProfile();
      if (mounted && profile != null) setState(() => _selfProfile = profile);
    } catch (e) {
      logger.w('[call] own profile lookup failed: $e');
    }
  }

  Future<void> _resolvePeerInfo(int id) async {
    var name = ContactCache.get(id);
    var avatar = ContactCache.getAvatar(id);
    if (name == null || avatar == null) {
      final info = await ContactInfoFetch.get(id);
      if (info != null) {
        name ??= info.displayName;
        avatar ??= info.avatarUrl;
        if (name != null) ContactCache.put(id, name);
        ContactCache.putAvatar(id, avatar);
      }
    }
    if (!mounted) return;
    setState(() {
      if (name != null && name.isNotEmpty) _name = name;
      if (avatar != null && avatar.isNotEmpty) _avatarUrl = avatar;
    });
    _publishActiveCall();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    await _localRenderer.initialize();
    if (!mounted) return;
    _rendererReady = true;
    _localRendererReady = true;
    if (_pendingStream != null) {
      _remoteRenderer.srcObject = _pendingStream;
      _pendingStream = null;
    }
    _syncLocalPreview();
    setState(() {});
  }

  void _attachStream(MediaStream stream) {
    if (!_rendererReady) {
      _pendingStream = stream;
      return;
    }
    final videoTrackId = stream.getVideoTracks().firstOrNull?.id;
    if (!identical(_remoteRenderer.srcObject, stream)) {
      _remoteRenderer.srcObject = stream;
    } else if (videoTrackId != _attachedVideoTrackId) {
      _remoteRenderer.srcObject = null;
      _remoteRenderer.srcObject = stream;
    } else {
      return;
    }
    _attachedVideoTrackId = videoTrackId;
    if (mounted) setState(() {});
  }

  void _syncVideo() {
    if (_session?.peerVideo == true) {
      _videoController.forward();
    } else {
      _stageOpen = false;
      _videoController.reverse();
    }
  }

  ColorScheme _darkScheme(BuildContext context) {
    final seed = Theme.of(context).colorScheme.primary;
    if (_seedKey != seed || _scheme == null) {
      _seedKey = seed;
      _scheme = schemeFromSeed(seed, Brightness.dark);
    }
    return _scheme!;
  }

  void _bind(CallSession session) {
    _session = session;
    _state = session.currentState;
    _stateSub = session.stateStream.listen(_onState);
    _infoSub = session.infoUpdates.listen((_) {
      if (!mounted) return;
      _isMuted = session.isMuted;
      _resolveParticipants();
      _syncVideo();
      _syncLocalPreview();
      _isSpeaker = session.isSpeaker;
      setState(() {});
      _publishActiveCall();
    });
    _remoteStreamSub = session.remoteStreamStream.listen(_attachStream);
    _tileStreamSub = session.participantStreamUpdates.listen(_onTileStream);
    _kometSub = session.peerKometDetected.listen((_) => _showKometBadge());
    _chatSub = session.chatMessages.listen(_onChatMessage);
    if (session.peerIsKomet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showKometBadge());
    }
    final existing = session.remoteStream;
    if (existing != null) _attachStream(existing);
    _resolveParticipants();
    _syncVideo();
    _isSpeaker = session.isSpeaker;
    _publishActiveCall();
  }

  void _publishActiveCall() {
    final session = _session;
    if (session == null) return;
    ActiveCall.instance.attach(
      session: session,
      name: _name,
      avatarUrl: _avatarUrl,
      isGroup: _isGroup,
    );
  }

  void _showKometBadge() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showCustomNotification(context, l10n.callKometDetectedNotification);
  }

  void _onChatMessage(CallChatMessage message) {
    if (!mounted || message.mine || _chatOpen) return;
    showCustomNotification(context, message.text);
  }

  Future<void> _openKometHub() async {
    final session = _session;
    if (session == null) return;
    setState(() => _chatOpen = true);
    await showKometHub(context, session: session, scheme: _darkScheme(context));
    if (mounted) setState(() => _chatOpen = false);
  }

  void _resolveParticipants() {
    final session = _session;
    if (session == null) return;
    for (final p in session.participants) {
      final ext = p.externalId;
      if (ext == null || p.isSelf || _peerInfo.containsKey(ext)) continue;
      _peerInfo[ext] = const _PeerInfo(resolving: true);
      unawaited(_resolveParticipant(ext));
    }
  }

  Future<void> _resolveParticipant(int id) async {
    var name = ContactCache.get(id);
    var avatar = ContactCache.getAvatar(id);
    if (name == null) {
      final info = await ContactInfoFetch.get(id);
      if (info != null) {
        name = info.displayName;
        avatar ??= info.avatarUrl;
        if (name != null) ContactCache.put(id, name);
        ContactCache.putAvatar(id, avatar);
      }
    }
    if (!mounted) return;
    setState(() => _peerInfo[id] = _PeerInfo(name: name, avatar: avatar));
  }

  void _onState(CallSessionState state) {
    if (!mounted) return;
    setState(() => _state = state);
    if (state == CallSessionState.ended) _close();
  }

  Future<void> _accept() async {
    final incoming = widget.incoming;
    if (incoming == null) return;
    setState(() {
      _incomingPending = false;
      _state = CallSessionState.connecting;
    });
    try {
      final session = await CallController.instance.acceptIncoming(incoming);
      if (!mounted) return;
      _bind(session);
    } catch (_) {
      _close();
    }
  }

  Future<void> _decline() async {
    final incoming = widget.incoming;
    if (incoming != null) {
      await CallController.instance.rejectIncoming(incoming);
    }
    _close();
  }

  // #***! пока принятие ещё идёт, своей сессии у экрана нет, но контроллер её
  // уже держит: без этого кнопка закрывала экран, а звонок соединялся дальше
  Future<void> _hangup() async {
    final session = _session ?? CallController.instance.activeSession;
    if (session != null) {
      await session.hangup();
    }
    _close();
  }

  void _close() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _toggleMute() async {
    final next = !_isMuted;
    setState(() => _isMuted = next);
    await _session?.setMuted(next);
  }

  Future<void> _toggleSpeaker() async {
    final session = _session;
    if (session == null) return;
    final next = !session.isSpeaker;
    setState(() => _isSpeaker = next);
    await session.setSpeaker(next);
  }

  bool _videoBusy = false;

  Future<void> _toggleVideo() async {
    final session = _session;
    if (session == null || _videoBusy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _videoBusy = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await session.setVideoEnabled(!session.localVideo);
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, l10n.callCameraUnavailable(e));
      }
    } finally {
      _syncLocalPreview();
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  Future<void> _switchCamera() async {
    final session = _session;
    if (session == null || _videoBusy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _videoBusy = true);
    try {
      await session.switchCamera();
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, l10n.callCameraUnavailable(e));
      }
    } finally {
      _syncLocalPreview();
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  Future<void> _toggleScreen() async {
    final session = _session;
    if (session == null || _videoBusy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _videoBusy = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await session.setScreenSharing(!session.localScreen);
    } catch (e) {
      if (mounted) {
        showCustomNotification(context, l10n.callScreenShareFailed('$e'));
      }
    } finally {
      _syncLocalPreview();
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  void _syncLocalPreview() {
    if (!_localRendererReady) return;
    _localRenderer.srcObject = _session?.localVideoStream;
  }

  @override
  void dispose() {
    ActiveCall.instance.leaveScreen();
    unawaited(ScreenWake.instance.release(this));
    _stateSub?.cancel();
    _canceledSub?.cancel();
    _infoSub?.cancel();
    _kometSub?.cancel();
    _chatSub?.cancel();
    _remoteStreamSub?.cancel();
    _tileStreamSub?.cancel();
    for (final renderer in _tileRenderers.values) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    _tileRenderers.clear();
    _dotsController.dispose();
    _videoController.dispose();
    if (_rendererReady) _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();
    if (_localRendererReady) _localRenderer.srcObject = null;
    _localRenderer.dispose();
    super.dispose();
  }

  CallParticipantView _participantView(CallParticipant p) {
    final l10n = AppLocalizations.of(context)!;
    if (p.isSelf) {
      final profile = _selfProfile;
      return CallParticipantView(
        name: l10n.callParticipantYou,
        avatarUrl: profile?.baseUrl,
        contactId: profile?.id,
      );
    }
    final ext = p.externalId;
    final info = ext != null ? _peerInfo[ext] : null;
    return CallParticipantView(
      name: info?.name?.isNotEmpty == true
          ? info!.name!
          : l10n.callParticipantFallback,
      avatarUrl: info?.avatar,
      contactId: ext,
    );
  }

  Widget? _tileMedia(
    CallParticipant p,
    Widget avatar, {
    CallVideoSource? source,
    bool stage = false,
  }) {
    final session = _session;
    if (session == null) return null;
    final fit = stage
        ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
        : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover;
    if (p.isSelf) {
      final local = switch (source) {
        CallVideoSource.camera => session.localVideo,
        CallVideoSource.screen => session.localScreen,
        null => session.localVideo || session.localScreen,
      };
      if (!local || !_localRendererReady || _localRenderer.srcObject == null) {
        return null;
      }
      return CallVideoView(
        renderer: _localRenderer,
        mirror: !session.localScreen,
        objectFit: session.localScreen
            ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
            : fit,
        placeholder: avatar,
      );
    }
    final renderer = _tileRenderer(p);
    Widget? video(bool live) => live && renderer != null
        ? CallVideoView(renderer: renderer, objectFit: fit, placeholder: avatar)
        : null;
    Widget screen(Widget fallback) => RemoteScreenView(
      screen: session.remoteScreenOf(p.id),
      fallback: fallback,
    );
    return switch (source) {
      CallVideoSource.camera => video(p.videoEnabled),
      CallVideoSource.screen => screen(video(p.screenSharing) ?? avatar),
      null when p.screenSharing => screen(video(true) ?? avatar),
      null => video(p.videoEnabled),
    };
  }

  void _showMicrophones() {
    final session = _session;
    if (session == null) return;
    showCallMicrophoneSheet(
      context,
      session: session,
      scheme: _darkScheme(context),
    );
  }

  void _showInfoSheet() {
    final cs = _darkScheme(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: kSheetShape,
      builder: (_) => Theme(
        data: Theme.of(context).copyWith(colorScheme: cs),
        child: _CallInfoSheet(
          session: _session,
          incoming: widget.incoming,
          name: _displayName,
          renderer: _remoteRenderer,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = _darkScheme(context);
    final group = _isGroup && !_incomingPending;
    final stage = !group && _stageOpen && _session?.peerVideo == true;

    final Widget body = group
        ? _buildGroupBody(cs)
        : AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: stage
                ? KeyedSubtree(
                    key: const ValueKey('stage'),
                    child: _buildStage(cs),
                  )
                : AnimatedBuilder(
                    key: const ValueKey('call'),
                    animation: _videoController,
                    builder: (context, _) => _buildBody(
                      cs,
                      avatar: _buildAvatar(cs),
                      name: _buildName(cs),
                      status: _buildStatus(cs),
                      peerBar: _peerStateBar(cs),
                      controls: _buildControls(cs),
                    ),
                  ),
          );

    return Theme(
      data: Theme.of(context).copyWith(colorScheme: cs),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: cs.surface,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: cs.surface,
          body: Stack(
            children: [
              body,
              if (!group &&
                  !stage &&
                  (_session?.localVideo == true ||
                      _session?.localScreen == true))
                _localPreview(cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _localPreview(ColorScheme cs) {
    return Positioned(
      right: 16,
      top: MediaQuery.of(context).padding.top + 56,
      child: SafeArea(
        child: Container(
          width: 96,
          height: 140,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outlineVariant, width: 1),
          ),
          child: _localRendererReady && _localRenderer.srcObject != null
              ? CallVideoView(
                  renderer: _localRenderer,
                  mirror: _session?.localScreen != true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  placeholder: _localPreviewIcon(cs),
                )
              : _localPreviewIcon(cs),
        ),
      ),
    );
  }

  Widget _localPreviewIcon(ColorScheme cs) => Center(
    child: Icon(
      _session?.localScreen == true ? Symbols.screen_share : Symbols.videocam,
      color: cs.onSurfaceVariant,
      size: 28,
    ),
  );

  Widget _buildGroupBody(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    if (session == null) {
      return SafeArea(
        child: Center(child: _statusWithDots(cs, l10n.callStatusConnecting)),
      );
    }
    return GroupCallView(
      session: session,
      title: _name.isEmpty ? l10n.callGroupTitle : _name,
      resolve: _participantView,
      mediaOf: _tileMedia,
      videoOf: _tileRenderer,
      muted: _isMuted,
      speakerOn: _isSpeaker,
      videoBusy: _videoBusy,
      onToggleMute: _toggleMute,
      onToggleSpeaker: _toggleSpeaker,
      onToggleVideo: _toggleVideo,
      onSwitchCamera: _switchCamera,
      onToggleScreen: _toggleScreen,
      onHangup: _hangup,
      onMinimize: () => Navigator.of(context).maybePop(),
      onShowMicrophones: _showMicrophones,
      onShowInfo: _showInfoSheet,
    );
  }

  Widget _buildStage(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session!;
    final screen = session.peerScreen;
    final wide =
        MediaQuery.sizeOf(context).width >= GroupCallView.wideBreakpoint;
    final avatar = Center(child: _avatarCircle(144, cs));
    final camera = _remoteRenderer.srcObject == null
        ? avatar
        : CallVideoView(
            renderer: _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
            placeholder: avatar,
          );
    final strip = <String>[
      if (screen && session.peerCamera) 'peer',
      if (session.localVideo || session.localScreen) 'self',
    ];
    final peer = session.peerUserId;
    Widget stage(VoidCallback toggle, {bool fullscreen = false}) => CallStage(
      key: ValueKey(screen),
      media: _peerScreenOr(camera),
      label: screen ? l10n.callScreenOf(_displayName) : _displayName,
      labelIcon: screen ? Symbols.screen_share : Symbols.videocam,
      collapseTooltip: l10n.callExitFocus,
      onCollapse: () => setState(() => _stageOpen = false),
      fullscreenTooltip: fullscreen
          ? l10n.callExitFullscreen
          : l10n.callEnterFullscreen,
      onToggleFullscreen: toggle,
      fullscreen: fullscreen,
    );
    return CallFullscreenScope(
      stage: screen,
      screen: screen && peer != null ? session.remoteScreenOf(peer) : null,
      video: _remoteRenderer,
      builder: (context, fullscreen, toggle) => fullscreen
          ? stage(toggle, fullscreen: true)
          : SafeArea(
              child: Column(
                children: [
                  _buildTopBar(cs, 1, stage: true),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: stage(toggle),
                    ),
                  ),
                  if (strip.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: CallStrip<String>(
                        ids: strip,
                        height: wide ? 120 : 92,
                        tileBuilder: (context, id, size) => id == 'peer'
                            ? _peerStripTile(session)
                            : _selfStripTile(session),
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildControls(cs),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _peerStripTile(CallSession session) => CallParticipantTile(
    name: _displayName,
    avatarUrl: _avatarUrl,
    muted: session.peerMuted,
    media: (avatar) => CallVideoView(
      renderer: _remoteRenderer,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      placeholder: avatar,
    ),
  );

  Widget _selfStripTile(CallSession session) {
    final profile = _selfProfile;
    return CallParticipantTile(
      name: AppLocalizations.of(context)!.callParticipantYou,
      avatarUrl: profile?.baseUrl,
      userId: profile?.id,
      muted: _isMuted,
      media: (avatar) => _localRendererReady && _localRenderer.srcObject != null
          ? CallVideoView(
              renderer: _localRenderer,
              mirror: !session.localScreen,
              objectFit: session.localScreen
                  ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                  : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              placeholder: avatar,
            )
          : null,
    );
  }

  Widget _peerScreenOr(Widget video) {
    final session = _session;
    final peer = session?.peerUserId;
    if (session == null || peer == null || !session.peerScreen) return video;
    return RemoteScreenView(
      screen: session.remoteScreenOf(peer),
      fallback: video,
    );
  }

  Widget _buildBody(
    ColorScheme cs, {
    required Widget avatar,
    required Widget name,
    required Widget status,
    required Widget? peerBar,
    required Widget controls,
  }) {
    final t = Curves.easeInOut.transform(_videoController.value);
    final showVideo = t > 0.001 && _remoteRenderer.srcObject != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (showVideo)
          Center(
            child: Opacity(
              opacity: t,
              child: FractionallySizedBox(
                widthFactor: 0.62 + 0.38 * t,
                heightFactor: 0.46 + 0.54 * t,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24 * (1 - t)),
                  child: _peerScreenOr(
                    ValueListenableBuilder<RTCVideoValue>(
                      valueListenable: _remoteRenderer,
                      builder: (context, value, _) {
                        final ar = value.aspectRatio > 0
                            ? value.aspectRatio
                            : 16 / 9;
                        return Center(
                          child: AspectRatio(
                            aspectRatio: ar,
                            child: RepaintBoundary(
                              child: CallVideoView(
                                renderer: _remoteRenderer,
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (t > 0.001)
          IgnorePointer(
            child: Opacity(opacity: t, child: _videoScrim(cs)),
          ),
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(cs, t),
              const Spacer(flex: 2),
              _collapse(t, avatar),
              SizedBox(height: 36 * (1 - t)),
              _collapse(t, name),
              SizedBox(height: 12 * (1 - t)),
              _collapse(t, status),
              if (peerBar != null) ...[
                SizedBox(height: 14 * (1 - t)),
                _collapse(t, peerBar),
              ],
              const Spacer(flex: 5),
              controls,
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _collapse(double t, Widget child) {
    if (t <= 0.001) return child;
    if (t >= 0.999) return const SizedBox.shrink();
    return Opacity(
      opacity: 1 - t,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: 1 - t,
          child: child,
        ),
      ),
    );
  }

  Widget _videoScrim(ColorScheme cs) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            cs.surface.withValues(alpha: 0.55),
            Colors.transparent,
            Colors.transparent,
            cs.surface.withValues(alpha: 0.65),
          ],
          stops: const [0.0, 0.34, 0.70, 1.0],
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs, double t, {bool stage = false}) {
    final l10n = AppLocalizations.of(context)!;
    final expandable = !stage && t > 0.5 && _session?.peerVideo == true;
    final showTimer =
        t > 0.001 &&
        _session != null &&
        _state == CallSessionState.active &&
        _session!.mediaConnected;
    return SizedBox(
      height: 48,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: l10n.callTooltipMinimize,
              icon: Icon(
                Symbols.close_fullscreen,
                color: cs.onSurface,
                weight: 500,
                size: 26,
              ),
            ),
          ),
          if (_session != null)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (expandable)
                    IconButton(
                      onPressed: () => setState(() => _stageOpen = true),
                      tooltip: l10n.callTooltipExpand,
                      icon: Icon(
                        Symbols.open_in_full,
                        color: cs.onSurface,
                        weight: 500,
                        size: 24,
                      ),
                    ),
                  if (_session?.peerIsKomet == true)
                    IconButton(
                      onPressed: _openKometHub,
                      tooltip: l10n.callTooltipKometHub,
                      icon: Icon(
                        Symbols.auto_awesome,
                        color: cs.primary,
                        weight: 500,
                        size: 26,
                      ),
                    ),
                  IconButton(
                    onPressed: _showMicrophones,
                    tooltip: l10n.callTooltipMicrophone,
                    icon: Icon(
                      Symbols.settings_voice,
                      color: cs.onSurface,
                      weight: 500,
                      size: 26,
                    ),
                  ),
                  IconButton(
                    onPressed: _showInfoSheet,
                    tooltip: l10n.callInfoTitle,
                    icon: Icon(
                      Symbols.info,
                      color: cs.onSurface,
                      weight: 500,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          if (showTimer)
            Align(
              alignment: Alignment.center,
              child: Opacity(
                opacity: t,
                child: _ElapsedText(
                  session: _session!,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _peerStateBar(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final session = _session;
    if (session == null) return null;
    final pills = <Widget>[
      if (session.peerMuted)
        _statePill(cs, Symbols.mic_off, l10n.callPeerMicOff),
      if (session.peerVideo)
        _statePill(cs, Symbols.videocam, l10n.callPeerCameraOn),
    ];
    if (pills.isEmpty) return null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: pills,
    );
  }

  Widget _statePill(ColorScheme cs, IconData icon, String label) {
    return GlossyPill(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(100),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      depth: 5,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant, fill: 1),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ColorScheme cs) {
    final avatarSize = (MediaQuery.of(context).size.shortestSide * 0.42).clamp(
      128.0,
      172.0,
    );
    return _avatarCircle(avatarSize, cs);
  }

  String get _displayName =>
      _name.isEmpty ? AppLocalizations.of(context)!.callUnknownName : _name;

  Widget _avatarCircle(double size, ColorScheme cs) =>
      _circleAvatar(size, cs, name: _displayName, url: _avatarUrl);

  Widget _circleAvatar(
    double size,
    ColorScheme cs, {
    required String name,
    String? url,
  }) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surfaceContainerHighest,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: (url != null && url.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 420,
              memCacheHeight: 420,
              errorWidget: (_, _, _) => _avatarFallback(size, cs, name),
            )
          : _avatarFallback(size, cs, name),
    );
  }

  Widget _avatarFallback(double size, ColorScheme cs, String name) {
    final letter = (name.isEmpty ? '?' : name[0]).toUpperCase();
    return Container(
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          fontFamily: displayFontOf(context),
        ),
      ),
    );
  }

  Widget _buildName(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: OfficialName(
        contactId: _session?.peerUserId ?? 0,
        text: _displayName,
        textAlign: TextAlign.center,
        iconSize: 18,
        maxLines: 2,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 30,
          fontWeight: FontWeight.w600,
          fontFamily: displayFontOf(context),
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildStatus(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    if (!_incomingPending && _state == CallSessionState.active) {
      final session = _session;
      if (session == null) return const SizedBox.shrink();
      if (!session.mediaConnected) {
        return _statusWithDots(cs, l10n.callStatusConnecting);
      }
      return _ElapsedText(
        session: session,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      );
    }

    if (_incomingPending) {
      return Text(
        l10n.callIncoming,
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
      );
    }

    String text;
    switch (_state) {
      case CallSessionState.connecting:
        text = l10n.callStatusConnecting;
      case CallSessionState.ringing:
        text = l10n.callStatusRinging;
      case CallSessionState.active:
        text = '';
      case CallSessionState.ended:
        text = l10n.callStatusEnded;
    }

    return _statusWithDots(cs, text);
  }

  Widget _statusWithDots(ColorScheme cs, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
        const SizedBox(width: 4),
        _CallingDots(animation: _dotsController, color: cs.onSurfaceVariant),
      ],
    );
  }

  Widget _buildControls(ColorScheme cs) {
    if (_incomingPending) return _incomingControls(cs);
    return _activeControls(cs);
  }

  Widget _incomingControls(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CallButton(
            icon: Symbols.call_end,
            label: l10n.callDecline,
            background: kDangerRed,
            foreground: Colors.white,
            onTap: _decline,
          ),
          CallButton(
            icon: Symbols.call,
            label: l10n.callAccept,
            background: kSuccessGreen,
            foreground: Colors.white,
            onTap: _accept,
          ),
        ],
      ),
    );
  }

  Widget _activeControls(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final video = _session?.localVideo == true;
    final screen = _session?.localScreen == true;
    return CallControlBar(
      children: [
        CallButton(
          icon: Symbols.volume_up,
          glyph: CallSpeakerGlyph(loud: _isSpeaker),
          label: l10n.callSpeaker,
          background: _isSpeaker ? cs.primary : cs.surfaceContainerHighest,
          foreground: _isSpeaker ? cs.onPrimary : cs.onSurface,
          onTap: _toggleSpeaker,
        ),
        CallButton(
          icon: Symbols.videocam,
          slashedIcon: Symbols.videocam_off,
          slashed: !video,
          label: l10n.callVideoLabel,
          background: video ? cs.primary : cs.surfaceContainerHighest,
          foreground: video ? cs.onPrimary : cs.onSurface,
          busy: _videoBusy,
          onTap: _toggleVideo,
        ),
        if (video)
          CallButton(
            icon: Symbols.cameraswitch,
            label: l10n.callSwitchCamera,
            background: cs.surfaceContainerHighest,
            foreground: cs.onSurface,
            busy: _videoBusy,
            onTap: _switchCamera,
          ),
        CallButton(
          icon: Symbols.screen_share,
          glyph: CallScreenGlyph(sharing: screen),
          label: l10n.callScreenLabel,
          background: screen ? cs.primary : cs.surfaceContainerHighest,
          foreground: screen ? cs.onPrimary : cs.onSurface,
          busy: _videoBusy,
          onTap: _toggleScreen,
        ),
        CallButton(
          icon: Symbols.mic,
          slashedIcon: Symbols.mic_off,
          slashed: _isMuted,
          label: _isMuted
              ? (LaunchFlags.noMute ? l10n.callMicStillLive : l10n.callUnmute)
              : l10n.callMute,
          background: _isMuted ? cs.primary : cs.surfaceContainerHighest,
          foreground: _isMuted ? cs.onPrimary : cs.onSurface,
          onTap: _toggleMute,
          onLongPress: _showMicrophones,
          micLevels: _session?.micLevels,
        ),
        CallButton(
          icon: Symbols.call_end,
          label: l10n.callEndButton,
          background: kDangerRed,
          foreground: Colors.white,
          onTap: _hangup,
        ),
      ],
    );
  }
}

class _PeerInfo {
  final String? name;
  final String? avatar;
  final bool resolving;

  const _PeerInfo({this.name, this.avatar, this.resolving = false});
}

class _CallingDots extends StatelessWidget {
  final Animation<double> animation;
  final Color color;

  const _CallingDots({required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = animation.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (v + i / 3) % 1.0;
            final alpha = 0.3 + 0.7 * (0.5 - 0.5 * cos(phase * 2 * pi));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: alpha),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ElapsedText extends StatefulWidget {
  final CallSession session;
  final TextStyle style;

  const _ElapsedText({required this.session, required this.style});

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatSecondsMmSs(widget.session.elapsedSeconds, padMinutes: true),
      style: widget.style,
    );
  }
}

class _CallInfoSheet extends StatelessWidget {
  final CallSession? session;
  final IncomingCall? incoming;
  final String name;
  final RTCVideoRenderer renderer;

  const _CallInfoSheet({
    required this.session,
    required this.incoming,
    required this.name,
    required this.renderer,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final info = session?.info;

    final rows = <List<String>>[];
    void add(String k, String? v) {
      if (v != null && v.isNotEmpty) rows.add([k, v]);
    }

    add(l10n.callInfoClient, _clientLine(info));
    add(l10n.callInfoPlatform, info?.peerPlatform);
    add(l10n.callInfoCountry, incoming?.country);
    final isContact = incoming?.isContact;
    if (isContact != null) {
      add(
        l10n.callInfoInContacts,
        isContact ? l10n.callValueYes : l10n.callValueNo,
      );
    }
    add(l10n.callInfoPeerIp, info?.peerIp);
    add(l10n.callInfoPeerNetwork, info?.peerNetwork);
    add(l10n.callInfoPath, info?.path);
    add(l10n.callInfoCodec, info?.audioCodec);
    add(l10n.callInfoServer, info?.region);
    add(l10n.callInfoTopology, info?.topology);
    add(l10n.callInfoConversationId, info?.conversationId);
    if (info?.dtlsFingerprint != null) {
      add('DTLS', _shortFp(info!.dtlsFingerprint!));
    }
    if (session != null) {
      add(
        l10n.callInfoStatus,
        session!.mediaConnected
            ? l10n.callStatusValueConnected
            : l10n.callStatusValueConnecting,
      );
      add(
        l10n.callInfoPeerMic,
        session!.peerMuted ? l10n.callMicValueOff : l10n.callMicValueOn,
      );
      add(
        l10n.callInfoPeerCamera,
        session!.peerCamera ? l10n.callCameraValueOn : l10n.callCameraValueOff,
      );
    }

    final vtracks = renderer.srcObject?.getVideoTracks().length ?? 0;
    add(
      l10n.callInfoVideoTrack,
      vtracks > 0 ? l10n.callInfoVideoTrackPresent(vtracks) : l10n.callValueNo,
    );
    final w = renderer.value.width.toInt();
    final h = renderer.value.height.toInt();
    add(l10n.callInfoVideoSize, (w > 0 && h > 0) ? '$w×$h' : '—');
    add(
      l10n.callInfoFrameRendering,
      renderer.renderVideo ? l10n.callValueYes : l10n.callValueNo,
    );

    final badges = <Widget>[
      _badge(cs, Symbols.call, l10n.callBadgeAudio),
      if (info?.record == true)
        _badge(cs, Symbols.radio_button_checked, l10n.callBadgeRecording),
      if (info?.denoise == true)
        _badge(cs, Symbols.noise_control_on, l10n.callBadgeNoiseSuppression),
      if (info?.animoji == true)
        _badge(cs, Symbols.mood, l10n.callBadgeAnimoji),
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.callInfoTitle,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: displayFontOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: badges),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Text(
                  l10n.callInfoNoDataYet,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          r[0],
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SelectableText(
                          r[1],
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _clientLine(CallInfo? info) {
    if (info == null) return null;
    final engine = info.peerEngine;
    if (engine == null || engine == 'неизвестно') return null;
    return engine;
  }

  String _shortFp(String fp) => fp.length > 34 ? '${fp.substring(0, 34)}…' : fp;

  Widget _badge(ColorScheme cs, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant, fill: 1),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
