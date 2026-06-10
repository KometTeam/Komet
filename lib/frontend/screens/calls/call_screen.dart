import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show Helper;
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/calls/call_controller.dart';
import '../../../core/calls/call_session.dart';
import '../../../core/utils/format.dart';

/// Экран звонка. Управляется живым [CallSession].
///
/// Открывается в одном из режимов:
/// - исходящий/активный: передан [session] (уже запущен);
/// - входящий: передан [incoming] — показываем «принять/отклонить», сессия
///   создаётся при принятии.
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
    with SingleTickerProviderStateMixin {
  CallSession? _session;
  StreamSubscription<CallSessionState>? _stateSub;
  CallSessionState _state = CallSessionState.connecting;
  bool _incomingPending = false;

  Timer? _timer;
  bool _isMuted = false;
  bool _isSpeaker = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _incomingPending = widget.session == null && widget.incoming != null;
    if (widget.session != null) _bind(widget.session!);
  }

  void _bind(CallSession session) {
    _session = session;
    _state = session.currentState;
    _stateSub = session.stateStream.listen(_onState);
    if (_state == CallSessionState.active) _startActiveTimer();
  }

  void _onState(CallSessionState state) {
    if (!mounted) return;
    setState(() => _state = state);
    if (state == CallSessionState.active) {
      _startActiveTimer();
    } else if (state == CallSessionState.ended) {
      _close();
    }
  }

  void _startActiveTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
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
    _timer?.cancel();
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
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E14),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const Spacer(flex: 3),
                _buildAvatar(screenH),
                const SizedBox(height: 24),
                _buildName(),
                const SizedBox(height: 8),
                _buildStatus(),
                const Spacer(flex: 2),
                _buildActions(),
                const SizedBox(height: 48),
              ],
            ),
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(
                    Symbols.arrow_back,
                    color: Colors.white,
                    weight: 400,
                  ),
                  tooltip: 'Свернуть',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isRinging =>
      _incomingPending ||
      _state == CallSessionState.connecting ||
      _state == CallSessionState.ringing;

  Widget _buildAvatar(double screenH) {
    final size = screenH * 0.18;
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = _isRinging ? _pulseAnimation.value : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.primaryContainer.withValues(alpha: 0.2),
          border: Border.all(
            color: cs.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: widget.avatarUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 360,
                  memCacheHeight: 360,
                  errorWidget: (_, _, _) => _fallbackAvatar(size),
                )
              : _fallbackAvatar(size),
        ),
      ),
    );
  }

  Widget _fallbackAvatar(double size) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primaryContainer,
      ),
      alignment: Alignment.center,
      child: Text(
        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildName() {
    final cs = Theme.of(context).colorScheme;
    return Text(
      widget.name,
      style: TextStyle(
        color: cs.onSurface,
        fontSize: 26,
        fontWeight: FontWeight.w600,
        fontFamily: 'Outfit',
      ),
    );
  }

  Widget _buildStatus() {
    final cs = Theme.of(context).colorScheme;
    String text;
    if (_incomingPending) {
      text = 'Входящий звонок';
    } else {
      switch (_state) {
        case CallSessionState.connecting:
          text = 'Соединение…';
        case CallSessionState.ringing:
          text = 'Вызов…';
        case CallSessionState.active:
          text = formatSecondsMmSs(
            _session?.elapsedSeconds ?? 0,
            padMinutes: true,
          );
        case CallSessionState.ended:
          text = 'Звонок завершён';
      }
    }
    return Text(
      text,
      style: TextStyle(
        color: cs.onSurfaceVariant,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildActions() {
    if (_incomingPending) return _buildIncomingActions();
    if (_state == CallSessionState.active) return _buildActiveActions();
    return _buildOutgoingActions();
  }

  Widget _buildIncomingActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionButton(
          icon: Symbols.phone_disabled,
          label: 'Отклонить',
          color: const Color(0xFFBA1A1A),
          onTap: _decline,
        ),
        const SizedBox(width: 48),
        _ActionButton(
          icon: Symbols.phone,
          label: 'Принять',
          color: const Color(0xFF3A691E),
          onTap: _accept,
        ),
      ],
    );
  }

  Widget _buildOutgoingActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionButton(
          icon: Symbols.phone_disabled,
          label: 'Отмена',
          color: const Color(0xFFBA1A1A),
          onTap: _hangup,
        ),
      ],
    );
  }

  Widget _buildActiveActions() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleActionButton(
              icon: _isMuted ? Symbols.mic_off : Symbols.mic,
              active: _isMuted,
              onTap: _toggleMute,
            ),
            const SizedBox(width: 32),
            _CircleActionButton(
              icon: _isSpeaker ? Symbols.volume_up : Symbols.volume_down,
              active: _isSpeaker,
              onTap: _toggleSpeaker,
            ),
            const SizedBox(width: 32),
            _CircleActionButton(
              icon: Symbols.bluetooth_audio,
              active: false,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 40),
        _ActionButton(
          icon: Symbols.phone_disabled,
          label: 'Завершить',
          color: const Color(0xFFBA1A1A),
          onTap: _hangup,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 28, fill: 1),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: active ? Colors.white : Colors.white70,
          size: 24,
          fill: 1,
        ),
      ),
    );
  }
}
