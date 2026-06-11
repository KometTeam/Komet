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
import '../../widgets/glossy_pill.dart';

const Color _kEndRed = Color(0xFFE5484D);
const Color _kAcceptGreen = Color(0xFF2EC36B);

class CallScreen extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  final CallSession? session;
  final IncomingCall? incoming;

  const CallScreen({
    super.key,
    required this.name,
    this.avatarUrl,
    this.session,
    this.incoming,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with TickerProviderStateMixin {
  CallSession? _session;
  StreamSubscription<CallSessionState>? _stateSub;
  StreamSubscription<void>? _infoSub;
  StreamSubscription<MediaStream>? _remoteStreamSub;
  CallSessionState _state = CallSessionState.connecting;
  bool _incomingPending = false;

  bool _isMuted = false;
  bool _isSpeaker = false;

  late final AnimationController _dotsController;
  late final AnimationController _videoController;
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _rendererReady = false;
  bool _videoAttached = false;
  MediaStream? _pendingStream;

  Color? _seedKey;
  ColorScheme? _scheme;

  late String _name = widget.name;
  late String? _avatarUrl = widget.avatarUrl;

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
  }

  Future<void> _resolvePeerInfo(int id) async {
    var name = ContactCache.get(id);
    var avatar = ContactCache.getAvatar(id);
    if (name == null || avatar == null) {
      final info = await ContactInfoFetch.get(id);
      if (info != null) {
        name ??= _contactName(info);
        avatar ??= info['baseUrl'] as String?;
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

  String? _contactName(Map<String, dynamic> info) {
    final names = info['names'];
    if (names is! List) return null;
    Map? pick;
    for (final n in names) {
      if (n is! Map) continue;
      pick ??= n;
      if (n['type'] == 'ONEME') {
        pick = n;
        break;
      }
    }
    if (pick == null) return null;
    final first = (pick['firstName'] as String?) ?? '';
    final last = pick['lastName'] as String?;
    final full = (last != null && last.isNotEmpty) ? '$first $last' : first;
    return full.trim().isEmpty ? null : full.trim();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    if (!mounted) return;
    _rendererReady = true;
    if (_pendingStream != null) {
      _remoteRenderer.srcObject = _pendingStream;
      _pendingStream = null;
    }
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
      _syncVideo();
      setState(() {});
    });
    _remoteStreamSub = session.remoteStreamStream.listen(_attachStream);
    final existing = session.remoteStream;
    if (existing != null) _attachStream(existing);
    _syncVideo();
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

  @override
  void dispose() {
    _stateSub?.cancel();
    _infoSub?.cancel();
    _remoteStreamSub?.cancel();
    _dotsController.dispose();
    _videoController.dispose();
    _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _showInfoSheet() {
    final cs = _darkScheme(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
    final avatar = _buildAvatar(cs);
    final name = _buildName(cs);
    final status = _buildStatus(cs);
    final peerBar = _peerStateBar(cs);
    final controls = _buildControls(cs);

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
          body: AnimatedBuilder(
            animation: _videoController,
            builder: (context, _) => _buildBody(
              cs,
              avatar: avatar,
              name: name,
              status: status,
              peerBar: peerBar,
              controls: controls,
            ),
          ),
        ),
      ),
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
          IgnorePointer(child: Opacity(opacity: t, child: _videoScrim(cs))),
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
    final showTimer = t > 0.001 &&
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
              tooltip: 'Свернуть',
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
              child: IconButton(
                onPressed: _showInfoSheet,
                tooltip: 'О звонке',
                icon: Icon(
                  Symbols.info,
                  color: cs.onSurface,
                  weight: 500,
                  size: 26,
                ),
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
    final session = _session;
    if (session == null) return null;
    final pills = <Widget>[
      if (session.peerMuted)
        _statePill(cs, Symbols.mic_off, 'Микрофон выключен'),
      if (session.peerVideo)
        _statePill(cs, Symbols.videocam, 'Камера включена'),
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
    final avatarSize =
        (MediaQuery.of(context).size.shortestSide * 0.42).clamp(128.0, 172.0);
    return _avatarCircle(avatarSize, cs);
  }

  String get _displayName => _name.isEmpty ? 'Неизвестный' : _name;

  Widget _avatarCircle(double size, ColorScheme cs) {
    final url = _avatarUrl;
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
              errorWidget: (_, _, _) => _avatarFallback(size, cs),
            )
          : _avatarFallback(size, cs),
    );
  }

  Widget _avatarFallback(double size, ColorScheme cs) {
    final letter = _displayName[0].toUpperCase();
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
    if (!_incomingPending && _state == CallSessionState.active) {
      final session = _session;
      if (session == null) return const SizedBox.shrink();
      if (!session.mediaConnected) {
        return _statusWithDots(cs, 'Соединение');
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
        'Входящий звонок',
        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
      );
    }

    String text;
    switch (_state) {
      case CallSessionState.connecting:
        text = 'Соединение';
      case CallSessionState.ringing:
        text = 'Вызов';
      case CallSessionState.active:
        text = '';
      case CallSessionState.ended:
        text = 'Звонок завершён';
    }

    return _statusWithDots(cs, text);
  }

  Widget _statusWithDots(ColorScheme cs, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16),
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CallButton(
            icon: Symbols.call_end,
            label: 'Отклонить',
            background: _kEndRed,
            foreground: Colors.white,
            onTap: _decline,
          ),
          _CallButton(
            icon: Symbols.call,
            label: 'Принять',
            background: _kAcceptGreen,
            foreground: Colors.white,
            onTap: _accept,
          ),
        ],
      ),
    );
  }

  Widget _activeControls(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CallButton(
            icon: _isSpeaker ? Symbols.volume_up : Symbols.volume_down,
            label: 'Динамик',
            background: _isSpeaker ? cs.primary : cs.surfaceContainerHighest,
            foreground: _isSpeaker ? cs.onPrimary : cs.onSurface,
            onTap: _toggleSpeaker,
          ),
          _CallButton(
            icon: Symbols.videocam_off,
            label: 'Видео',
            background: cs.surfaceContainerHighest,
            foreground: cs.onSurface,
            onTap: () {},
          ),
          _CallButton(
            icon: _isMuted ? Symbols.mic_off : Symbols.mic,
            label: _isMuted ? 'Вкл. звук' : 'Выкл. звук',
            background: _isMuted ? cs.primary : cs.surfaceContainerHighest,
            foreground: _isMuted ? cs.onPrimary : cs.onSurface,
            onTap: _toggleMute,
          ),
          _CallButton(
            icon: Symbols.call_end,
            label: 'Завершить',
            background: _kEndRed,
            foreground: Colors.white,
            onTap: _hangup,
          ),
        ],
      ),
    );
  }
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

  const _CallButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
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
            onTap: onTap,
            depth: 9,
            child: Center(
              child: Icon(icon, color: foreground, size: 26, fill: 1),
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
    final cs = Theme.of(context).colorScheme;
    final info = session?.info;

    final rows = <List<String>>[];
    void add(String k, String? v) {
      if (v != null && v.isNotEmpty) rows.add([k, v]);
    }

    add('Клиент', _clientLine(info));
    add('Платформа', info?.peerPlatform);
    add('Страна', incoming?.country);
    final isContact = incoming?.isContact;
    if (isContact != null) add('В контактах', isContact ? 'да' : 'нет');
    add('IP собеседника', info?.peerIp);
    add('Сеть собеседника', info?.peerNetwork);
    add('Путь соединения', info?.path);
    add('Кодек', info?.audioCodec);
    add('Сервер', info?.region);
    add('Топология', info?.topology);
    add('Conversation ID', info?.conversationId);
    if (info?.dtlsFingerprint != null) {
      add('DTLS', _shortFp(info!.dtlsFingerprint!));
    }
    if (session != null) {
      add('Статус', session!.mediaConnected ? 'соединён' : 'соединение…');
      add('Микрофон собеседника', session!.peerMuted ? 'выключен' : 'включён');
      add('Камера собеседника', session!.peerVideo ? 'включена' : 'выключена');
    }

    final vtracks = renderer.srcObject?.getVideoTracks().length ?? 0;
    add('Видео-дорожка', vtracks > 0 ? 'есть ($vtracks)' : 'нет');
    final w = renderer.value.width.toInt();
    final h = renderer.value.height.toInt();
    add('Размер видео', (w > 0 && h > 0) ? '$w×$h' : '—');
    add('Отрисовка кадров', renderer.renderVideo ? 'да' : 'нет');

    final badges = <Widget>[
      _badge(cs, Symbols.lock, 'Зашифрован'),
      _badge(cs, Symbols.call, 'Аудио'),
      if (info?.record == true) _badge(cs, Symbols.radio_button_checked, 'Запись'),
      if (info?.denoise == true)
        _badge(cs, Symbols.noise_control_on, 'Шумоподавление'),
      if (info?.animoji == true) _badge(cs, Symbols.mood, 'Анимодзи'),
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
                'О звонке',
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
                  'Данные появятся после соединения…',
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
