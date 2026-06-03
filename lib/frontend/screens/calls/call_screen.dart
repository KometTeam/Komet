import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

enum CallScreenState { incoming, outgoing, active }

class CallScreen extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  final CallScreenState initialState;

  const CallScreen({
    super.key,
    required this.name,
    this.avatarUrl,
    this.initialState = CallScreenState.incoming,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  late CallScreenState _state;
  Timer? _timer;
  int _seconds = 0;
  bool _isMuted = false;
  bool _isSpeaker = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (_state == CallScreenState.outgoing) {
      _startOutgoingTimer();
    }
  }

  void _startOutgoingTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
      if (_seconds >= 3 && _state == CallScreenState.outgoing) {
        _timer?.cancel();
        setState(() => _state = CallScreenState.active);
        _startActiveTimer();
      }
    });
  }

  void _startActiveTimer() {
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  String get _timerText {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _accept() {
    setState(() {
      _state = CallScreenState.active;
      _seconds = 0;
    });
    _startActiveTimer();
  }

  void _endCall() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
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
        child: Column(
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
      ),
    );
  }

  Widget _buildAvatar(double screenH) {
    final size = screenH * 0.18;
    final cs = Theme.of(context).colorScheme;
    final isRinging = _state == CallScreenState.incoming;
    final isOutgoing = _state == CallScreenState.outgoing;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = (isRinging || isOutgoing)
            ? _pulseAnimation.value
            : 1.0;
        return Transform.scale(
          scale: scale,
          child: child,
        );
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
    switch (_state) {
      case CallScreenState.incoming:
        text = 'Входящий звонок';
      case CallScreenState.outgoing:
        text = 'Вызов...';
      case CallScreenState.active:
        text = _timerText;
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
    switch (_state) {
      case CallScreenState.incoming:
        return _buildIncomingActions();
      case CallScreenState.outgoing:
        return _buildOutgoingActions();
      case CallScreenState.active:
        return _buildActiveActions();
    }
  }

  Widget _buildIncomingActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionButton(
          icon: Symbols.phone_disabled,
          label: 'Отклонить',
          color: const Color(0xFFBA1A1A),
          onTap: _endCall,
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
          onTap: _endCall,
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
              onTap: () => setState(() => _isMuted = !_isMuted),
            ),
            const SizedBox(width: 32),
            _CircleActionButton(
              icon: _isMuted ? Symbols.volume_off : Symbols.volume_up,
              active: _isSpeaker,
              onTap: () => setState(() => _isSpeaker = !_isSpeaker),
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
          onTap: _endCall,
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
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
