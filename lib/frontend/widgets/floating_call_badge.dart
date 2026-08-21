import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart'
    show MediaStream, RTCVideoRenderer, RTCVideoViewObjectFit;
import 'package:material_symbols_icons/symbols.dart';

import '../../core/calls/active_call.dart';
import '../../core/calls/call_session.dart';
import '../../core/config/app_colors.dart';
import '../../core/config/app_fonts.dart';
import '../../core/utils/format.dart';
import '../../core/utils/haptics.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart' show KometApp;
import '../screens/calls/call_screen.dart';
import 'call_video_view.dart';
import 'custom_notification.dart';
import 'draggable_floating_layer.dart';
import 'glossy_pill.dart';
import 'lottie_slash_icon.dart';
import 'small_spinner.dart';

class FloatingCallBadgeLayer extends StatelessWidget {
  const FloatingCallBadgeLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final call = ActiveCall.instance;
    return ValueListenableBuilder<ActiveCallPresentation?>(
      valueListenable: call.current,
      builder: (context, active, _) {
        if (active == null) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: call.screenVisible,
          builder: (context, onScreen, _) => onScreen
              ? const SizedBox.shrink()
              : _CallBadge(key: ObjectKey(active.session), call: active),
        );
      },
    );
  }
}

typedef _BadgeSnapshot = ({
  bool muted,
  bool video,
  bool speaking,
  bool hasVideo,
  bool reconnecting,
  CallSessionState state,
});

class _CallBadge extends StatefulWidget {
  const _CallBadge({super.key, required this.call});

  final ActiveCallPresentation call;

  @override
  State<_CallBadge> createState() => _CallBadgeState();
}

class _CallBadgeState extends State<_CallBadge>
    with SingleTickerProviderStateMixin {
  static const double _collapsedWidth = 120;
  static const double _expandedWidth = 152;
  static const double _collapsedHeight = 112;
  static const double _expandedHeight = 160;
  static const double _avatarSize = 56;
  static const double _buttonSize = 38;
  static const double _controlsWidth = _expandedWidth - 20;
  static const Duration _autoCollapse = Duration(seconds: 4);

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    reverseDuration: const Duration(milliseconds: 200),
  );

  StreamSubscription<CallSessionState>? _stateSub;
  StreamSubscription<void>? _infoSub;
  StreamSubscription<MediaStream>? _remoteStreamSub;
  StreamSubscription<int>? _participantStreamSub;
  Timer? _collapseTimer;
  bool _chromeMounted = false;
  _BadgeSnapshot? _rendered;

  RTCVideoRenderer? _renderer;
  MediaStream? _videoStream;
  bool _rendererPending = false;
  bool _videoBusy = false;

  CallSession get _session => widget.call.session;

  @override
  void initState() {
    super.initState();
    _stateSub = _session.stateStream.listen((_) => _sync());
    _infoSub = _session.infoUpdates.listen((_) => _sync());
    _remoteStreamSub = _session.remoteStreamStream.listen((_) => _sync());
    _participantStreamSub = _session.participantStreamUpdates.listen(
      (_) => _sync(),
    );
    _reveal.addStatusListener(_onRevealStatus);
    _attachVideo();
    _rendered = _snapshot();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _infoSub?.cancel();
    _remoteStreamSub?.cancel();
    _participantStreamSub?.cancel();
    _collapseTimer?.cancel();
    _renderer?.srcObject = null;
    _renderer?.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    _attachVideo();
    final next = _snapshot();
    if (next == _rendered) return;
    _rendered = next;
    setState(() {});
  }

  void _redraw() {
    if (!mounted) return;
    _rendered = _snapshot();
    setState(() {});
  }

  _BadgeSnapshot _snapshot() => (
    muted: _session.isMuted,
    video: _session.localVideo,
    speaking: _peerSpeaking,
    hasVideo: _videoStream != null,
    reconnecting: _session.isReconnecting,
    state: _session.currentState,
  );

  MediaStream? _pickVideoStream() {
    final session = _session;
    for (final participant in session.participants) {
      if (participant.isSelf) continue;
      if (!participant.videoEnabled && !participant.screenSharing) continue;
      final stream = session.streamOf(participant.id);
      if (stream != null && stream.getVideoTracks().isNotEmpty) return stream;
    }
    final remote = session.remoteStream;
    if (session.peerVideo &&
        remote != null &&
        remote.getVideoTracks().isNotEmpty) {
      return remote;
    }
    return null;
  }

  void _attachVideo() {
    final next = _pickVideoStream();
    if (identical(next, _videoStream)) return;
    _videoStream = next;
    final renderer = _renderer;
    if (renderer != null) {
      renderer.srcObject = next;
      return;
    }
    if (next != null && !_rendererPending) {
      _rendererPending = true;
      unawaited(_createRenderer());
    }
  }

  Future<void> _createRenderer() async {
    final renderer = RTCVideoRenderer();
    try {
      await renderer.initialize();
    } catch (_) {
      _rendererPending = false;
      return;
    }
    _rendererPending = false;
    if (!mounted || _videoStream == null) {
      await renderer.dispose();
      return;
    }
    renderer.srcObject = _videoStream;
    _renderer = renderer;
    _redraw();
  }

  void _restartCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_autoCollapse, _collapse);
  }

  void _mountChrome() {
    if (_chromeMounted) return;
    setState(() => _chromeMounted = true);
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !_chromeMounted) return;
    setState(() => _chromeMounted = false);
  }

  void _expandControls() {
    _mountChrome();
    _reveal.forward();
    _restartCollapseTimer();
  }

  void _collapse() {
    _collapseTimer?.cancel();
    if (mounted) _reveal.reverse();
  }

  void _toggleControls() {
    Haptics.tap();
    if (_reveal.value > 0.5) {
      _collapse();
    } else {
      _expandControls();
    }
  }

  void _onDragStart() {
    _collapseTimer?.cancel();
    _mountChrome();
    _reveal.forward();
  }

  void _onDragEnd() => _restartCollapseTimer();

  Future<void> _toggleMute() async {
    Haptics.tap();
    _restartCollapseTimer();
    await _session.setMuted(!_session.isMuted);
    _redraw();
  }

  Future<void> _toggleVideo() async {
    if (_videoBusy) return;
    Haptics.tap();
    _restartCollapseTimer();
    final l10n = AppLocalizations.of(context)!;
    setState(() => _videoBusy = true);
    await WidgetsBinding.instance.endOfFrame;
    try {
      await _session.setVideoEnabled(!_session.localVideo);
    } catch (e) {
      _notify(l10n.callCameraUnavailable(e));
    } finally {
      _videoBusy = false;
      _redraw();
    }
  }

  void _notify(String message) {
    final overlay = KometApp.navigatorKey.currentState?.overlay;
    if (overlay == null) return;
    showCustomNotificationOnOverlay(overlay, message);
  }

  Future<void> _hangup() async {
    Haptics.medium();
    _collapseTimer?.cancel();
    await _session.hangup();
  }

  void _openCall() {
    Haptics.tap();
    _collapse();
    final navigator = KometApp.navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          name: widget.call.name,
          avatarUrl: widget.call.avatarUrl,
          session: _session,
          isGroup: widget.call.isGroup,
        ),
      ),
    );
  }

  bool get _peerSpeaking =>
      _session.participants.any((p) => !p.isSelf && _session.isSpeaking(p.id));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final text = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: cs.onSurface,
    );
    final title = _title(cs, l10n);
    final face = _face(cs);
    final expand = _chromeMounted ? _expandButton(cs, l10n) : null;
    final controls = _chromeMounted ? _controls(cs, l10n) : null;
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_reveal.value);
        final size = Size(
          lerpDouble(_collapsedWidth, _expandedWidth, t)!,
          lerpDouble(_collapsedHeight, _expandedHeight, t)!,
        );
        return DraggableFloatingLayer(
          storageKey: 'call_badge',
          size: size,
          onTap: _toggleControls,
          onDragStart: _onDragStart,
          onDragEnd: _onDragEnd,
          child: SizedBox.fromSize(
            size: size,
            child: _card(
              cs,
              t,
              text: text,
              title: title,
              face: face,
              expand: expand,
              controls: controls,
            ),
          ),
        );
      },
    );
  }

  Widget _card(
    ColorScheme cs,
    double t, {
    required TextStyle text,
    required Widget title,
    required Widget face,
    required Widget? expand,
    required Widget? controls,
  }) {
    final radius = BorderRadius.circular(26);
    return DefaultTextStyle(
      style: text,
      child: GlossyPill(
        color: cs.surfaceContainerHigh,
        borderRadius: radius,
        depth: 10,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned(
                left: 12,
                right: lerpDouble(12, 44, t)!,
                top: 10,
                child: title,
              ),
              if (expand != null)
                Positioned(top: 7, right: 7, child: _fade(t, expand)),
              Positioned(
                left: 0,
                right: 0,
                top: 44,
                bottom: lerpDouble(12, 58, t)!,
                child: Center(child: face),
              ),
              if (controls != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: _fade(
                    t,
                    SizedBox(
                      height: _buttonSize,
                      child: OverflowBox(
                        minWidth: _controlsWidth,
                        maxWidth: _controlsWidth,
                        minHeight: _buttonSize,
                        maxHeight: _buttonSize,
                        alignment: Alignment.center,
                        child: controls,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fade(double t, Widget child) => IgnorePointer(
    ignoring: t < 0.5,
    child: Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(scale: lerpDouble(0.82, 1, t)!, child: child),
    ),
  );

  Widget _title(ColorScheme cs, AppLocalizations l10n) {
    final name = widget.call.name.isEmpty
        ? l10n.callUnknownName
        : widget.call.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
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
        _CallStatusLine(session: _session, color: cs.onSurfaceVariant),
      ],
    );
  }

  Widget _expandButton(ColorScheme cs, AppLocalizations l10n) {
    return Semantics(
      label: l10n.callTooltipExpand,
      button: true,
      child: SizedBox.square(
        dimension: 30,
        child: GlossyPill(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(15),
          depth: 6,
          onTap: _openCall,
          child: Center(
            child: Icon(
              Symbols.open_in_full,
              size: 16,
              weight: 600,
              color: cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(ColorScheme cs) {
    final muted = _session.isMuted;
    final renderer = _renderer;
    final showVideo = _videoStream != null && renderer != null;
    return SizedBox.square(
      dimension: _avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: _avatarSize,
            height: _avatarSize,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.surfaceContainerHighest,
              border: Border.all(
                color: _peerSpeaking
                    ? kSuccessGreen
                    : Colors.white.withValues(alpha: 0.10),
                width: _peerSpeaking ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: showVideo
                ? CallVideoView(
                    renderer: renderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    placeholder: _avatar(cs),
                  )
                : _avatar(cs),
          ),
          if (muted)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surfaceContainerHigh, width: 2),
                ),
                child: Icon(
                  Symbols.mic_off,
                  size: 12,
                  fill: 1,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar(ColorScheme cs) {
    final url = widget.call.avatarUrl;
    if (url == null || url.isEmpty) return _avatarFallback(cs);
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      memCacheWidth: 192,
      memCacheHeight: 192,
      errorWidget: (_, _, _) => _avatarFallback(cs),
    );
  }

  Widget _avatarFallback(ColorScheme cs) {
    final name = widget.call.name;
    final letter = (name.isEmpty ? '?' : name[0]).toUpperCase();
    return ColoredBox(
      color: cs.primaryContainer,
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontSize: _avatarSize * 0.38,
            fontWeight: FontWeight.w600,
            fontFamily: displayFontOf(context),
          ),
        ),
      ),
    );
  }

  Widget _controls(ColorScheme cs, AppLocalizations l10n) {
    final muted = _session.isMuted;
    final video = _session.localVideo;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _BadgeButton(
          size: _buttonSize,
          background: muted ? cs.primary : cs.surfaceContainerHighest,
          label: muted ? l10n.callUnmute : l10n.callMute,
          onTap: _toggleMute,
          child: LottieSlashIcon(
            asset: 'assets/lottie/ic_mic_on_to_off.json',
            slashed: muted,
            color: muted ? cs.onPrimary : cs.onSurface,
            size: 20,
          ),
        ),
        _BadgeButton(
          size: _buttonSize,
          background: video ? cs.primary : cs.surfaceContainerHighest,
          label: l10n.callVideoLabel,
          onTap: _toggleVideo,
          child: _videoBusy
              ? SmallSpinner(
                  size: 16,
                  color: video ? cs.onPrimary : cs.onSurface,
                )
              : LottieSlashIcon(
                  asset: 'assets/lottie/ic_videocam_on_to_off.json',
                  slashed: !video,
                  color: video ? cs.onPrimary : cs.onSurface,
                  size: 20,
                ),
        ),
        _BadgeButton(
          size: _buttonSize,
          background: kDangerRed,
          label: l10n.callEndButton,
          onTap: _hangup,
          child: const Icon(
            Symbols.call_end,
            size: 20,
            fill: 1,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _BadgeButton extends StatelessWidget {
  const _BadgeButton({
    required this.size,
    required this.background,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final double size;
  final Color background;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: SizedBox.square(
        dimension: size,
        child: GlossyPill(
          color: background,
          borderRadius: BorderRadius.circular(size / 2),
          depth: 7,
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CallStatusLine extends StatefulWidget {
  const _CallStatusLine({required this.session, required this.color});

  final CallSession session;
  final Color color;

  @override
  State<_CallStatusLine> createState() => _CallStatusLineState();
}

class _CallStatusLineState extends State<_CallStatusLine> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(_CallStatusLine old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    final counting =
        widget.session.currentState == CallSessionState.active &&
        !widget.session.isReconnecting;
    if (counting == (_ticker != null)) return;
    if (!counting) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String _label(AppLocalizations l10n) {
    final session = widget.session;
    if (session.isReconnecting) return l10n.callStatusConnecting;
    return switch (session.currentState) {
      CallSessionState.connecting => l10n.callStatusConnecting,
      CallSessionState.ringing => l10n.callStatusRinging,
      CallSessionState.ended => l10n.callStatusEnded,
      CallSessionState.active => formatSecondsMmSs(
        session.elapsedSeconds,
        padMinutes: true,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label(AppLocalizations.of(context)!),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: widget.color,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
