import 'dart:async';
import 'dart:math' show cos, pi;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show
        Helper,
        MediaStream,
        RTCVideoRenderer,
        RTCVideoValue,
        RTCVideoView,
        RTCVideoViewObjectFit;
import 'package:material_symbols_icons/symbols.dart';

import '../../../backend/modules/messages.dart' show ContactCache;
import '../../../core/cache/info_cache.dart';
import '../../../core/calls/call_controller.dart';
import '../../../core/calls/call_info.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/utils/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/custom_notification.dart';
import '../../widgets/glossy_pill.dart';
import '../../widgets/sheet_helpers.dart';
import 'komet_hub.dart';

const Color _kEndRed = Color(0xFFE5484D);
const Color _kAcceptGreen = Color(0xFF2EC36B);

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
  CallSessionState _state = CallSessionState.connecting;
  bool _incomingPending = false;

  bool _isMuted = false;
  bool _isSpeaker = false;

  late final AnimationController _dotsController;
  late final AnimationController _videoController;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _rendererReady = false;
  bool _localRendererReady = false;
  bool _videoAttached = false;
  MediaStream? _pendingStream;

  Color? _seedKey;
  ColorScheme? _scheme;

  late String _name = widget.name;
  late String? _avatarUrl = widget.avatarUrl;

  final Map<int, _PeerInfo> _peerInfo = {};

  bool get _isGroup => widget.isGroup || (_session?.participantCount ?? 0) > 2;

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
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _videoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _initRenderer();

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
    final hasVideo = stream.getVideoTracks().isNotEmpty;
    if (!identical(_remoteRenderer.srcObject, stream)) {
      _remoteRenderer.srcObject = stream;
    } else if (hasVideo && !_videoAttached) {
      _remoteRenderer.srcObject = null;
      _remoteRenderer.srcObject = stream;
    } else {
      return;
    }
    if (hasVideo) _videoAttached = true;
    if (mounted) setState(() {});
  }

  void _syncVideo() {
    if (_session?.peerVideo == true) {
      _videoController.forward();
    } else {
      _videoController.reverse();
    }
  }

  ColorScheme _darkScheme(BuildContext context) {
    final seed = Theme.of(context).colorScheme.primary;
    if (_seedKey != seed || _scheme == null) {
      _seedKey = seed;
      _scheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
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
      setState(() {});
    });
    _remoteStreamSub = session.remoteStreamStream.listen(_attachStream);
    _kometSub = session.peerKometDetected.listen((_) => _showKometBadge());
    _chatSub = session.chatMessages.listen(_onChatMessage);
    if (session.peerIsKomet) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showKometBadge());
    }
    final existing = session.remoteStream;
    if (existing != null) _attachStream(existing);
    _resolveParticipants();
    _syncVideo();
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

  Future<void> _hangup() async {
    final session = _session;
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
    final next = !_isSpeaker;
    setState(() => _isSpeaker = next);
    await Helper.setSpeakerphoneOn(next);
  }

  bool _videoBusy = false;

  Future<void> _toggleVideo() async {
    final session = _session;
    if (session == null || _videoBusy) return;
    setState(() => _videoBusy = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await session.setVideoEnabled(!session.localVideo);
    } finally {
      _syncLocalPreview();
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  Future<void> _toggleScreen() async {
    final session = _session;
    if (session == null || _videoBusy) return;
    setState(() => _videoBusy = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await session.setScreenSharing(!session.localScreen);
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
    _stateSub?.cancel();
    _canceledSub?.cancel();
    _infoSub?.cancel();
    _kometSub?.cancel();
    _chatSub?.cancel();
    _remoteStreamSub?.cancel();
    _dotsController.dispose();
    _videoController.dispose();
    _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();
    _localRenderer.srcObject = null;
    _localRenderer.dispose();
    super.dispose();
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

    final Widget body = group
        ? _buildGroupBody(cs)
        : AnimatedBuilder(
            animation: _videoController,
            builder: (context, _) => _buildBody(
              cs,
              avatar: _buildAvatar(cs),
              name: _buildName(cs),
              status: _buildStatus(cs),
              peerBar: _peerStateBar(cs),
              controls: _buildControls(cs),
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
              if (_session?.localVideo == true || _session?.localScreen == true)
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
              ? RTCVideoView(
                  _localRenderer,
                  mirror: _session?.localScreen != true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              : Center(
                  child: Icon(
                    _session?.localScreen == true
                        ? Symbols.screen_share
                        : Symbols.videocam,
                    color: cs.onSurfaceVariant,
                    size: 28,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildGroupBody(ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    final participants = _session?.participants ?? const <CallParticipant>[];
    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(cs, 0),
          const SizedBox(height: 4),
          _groupHeader(cs, participants.length),
          const SizedBox(height: 8),
          Expanded(
            child: participants.isEmpty
                ? Center(child: _statusWithDots(cs, l10n.callStatusConnecting))
                : _participantGrid(cs, participants),
          ),
          const SizedBox(height: 12),
          _activeControls(cs),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _groupHeader(ColorScheme cs, int count) {
    final l10n = AppLocalizations.of(context)!;
    final String subtitle;
    if (count == 0) {
      subtitle = l10n.callGroupConnecting;
    } else if (count <= 1) {
      subtitle = l10n.callGroupWaitingParticipants;
    } else {
      subtitle =
          '$count ${pluralRu(count, 'участник', 'участника', 'участников')}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            _displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _participantGrid(ColorScheme cs, List<CallParticipant> ps) {
    final cols = ps.length <= 1
        ? 1
        : ps.length <= 4
        ? 2
        : 3;
    return GridView.count(
      crossAxisCount: cols,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.84,
      children: [for (final p in ps) _participantTile(cs, p)],
    );
  }

  Widget _participantTile(ColorScheme cs, CallParticipant p) {
    final l10n = AppLocalizations.of(context)!;
    final ext = p.externalId;
    final info = ext != null ? _peerInfo[ext] : null;
    final name = p.isSelf
        ? l10n.callParticipantYou
        : (info?.name?.isNotEmpty == true
              ? info!.name!
              : l10n.callParticipantFallback);
    final url = p.isSelf ? _avatarUrl : info?.avatar;
    final muted = p.isSelf ? _isMuted : !p.audioEnabled;
    final speaking = !muted && _session?.isSpeaking(p.id) == true;
    final showVideo =
        !p.isSelf && (p.videoEnabled || p.screenSharing) && _tileVideoReady;

    return GlossyPill(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      depth: 6,
      borderSide: speaking
          ? const BorderSide(color: _kAcceptGreen, width: 2.5)
          : null,
      padding: EdgeInsets.all(showVideo ? 0 : 12),
      child: showVideo
          ? _videoTile(cs, name, muted, p.handRaised, p.screenSharing)
          : _avatarTile(cs, name, url, muted, p.handRaised, p.screenSharing),
    );
  }

  Widget _avatarTile(
    ColorScheme cs,
    String name,
    String? url,
    bool muted,
    bool hand,
    bool screen,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest.shortestSide.clamp(48.0, 96.0);
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _circleAvatar(size, cs, name: name, url: url),
                      if (hand)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: _tileBadge(
                            cs,
                            Symbols.front_hand,
                            cs.tertiaryContainer,
                            cs.onTertiaryContainer,
                          ),
                        ),
                      if (screen)
                        Positioned(
                          top: -2,
                          left: -2,
                          child: _tileBadge(
                            cs,
                            Symbols.screen_share,
                            cs.primaryContainer,
                            cs.onPrimaryContainer,
                          ),
                        ),
                      if (muted)
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: _tileBadge(
                            cs,
                            Symbols.mic_off,
                            cs.surfaceContainerHighest,
                            cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _videoTile(
    ColorScheme cs,
    String name,
    bool muted,
    bool hand,
    bool screen,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RTCVideoView(
            _remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                if (muted)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Symbols.mic_off,
                      size: 16,
                      color: Colors.white,
                      fill: 1,
                    ),
                  ),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hand)
            Positioned(
              top: 8,
              right: 8,
              child: _tileBadge(
                cs,
                Symbols.front_hand,
                cs.tertiaryContainer,
                cs.onTertiaryContainer,
              ),
            ),
          if (screen)
            Positioned(
              top: 8,
              left: 8,
              child: _tileBadge(
                cs,
                Symbols.screen_share,
                cs.primaryContainer,
                cs.onPrimaryContainer,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tileBadge(ColorScheme cs, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: cs.surface, width: 2),
      ),
      child: Icon(icon, size: 14, color: fg, fill: 1),
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
                  child: ValueListenableBuilder<RTCVideoValue>(
                    valueListenable: _remoteRenderer,
                    builder: (context, value, _) {
                      final ar = value.aspectRatio > 0
                          ? value.aspectRatio
                          : 16 / 9;
                      return Center(
                        child: AspectRatio(
                          aspectRatio: ar,
                          child: RepaintBoundary(
                            child: RTCVideoView(
                              _remoteRenderer,
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

  Widget _buildTopBar(ColorScheme cs, double t) {
    final l10n = AppLocalizations.of(context)!;
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
      if (session.peerMuted) _statePill(cs, Symbols.mic_off, l10n.callPeerMicOff),
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
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildName(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        _displayName,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurface,
          fontSize: 30,
          fontWeight: FontWeight.w600,
          fontFamily: 'Outfit',
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
          _CallButton(
            icon: Symbols.call_end,
            label: l10n.callDecline,
            background: _kEndRed,
            foreground: Colors.white,
            onTap: _decline,
          ),
          _CallButton(
            icon: Symbols.call,
            label: l10n.callAccept,
            background: _kAcceptGreen,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CallButton(
            icon: _isSpeaker ? Symbols.volume_up : Symbols.volume_down,
            label: l10n.callSpeaker,
            background: _isSpeaker ? cs.primary : cs.surfaceContainerHighest,
            foreground: _isSpeaker ? cs.onPrimary : cs.onSurface,
            onTap: _toggleSpeaker,
          ),
          _CallButton(
            icon: video ? Symbols.videocam : Symbols.videocam_off,
            label: l10n.callVideoLabel,
            background: video ? cs.primary : cs.surfaceContainerHighest,
            foreground: video ? cs.onPrimary : cs.onSurface,
            busy: _videoBusy,
            onTap: _toggleVideo,
          ),
          _CallButton(
            icon: Symbols.screen_share,
            label: l10n.callScreenLabel,
            background: screen ? cs.primary : cs.surfaceContainerHighest,
            foreground: screen ? cs.onPrimary : cs.onSurface,
            busy: _videoBusy,
            onTap: _toggleScreen,
          ),
          _CallButton(
            icon: _isMuted ? Symbols.mic_off : Symbols.mic,
            label: _isMuted ? l10n.callUnmute : l10n.callMute,
            background: _isMuted ? cs.primary : cs.surfaceContainerHighest,
            foreground: _isMuted ? cs.onPrimary : cs.onSurface,
            onTap: _toggleMute,
          ),
          _CallButton(
            icon: Symbols.call_end,
            label: l10n.callEndButton,
            background: _kEndRed,
            foreground: Colors.white,
            onTap: _hangup,
          ),
        ],
      ),
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

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool busy;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 62,
          height: 62,
          child: GlossyPill(
            color: background,
            borderRadius: BorderRadius.circular(31),
            onTap: busy ? null : onTap,
            depth: 9,
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(foreground),
                      ),
                    )
                  : Icon(icon, color: foreground, size: 26, fill: 1),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
      add(l10n.callInfoInContacts, isContact ? l10n.callValueYes : l10n.callValueNo);
    }
    add(l10n.callInfoPeerIp, info?.peerIp);
    add(l10n.callInfoPeerNetwork, info?.peerNetwork);
    add(l10n.callInfoPath, info?.path);
    add(l10n.callInfoCodec, info?.audioCodec);
    add(l10n.callInfoServer, info?.region);
    add(l10n.callInfoTopology, info?.topology);
    add('Conversation ID', info?.conversationId);
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
        session!.peerVideo ? l10n.callCameraValueOn : l10n.callCameraValueOff,
      );
    }

    final vtracks = renderer.srcObject?.getVideoTracks().length ?? 0;
    add(
      l10n.callInfoVideoTrack,
      vtracks > 0
          ? l10n.callInfoVideoTrackPresent(vtracks)
          : l10n.callValueNo,
    );
    final w = renderer.value.width.toInt();
    final h = renderer.value.height.toInt();
    add(l10n.callInfoVideoSize, (w > 0 && h > 0) ? '$w×$h' : '—');
    add(
      l10n.callInfoFrameRendering,
      renderer.renderVideo ? l10n.callValueYes : l10n.callValueNo,
    );

    final badges = <Widget>[
      _badge(cs, Symbols.lock, l10n.callBadgeEncrypted),
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
                  fontFamily: 'Outfit',
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
